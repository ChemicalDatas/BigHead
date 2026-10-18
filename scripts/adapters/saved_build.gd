class_name SavedBuild
extends RefCounted
## Stores the player's bobblehead and scene style in user:// as JSON.
## On Linux: ~/.local/share/godot/app_userdata/Big Head/head_build.json
## On Windows: %APPDATA%\Godot\app_userdata\Big Head\head_build.json

const PATH := "user://head_build.json"


func exists() -> bool:
	return FileAccess.file_exists(PATH)


func _read() -> Dictionary:
	if not exists():
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		# Iteration 1 saved the head as a flat dictionary.
		if not data.has("head"):
			return {"head": data}
		return data
	push_warning("Saved head build is unreadable; starting fresh.")
	return {}


func load_build() -> HeadBuild:
	var data := _read()
	return HeadBuild.from_dict(data["head"]) if data.has("head") else null


func load_style() -> SceneStyle:
	var data := _read()
	return SceneStyle.from_dict(data["style"]) if data.has("style") else SceneStyle.new()


func save(build: HeadBuild, style: SceneStyle) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save head build: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"head": build.to_dict(), "style": style.to_dict()}, "\t"))


func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
