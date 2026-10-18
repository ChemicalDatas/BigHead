class_name UploadStore
extends RefCounted
## Player-uploaded images (body texture, background), copied into user:// and
## downscaled. The original file is never referenced again.
## Uploads stay local: they are never sent to other players.

const DIR := "user://uploads"
const MAX_SIZE := 2048
const BODY := "body"
const BACKGROUND := "background"
const FILTERS: Array[String] = ["*.png, *.jpg, *.jpeg, *.webp ; Images"]

var _cache := {}


func path_for(kind: String) -> String:
	return "%s/%s.png" % [DIR, kind]


func exists(kind: String) -> bool:
	return FileAccess.file_exists(path_for(kind))


## Copies an image from anywhere on disk into user://. Returns "" on success,
## otherwise a message for the player.
func import_image(source_path: String, kind: String) -> String:
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return "Couldn't read that image. Try a PNG or JPG."
	var longest := maxi(image.get_width(), image.get_height())
	if longest > MAX_SIZE:
		var factor := float(MAX_SIZE) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var err := image.save_png(path_for(kind))
	if err != OK:
		return "Couldn't save the image (error %d)." % err
	_cache.erase(kind)
	return ""


func texture(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	if not exists(kind):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path_for(kind)))
	if image == null:
		return null
	var tex := ImageTexture.create_from_image(image)
	_cache[kind] = tex
	return tex


func erase(kind: String) -> void:
	_cache.erase(kind)
	if exists(kind):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(kind)))
