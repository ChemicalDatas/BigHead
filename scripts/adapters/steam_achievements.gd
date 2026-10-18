class_name SteamAchievements
extends AchievementPort
## AchievementPort backed by GodotSteam.
## `id_map` translates the game's ids to Steamworks API names; ids missing
## from the map are used as-is.

var _steam: Object
var _id_map: Dictionary


func _init(steam: Object, id_map: Dictionary = {}) -> void:
	_steam = steam
	_id_map = id_map


func unlock(id: String) -> void:
	var api_name := str(_id_map.get(id, id))
	var result: Variant = _steam.call("setAchievement", api_name)
	_steam.call("storeStats")
	print("[achievements] %s -> %s (setAchievement returned %s)" % [id, api_name, result])
