class_name UploadStore
extends RefCounted
## Player-uploaded images (body texture, background), copied into user:// and
## downscaled. The original file is never referenced again.
## Uploads stay local: they are never sent to other players.
##
## Changes made in Customize are staged: picking or removing an image only
## changes a pending copy, which Save commits and Cancel throws away.

const DIR := "user://uploads"
const MAX_SIZE := 2048
const BODY := "body"
const BACKGROUND := "background"
const FILTERS: Array[String] = ["*.png, *.jpg, *.jpeg, *.webp ; Images"]

var _cache := {}
## kind -> "replace" (a pending image exists) or "remove"
var _staged := {}


func path_for(kind: String) -> String:
	return "%s/%s.png" % [DIR, kind]


func _pending_path(kind: String) -> String:
	return "%s/%s.pending.png" % [DIR, kind]


func exists(kind: String) -> bool:
	return FileAccess.file_exists(path_for(kind))


## The saved image, ignoring anything staged.
func texture(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var tex := _load(path_for(kind))
	if tex != null:
		_cache[kind] = tex
	return tex


## What Customize should preview: the staged image if there is one, else the saved one.
func preview_texture(kind: String) -> Texture2D:
	match _staged.get(kind, ""):
		"replace":
			return _load(_pending_path(kind))
		"remove":
			return null
	return texture(kind)


## Copies an image from anywhere on disk into a pending slot. Returns "" on
## success, otherwise a message for the player.
func stage_import(source_path: String, kind: String) -> String:
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return "Couldn't read that image. Try a PNG or JPG."
	var longest := maxi(image.get_width(), image.get_height())
	if longest > MAX_SIZE:
		var factor := float(MAX_SIZE) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var err := image.save_png(_pending_path(kind))
	if err != OK:
		return "Couldn't save the image (error %d)." % err
	_staged[kind] = "replace"
	return ""


func stage_remove(kind: String) -> void:
	_delete(_pending_path(kind))
	_staged[kind] = "remove"


## Save: pending images replace the saved ones; staged removals delete them.
func commit() -> void:
	for kind in _staged:
		_cache.erase(kind)
		if _staged[kind] == "replace":
			_delete(path_for(kind))
			DirAccess.rename_absolute(ProjectSettings.globalize_path(_pending_path(kind)), ProjectSettings.globalize_path(path_for(kind)))
		else:
			_delete(path_for(kind))
	_staged.clear()


## Cancel: forget everything staged.
func discard() -> void:
	for kind in _staged:
		_delete(_pending_path(kind))
	_staged.clear()


func erase(kind: String) -> void:
	_cache.erase(kind)
	_staged.erase(kind)
	_delete(path_for(kind))
	_delete(_pending_path(kind))


func _load(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null else null


func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
