class_name StatsPort
extends RefCounted
## Persistent integer counters (clicks, fireworks launched) by the game's own names.


func get_int(_name: String) -> int:
	return 0


## Adds `delta` to a stat and returns the new value.
func add_int(_name: String, _delta: int) -> int:
	return 0


func snapshot(names: Array[String]) -> Dictionary:
	var values := {}
	for stat_name in names:
		values[stat_name] = get_int(stat_name)
	return values
