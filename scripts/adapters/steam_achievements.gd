class_name SteamAchievements
extends AchievementPort
## AchievementPort backed by GodotSteam.
## `id_map` translates the game's ids to Steamworks API names. While the game
## runs as test app 480, ids without a Spacewar stand-in are only logged.
## With the real App ID (iteration 2B) pass `log_unmapped = false` and an
## empty map: every id is then its own Steamworks API name.

var _steam: Object
var _id_map: Dictionary
var _log_unmapped: bool


func _init(steam: Object, id_map: Dictionary = {}, log_unmapped := false) -> void:
	_steam = steam
	_id_map = id_map
	_log_unmapped = log_unmapped


func api_name(id: String) -> String:
	return str(_id_map.get(id, id))


func unlock(id: String) -> void:
	if _log_unmapped and not _id_map.has(id):
		print("[achievements] UNLOCKED %s (no Spacewar stand-in; real popup arrives with the App ID)" % id)
		return
	var result: Variant = _steam.call("setAchievement", api_name(id))
	_steam.call("storeStats")
	print("[achievements] UNLOCKED %s -> Steam %s (setAchievement returned %s)" % [id, api_name(id), result])
