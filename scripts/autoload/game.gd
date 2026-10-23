extends Node
## Global wiring: picks adapters, holds the player's profile, routes scenes,
## turns game events into stats and achievements.
##
## Command-line options (put them after `--` when launching):
##   --no-steam              skip Steam even if GodotSteam is installed (tests the fallback)
##   --reset                 forget the saved head, style and uploads (tests the first launch)
##   --reset-achievement     re-lock the dev achievements so unlocks can be tested again
##   --fake-friends=N        pretend N friends have Big Head (fireworks multiplier, until 2B)
##   --fast-faces            run the face swap cycle 10x faster (1.5 s / 4.5 s) for testing
##   --unlock-all            treat every catalog item as owned for this run
##   --reset-inventory       forget unlocked items; back to the starting set
##   --drop-rate=N           chance of a drop per right-click, 0 to 1 (default 0.05)
##   --fireworks-launched=N  set the lifetime fireworks count (tests the rig milestones)

## INTENTIONAL: the company name is "A.L.", not "A.I.". Do not correct it.
const COMPANY_NAME := "Scapegoat A.L. LLC"

## Valve's Spacewar test app until Big Head gets its own App ID (iteration 2B).
const DEV_APP_ID := 480
## Iteration 2B: set to false, empty both maps below, and use the real App ID.
const DEV_MODE := true
## Spacewar only defines four test achievements, so four of ours stand in on them.
## The rest are logged to the console while DEV_MODE is on.
const DEV_ACHIEVEMENT_MAP := {
	AchievementRules.BIG_HEAD: "ACH_WIN_ONE_GAME",
	AchievementRules.ITS_A_PARTY: "ACH_WIN_100_GAMES",
	AchievementRules.WHIPLASH: "ACH_TRAVEL_FAR_SINGLE",
	AchievementRules.BOBBLE_BOOP: "ACH_TRAVEL_FAR_ACCUM",
}
## Spacewar test stats our counters borrow during development.
const DEV_STAT_MAP := {
	AchievementRules.STAT_CLICKS: "NumGames",
	AchievementRules.STAT_FIREWORKS: "NumWins",
}

## After the reveal, Steam players alternate faces: the Steam avatar for 15 s,
## then their own face for 45 s, and so on (unless locked in Customize).
const STEAM_FACE_SECONDS := 15.0
const OWN_FACE_SECONDS := 45.0
## Confetti returns once every this many full cycles (10 cycles = 10 minutes).
const CONFETTI_EVERY_CYCLES := 10

const SPLASH_SCENE := "res://scenes/splash.tscn"
const BUILDER_SCENE := "res://scenes/head_builder.tscn"
const REVEAL_SCENE := "res://scenes/reveal.tscn"

signal steam_avatar_arrived
signal friends_with_big_head_changed(count: int)
## Emitted for every unlock (Steam shows its own popup; this is for logs and tests).
signal achievement_unlocked(id: String)

var identity: SteamIdentity
var achievements: AchievementPort
var stats: StatsPort
var uploads := UploadStore.new()
var inventory: InventoryPort
## Set when leaving Customize (Save or Cancel): the next reveal scene skips
## straight to the playground instead of replaying the pop.
var skip_reveal_once := false
## Chance of a regular drop per right-click (--drop-rate overrides it).
var drop_rate := DropRules.DEFAULT_DROP_RATE
## Items in gift boxes on screen, not yet clicked: item id -> super-rare flag.
## Kept here (not in the scene) so boxes survive a trip to Customize; lost at
## quit, by design.
var _waiting_in_boxes := {}
var _drop_rng := RandomNumberGenerator.new()
var saved_build := SavedBuild.new()
var profile := PlayerProfile.new()
var steam_available := false
var friends_with_big_head := 0
## 1.0 normally; 0.1 with --fast-faces.
var face_time_scale := 1.0

var _unlocked_this_session := {}
var _fake_friends := -1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_fake_friends = _parse_fake_friends(args)
	_drop_rng.randomize()
	_parse_drop_rate(args)
	if "--fast-faces" in args:
		face_time_scale = 0.1
		print("[game] Face swaps run 10x faster (--fast-faces).")

	if "--reset" in args:
		saved_build.erase()
		uploads.erase(UploadStore.BODY)
		uploads.erase(UploadStore.BACKGROUND)
		print("[game] Saved head, style and uploads erased (--reset).")
	if "--reset-inventory" in args:
		LocalInventory.erase()
		print("[game] Inventory back to the starting set (--reset-inventory).")
	inventory = LocalInventory.new()
	if "--unlock-all" in args:
		inventory = UnlockAllInventory.new(inventory)
		print("[game] Every item unlocked for this run (--unlock-all).")

	identity = SteamIdentity.new()
	identity.name = "SteamIdentity"
	add_child(identity)

	if "--no-steam" in args:
		print("[game] Steam skipped (--no-steam).")
	else:
		steam_available = identity.initialize(DEV_APP_ID)
		print("[game] Steam available: %s (%s)" % [steam_available, identity.init_message])

	if steam_available:
		achievements = SteamAchievements.new(identity.steam(), DEV_ACHIEVEMENT_MAP if DEV_MODE else {}, DEV_MODE)
		stats = SteamStats.new(identity.steam(), DEV_STAT_MAP if DEV_MODE else {}, not DEV_MODE)
		if "--reset-achievement" in args:
			for id in AchievementRules.ALL:
				identity.steam().call("clearAchievement", (achievements as SteamAchievements).api_name(id))
			identity.steam().call("storeStats")
			print("[game] Dev achievements cleared (--reset-achievement).")
		profile.display_name = identity.local_name()
		profile.steam_id = identity.local_id()
		identity.local_avatar_ready.connect(_on_local_avatar_ready)
		identity.request_local_avatar()
	else:
		achievements = NullAchievements.new()
		stats = LocalStats.new()
	_apply_fireworks_flag(args)

	if _fake_friends >= 0:
		_set_friends(_fake_friends)
		print("[game] Pretending %d friends have Big Head (--fake-friends)." % _fake_friends)
	elif steam_available:
		identity.friends_with_achievement_counted.connect(_set_friends)
		identity.count_friends_with_achievement((achievements as SteamAchievements).api_name(AchievementRules.BIG_HEAD))

	profile.build = saved_build.load_build()
	profile.style = saved_build.load_style()
	if profile.has_build():
		var fixed := profile.build.sanitize(inventory)
		if not fixed.is_empty():
			print("[game] Saved head used locked items (%s); switched to owned ones." % ", ".join(fixed))


## Reads --fake-friends=N or --fake-friends N. Returns -1 when the flag is absent
## or unreadable (with a warning), so a typo never silently means "0 friends".
func _parse_fake_friends(args: PackedStringArray) -> int:
	for i in args.size():
		var arg := args[i]
		var value := ""
		if arg.begins_with("--fake-friends="):
			value = arg.get_slice("=", 1)
		elif arg == "--fake-friends":
			value = args[i + 1] if i + 1 < args.size() else ""
		else:
			continue
		if value.is_valid_int() and int(value) >= 0:
			return int(value)
		push_warning("--fake-friends needs a whole number, like --fake-friends=4 (got \"%s\"); ignoring it." % value)
		return -1
	return -1


## --fireworks-launched=N (or --fireworks-launched N): sets the lifetime
## fireworks count, to test the rig milestones (500 balloon, 1000 marionette).
func _apply_fireworks_flag(args: PackedStringArray) -> void:
	for i in args.size():
		var value := ""
		if args[i].begins_with("--fireworks-launched="):
			value = args[i].get_slice("=", 1)
		elif args[i] == "--fireworks-launched" and i + 1 < args.size():
			value = args[i + 1]
		if value.is_valid_int():
			var name := AchievementRules.STAT_FIREWORKS
			stats.add_int(name, int(value) - stats.get_int(name))
			print("[game] Lifetime fireworks set to %d (--fireworks-launched)." % stats.get_int(name))
			return


## Reads --drop-rate=N (or --drop-rate N), a chance from 0 to 1.
func _parse_drop_rate(args: PackedStringArray) -> void:
	for i in args.size():
		var value := ""
		if args[i].begins_with("--drop-rate="):
			value = args[i].get_slice("=", 1)
		elif args[i] == "--drop-rate":
			value = args[i + 1] if i + 1 < args.size() else ""
		else:
			continue
		if value.is_valid_float() and float(value) >= 0.0 and float(value) <= 1.0:
			drop_rate = float(value)
			print("[game] Drop chance per right-click: %s (--drop-rate)." % value)
		else:
			push_warning("--drop-rate needs a number from 0 to 1, like --drop-rate=1 (got \"%s\"); ignoring it." % value)
		return


## One right-click's drop roll. A new item is held "in a box" until opened.
func roll_drop() -> DropRules.Result:
	var fireworks := stats.get_int(AchievementRules.STAT_FIREWORKS)
	var result := DropRules.roll(_drop_rng, drop_rate, func(id: String) -> bool:
		return inventory.owns(id) or _waiting_in_boxes.has(id), fireworks)
	if result.kind == DropRules.Kind.NEW_ITEM:
		_waiting_in_boxes[result.item_id] = result.super_rare
	return result


## Gift boxes still waiting to be clicked: item id -> super-rare flag.
func waiting_gifts() -> Dictionary:
	return _waiting_in_boxes.duplicate()


## The player clicked a gift box: the item is theirs.
func open_gift(item_id: String) -> bool:
	_waiting_in_boxes.erase(item_id)
	var is_new := inventory.grant(item_id)
	print("[drops] Unlocked %s%s" % [Catalog.display_name(item_id), "" if is_new else " (already owned)"])
	return is_new


## Where the splash goes next: the builder on first launch, else the reveal.
func scene_after_splash() -> String:
	return REVEAL_SCENE if profile.has_build() else BUILDER_SCENE


## The name on the banner: the Steam name for Steam players, else the typed name.
func banner_name() -> String:
	if steam_available and profile.display_name != "":
		return profile.display_name
	if profile.has_build() and profile.build.player_name.strip_edges() != "":
		return profile.build.player_name.strip_edges()
	return "Mystery Player"


## Rockets per right-click: one of yours plus one per friend with Big Head.
func rockets_per_click() -> int:
	return 1 + friends_with_big_head


func save_build(build: HeadBuild, style: SceneStyle) -> void:
	profile.build = build
	profile.style = style
	saved_build.save(build, style)


## Game events go here; see AchievementRules for the list.
func report(event: String, data: Dictionary = {}) -> void:
	var deltas := AchievementRules.stat_deltas(event, data)
	for stat_name in deltas:
		stats.add_int(stat_name, int(deltas[stat_name]))
	var snapshot := stats.snapshot([AchievementRules.STAT_CLICKS, AchievementRules.STAT_FIREWORKS])
	for id in AchievementRules.unlocks_for(event, data, snapshot, steam_available):
		if _unlocked_this_session.has(id):
			continue
		_unlocked_this_session[id] = true
		achievements.unlock(id)
		achievement_unlocked.emit(id)


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _set_friends(count: int) -> void:
	friends_with_big_head = count
	friends_with_big_head_changed.emit(count)


func _on_local_avatar_ready(texture: Texture2D) -> void:
	profile.steam_avatar = texture
	steam_avatar_arrived.emit()
	print("[game] Steam avatar loaded: %dx%d" % [texture.get_width(), texture.get_height()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
