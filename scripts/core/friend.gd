class_name Friend
extends RefCounted
## A friend who has Big Head, for the shelf. `avatar` arrives later (or never).

var steam_id := 0
var name := ""
var avatar: Texture2D = null


func _init(id: int, friend_name: String) -> void:
	steam_id = id
	name = friend_name
