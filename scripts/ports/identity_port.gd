class_name IdentityPort
extends Node
## "Who is playing?" Scenes and core code ask this port, never Steam directly.

signal local_avatar_ready(texture: Texture2D)


func is_available() -> bool:
	return false


func local_name() -> String:
	return ""


func local_id() -> int:
	return 0


## Starts loading the local player's avatar; answers through local_avatar_ready.
func request_local_avatar() -> void:
	pass


## Friends as profiles. Empty until the friends shelf in iteration 3.
func get_friends() -> Array[PlayerProfile]:
	var friends: Array[PlayerProfile] = []
	return friends
