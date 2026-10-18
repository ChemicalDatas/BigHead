class_name NullAchievements
extends AchievementPort
## Used when Steam is not available: nothing is unlocked and nothing is shown.


func unlock(id: String) -> void:
	print("[achievements] Steam not available; skipped %s" % id)
