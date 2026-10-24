class_name SteamIdentity
extends IdentityPort
## IdentityPort backed by GodotSteam (GDExtension, 4.14 or newer).
##
## The Steam singleton is looked up at runtime instead of referenced by name,
## so the project still opens and runs when GodotSteam is not installed:
## initialize() just returns false and the game uses the Head Builder fallback.

const STEAM_INIT_OK := 0
const AVATAR_LARGE := 3            ## Steam.AVATAR_LARGE (184 px)
const AVATAR_MEDIUM := 2           ## Steam.AVATAR_MEDIUM (64 px), plenty for the shelf
const FRIEND_FLAG_IMMEDIATE := 4   ## Steam.FRIEND_FLAG_IMMEDIATE (regular friends)
const MAX_FRIENDS_CHECKED := 500
const MAX_IN_FLIGHT := 8           ## friend stat requests in flight at once

var init_message := ""

var _steam: Object = null
var _available := false

# Friend achievement lookup state
var _lookup_api_name := ""
var _lookup_queue: Array[int] = []
var _lookup_in_flight := 0
var _lookup_count := 0


func initialize(app_id: int) -> bool:
	if not Engine.has_singleton("Steam"):
		init_message = "GodotSteam is not installed (no Steam singleton)."
		return false
	_steam = Engine.get_singleton("Steam")
	# GodotSteam 4.14+: steamInitEx(app_id, embed_callbacks). Callbacks run in _process below.
	var result: Variant = _steam.call("steamInitEx", app_id, false)
	if result is Dictionary:
		init_message = str(result)
		_available = int((result as Dictionary).get("status", 1)) == STEAM_INIT_OK
	else:
		init_message = "Unexpected steamInitEx result: %s" % [result]
		_available = false
	if _available:
		_steam.connect("avatar_loaded", _on_avatar_loaded)
		if _steam.has_signal("user_stats_received"):
			_steam.connect("user_stats_received", _on_user_stats_received)
	return _available


func steam() -> Object:
	return _steam


func is_available() -> bool:
	return _available


func local_name() -> String:
	return str(_steam.call("getPersonaName")) if _available else ""


func local_id() -> int:
	return int(_steam.call("getSteamID")) if _available else 0


func request_local_avatar() -> void:
	if _available:
		_steam.call("getPlayerAvatar", AVATAR_LARGE, local_id())


## Asks Steam for each friend's stats once, then reads the achievement.
## Results are cached by the caller; this never runs per click.
func count_friends_with_achievement(api_name: String) -> void:
	_lookup_count = 0
	_lookup_queue.clear()
	_lookup_in_flight = 0
	_lookup_api_name = api_name
	if not _available or not _steam.has_signal("user_stats_received"):
		friends_with_achievement_counted.emit(0)
		return
	var total := mini(int(_steam.call("getFriendCount", FRIEND_FLAG_IMMEDIATE)), MAX_FRIENDS_CHECKED)
	for i in range(total):
		_lookup_queue.append(int(_steam.call("getFriendByIndex", i, FRIEND_FLAG_IMMEDIATE)))
	print("[friends] checking %d friends for %s" % [total, api_name])
	if total == 0:
		friends_with_achievement_counted.emit(0)
		return
	_pump_lookup()


func _pump_lookup() -> void:
	while _lookup_in_flight < MAX_IN_FLIGHT and not _lookup_queue.is_empty():
		var friend_id: int = _lookup_queue.pop_front()
		_lookup_in_flight += 1
		_steam.call("requestUserStats", friend_id)


func _on_user_stats_received(_game_id: int, result: int, user_id: int) -> void:
	if _lookup_api_name == "" or user_id == local_id():
		return
	_lookup_in_flight = maxi(_lookup_in_flight - 1, 0)
	if result == 1:  # k_EResultOK: this friend has stats for this game
		var answer: Variant = _steam.call("getUserAchievement", user_id, _lookup_api_name)
		var achieved := false
		if answer is Dictionary:
			achieved = bool((answer as Dictionary).get("achieved", false))
		elif answer is bool:
			achieved = answer
		if achieved:
			_lookup_count += 1
			friend_found.emit(user_id, str(_steam.call("getFriendPersonaName", user_id)))
			friends_with_achievement_counted.emit(_lookup_count)
	if _lookup_queue.is_empty() and _lookup_in_flight == 0:
		print("[friends] %d friends have %s" % [_lookup_count, _lookup_api_name])
		friends_with_achievement_counted.emit(_lookup_count)
	else:
		_pump_lookup()


func _process(_delta: float) -> void:
	if _available:
		_steam.call("run_callbacks")


func set_rich_presence(key: String, value: String) -> void:
	if _available:
		_steam.call("setRichPresence", key, value)


func request_friend_avatar(steam_id: int) -> void:
	if _available:
		_steam.call("getPlayerAvatar", AVATAR_MEDIUM, steam_id)


func _on_avatar_loaded(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	var image := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	var texture := ImageTexture.create_from_image(image)
	if user_id == local_id():
		local_avatar_ready.emit(texture)
	else:
		friend_avatar_ready.emit(user_id, texture)
