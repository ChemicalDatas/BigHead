class_name IdentityPort
extends Node
## "Who is playing, and who are their friends?" Scenes and core code ask this
## port, never Steam directly.

signal local_avatar_ready(texture: Texture2D)
## How many friends have a given achievement; may be emitted several times
## as results arrive.
signal friends_with_achievement_counted(count: int)


func is_available() -> bool:
	return false


func local_name() -> String:
	return ""


func local_id() -> int:
	return 0


## Starts loading the local player's avatar; answers through local_avatar_ready.
func request_local_avatar() -> void:
	pass


## Starts counting friends who have `api_name` unlocked in this game;
## answers through friends_with_achievement_counted.
func count_friends_with_achievement(_api_name: String) -> void:
	friends_with_achievement_counted.emit(0)


## Friends as profiles. Empty until the friends shelf in iteration 3.
func get_friends() -> Array[PlayerProfile]:
	var friends: Array[PlayerProfile] = []
	return friends
