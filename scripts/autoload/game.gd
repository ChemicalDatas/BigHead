extends Node
## Global wiring: picks adapters, holds the player's profile, routes scenes.
##
## Command-line options (put them after `--` when launching):
##   --no-steam   skip Steam even if GodotSteam is installed (tests the fallback)
##   --reset      forget the saved head build (tests the first launch)
##   --reset-achievement   re-lock the dev achievement so the unlock can be tested again

## INTENTIONAL: the company name is "A. L.", not "A. I.". Do not correct it.
const COMPANY_NAME := "Scapegoat A. L. LLC"

## Valve's Spacewar test app until Big Head gets its own App ID (iteration 2).
const DEV_APP_ID := 480
## Spacewar has no BIG_HEAD achievement, so during development ours is mapped
## onto one of Spacewar's test achievements. Iteration 2: empty this map.
const DEV_ACHIEVEMENT_MAP := {"BIG_HEAD": "ACH_WIN_ONE_GAME"}

const SPLASH_SCENE := "res://scenes/splash.tscn"
const BUILDER_SCENE := "res://scenes/head_builder.tscn"
const REVEAL_SCENE := "res://scenes/reveal.tscn"

signal steam_avatar_arrived

var identity: SteamIdentity
var achievements: AchievementPort
var saved_build := SavedBuild.new()
var profile := PlayerProfile.new()
var steam_available := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--reset" in args:
		saved_build.erase()
		print("[game] Saved head build erased (--reset).")

	identity = SteamIdentity.new()
	identity.name = "SteamIdentity"
	add_child(identity)

	if "--no-steam" in args:
		print("[game] Steam skipped (--no-steam).")
	else:
		steam_available = identity.initialize(DEV_APP_ID)
		print("[game] Steam available: %s (%s)" % [steam_available, identity.init_message])

	if steam_available:
		achievements = SteamAchievements.new(identity.steam(), DEV_ACHIEVEMENT_MAP)
		if "--reset-achievement" in args:
			for api_name in DEV_ACHIEVEMENT_MAP.values():
				identity.steam().call("clearAchievement", api_name)
			identity.steam().call("storeStats")
			print("[game] Dev achievement cleared (--reset-achievement).")
		profile.display_name = identity.local_name()
		profile.steam_id = identity.local_id()
		identity.local_avatar_ready.connect(_on_local_avatar_ready)
		identity.request_local_avatar()
	else:
		achievements = NullAchievements.new()

	profile.build = saved_build.load_build()


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


func save_build(build: HeadBuild) -> void:
	profile.build = build
	saved_build.save(build)


func report(event: String) -> void:
	for id in AchievementRules.unlocks_for(event, steam_available):
		achievements.unlock(id)


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _on_local_avatar_ready(texture: Texture2D) -> void:
	profile.steam_avatar = texture
	steam_avatar_arrived.emit()
	print("[game] Steam avatar loaded: %dx%d" % [texture.get_width(), texture.get_height()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
