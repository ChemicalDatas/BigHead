class_name PlayerProfile
extends RefCounted
## Who is playing. Both avatars are optional; the reveal reads which ones
## exist and picks its choreography from that.

var display_name := ""
var steam_id := 0
var build: HeadBuild = null
var steam_avatar: Texture2D = null


func has_build() -> bool:
	return build != null


func has_steam_avatar() -> bool:
	return steam_avatar != null
