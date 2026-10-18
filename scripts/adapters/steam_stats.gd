class_name SteamStats
extends StatsPort
## StatsPort backed by Steam user stats. `name_map` translates the game's stat
## names to Steamworks API names.
##   - Development on app 480 (`all_on_steam = false`): only mapped stats go
##     to Steam; the rest are kept in LocalStats.
##   - Real App ID (`all_on_steam = true`, empty map): every stat goes to
##     Steam under its own name.
## A stat Steam rejects falls back to LocalStats either way.

var _steam: Object
var _name_map: Dictionary
var _all_on_steam: bool
var _rejected := {}
var _local := LocalStats.new()


func _init(steam: Object, name_map: Dictionary = {}, all_on_steam := false) -> void:
	_steam = steam
	_name_map = name_map
	_all_on_steam = all_on_steam


func _on_steam(stat_name: String) -> bool:
	return not _rejected.has(stat_name) and (_all_on_steam or _name_map.has(stat_name))


func _api_name(stat_name: String) -> String:
	return str(_name_map.get(stat_name, stat_name))


func get_int(stat_name: String) -> int:
	if _on_steam(stat_name):
		return int(_steam.call("getStatInt", _api_name(stat_name)))
	return _local.get_int(stat_name)


func add_int(stat_name: String, delta: int) -> int:
	if _on_steam(stat_name):
		var api_name := _api_name(stat_name)
		var value := int(_steam.call("getStatInt", api_name)) + delta
		if _steam.call("setStatInt", api_name, value):
			_steam.call("storeStats")
			return value
		push_warning("Steam rejected stat %s; keeping it locally." % api_name)
		_rejected[stat_name] = true
	return _local.add_int(stat_name, delta)
