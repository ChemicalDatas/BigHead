class_name LocalStats
extends StatsPort
## Stats kept in user://stats.json. Used without Steam, and as the fallback
## for stats Steam doesn't define yet (during development on app 480).

const PATH := "user://stats.json"

var _values := {}


func _init() -> void:
	if FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			_values = data


func get_int(stat_name: String) -> int:
	return int(_values.get(stat_name, 0))


func add_int(stat_name: String, delta: int) -> int:
	var value := get_int(stat_name) + delta
	_values[stat_name] = value
	_save()
	return value


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_values))
