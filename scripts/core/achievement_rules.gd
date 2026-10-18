class_name AchievementRules
extends RefCounted
## Game events in, achievement unlocks out. No Steam calls here.

const BIG_HEAD := "BIG_HEAD"


static func unlocks_for(event: String, steam_available: bool) -> Array[String]:
	var unlocks: Array[String] = []
	# Non-Steam players get no achievement and no toast.
	if not steam_available:
		return unlocks
	match event:
		"reveal_finished":
			unlocks.append(BIG_HEAD)
	return unlocks
