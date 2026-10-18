class_name SavedBuild
extends RefCounted
## Stores the player's Head Builder choices in user:// as JSON.
## On Linux that is ~/.local/share/godot/app_userdata/Big Head/head_build.json

const PATH := "user://head_build.json"


func exists() -> bool:
	return FileAccess.file_exists(PATH)


func load_build() -> HeadBuild:
	if not exists():
		return null
	var text := FileAccess.get_file_as_string(PATH)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return HeadBuild.from_dict(data)
	push_warning("Saved head build is unreadable; starting fresh.")
	return null


func save(build: HeadBuild) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save head build: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(build.to_dict(), "\t"))


func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
