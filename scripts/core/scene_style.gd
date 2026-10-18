class_name SceneStyle
extends RefCounted
## Everything around the bobblehead: background and banner.

const BACKGROUNDS: Array[String] = ["Night", "Sunset", "Spotlight", "Office", "Party"]

## Index 0 is Godot's built-in font; the rest ship in res://assets/fonts (open licenses).
const FONT_NAMES: Array[String] = ["Classic", "Bangers", "Luckiest Guy", "Lobster", "Pacifico", "Press Start 2P"]
const FONT_FILES: Array[String] = [
	"",
	"res://assets/fonts/Bangers-Regular.ttf",
	"res://assets/fonts/LuckiestGuy-Regular.ttf",
	"res://assets/fonts/Lobster-Regular.ttf",
	"res://assets/fonts/Pacifico-Regular.ttf",
	"res://assets/fonts/PressStart2P-Regular.ttf",
]

var background := 0
## True when the player uploaded a background image (the image lives in UploadStore).
var use_background_image := false
var banner_color := Color("#c0392b")
var banner_text_color := Color.WHITE
var banner_font := 0


func cycle_background(step: int) -> void:
	background = posmod(background + step, BACKGROUNDS.size())


func cycle_font(step: int) -> void:
	banner_font = posmod(banner_font + step, FONT_NAMES.size())


func font() -> Font:
	var path := FONT_FILES[banner_font]
	return load(path) as Font if path != "" else null


func to_dict() -> Dictionary:
	return {
		"background": background,
		"use_background_image": use_background_image,
		"banner_color": banner_color.to_html(false),
		"banner_text_color": banner_text_color.to_html(false),
		"banner_font": banner_font,
	}


static func from_dict(data: Dictionary) -> SceneStyle:
	var style := SceneStyle.new()
	style.background = posmod(int(data.get("background", 0)), BACKGROUNDS.size())
	style.use_background_image = bool(data.get("use_background_image", false))
	style.banner_color = Color.from_string(str(data.get("banner_color", "")), style.banner_color)
	style.banner_text_color = Color.from_string(str(data.get("banner_text_color", "")), style.banner_text_color)
	style.banner_font = posmod(int(data.get("banner_font", 0)), FONT_NAMES.size())
	return style
