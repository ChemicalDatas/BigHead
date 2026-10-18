class_name HeadBuild
extends RefCounted
## One player-made bobblehead: head layers, head size and body.
## Head layers stay separate so the Steam face can later replace only the
## face layer while hair and accessory stay on.

const CATEGORIES: Array[String] = ["face_shape", "skin_tone", "hair", "eyes", "mouth", "accessory"]

const CATEGORY_LABELS := {
	"face_shape": "Face shape",
	"skin_tone": "Skin tone",
	"hair": "Hair",
	"eyes": "Eyes",
	"mouth": "Mouth",
	"accessory": "Accessory",
	"body_shape": "Body",
}

const OPTIONS := {
	"face_shape": ["Round", "Oval", "Square", "Egg"],
	"skin_tone": ["Tone 1", "Tone 2", "Tone 3", "Tone 4", "Tone 5", "Tone 6"],
	"hair": ["Bald", "Buzz", "Spiky", "Mop", "Mohawk"],
	"eyes": ["Dots", "Googly", "Happy", "Angry"],
	"mouth": ["Smile", "Grin", "Oh", "Flat"],
	"accessory": ["None", "Glasses", "Party hat", "Crown", "Goat horns"],
	"body_shape": ["Suit", "Hoodie", "T-shirt", "Robe", "Goat"],
}

const SKIN_TONES: Array[Color] = [
	Color("#f8dcc4"), Color("#ecc29c"), Color("#d49c6f"),
	Color("#a86d46"), Color("#7b4b2d"), Color("#4f301e"),
]

## Default body color per shape, used when a shape is picked for the first time.
const BODY_DEFAULT_COLORS: Array[Color] = [
	Color("#2f3a5c"), Color("#3c8d5a"), Color("#d35454"), Color("#6b4a9b"), Color("#ece4d4"),
]

const MAX_NAME_LENGTH := 20
const MIN_HEAD_SIZE := 0.8
const MAX_HEAD_SIZE := 1.5

var player_name := ""
var face_shape := 0
var skin_tone := 1
var hair := 2
var eyes := 1
var mouth := 0
var accessory := 2
var head_size := 1.0
var body_shape := 0
var body_color := BODY_DEFAULT_COLORS[0]
## True when the player uploaded a body texture (the image lives in UploadStore).
var use_body_texture := false


static func option_count(category: String) -> int:
	return (OPTIONS[category] as Array).size()


static func option_label(category: String, index: int) -> String:
	return str((OPTIONS[category] as Array)[index])


func get_choice(category: String) -> int:
	return int(get(category))


func set_choice(category: String, index: int) -> void:
	set(category, posmod(index, option_count(category)))


func cycle(category: String, step: int) -> void:
	set_choice(category, get_choice(category) + step)


func set_head_size(value: float) -> void:
	head_size = clampf(value, MIN_HEAD_SIZE, MAX_HEAD_SIZE)


func is_head_maxed() -> bool:
	return head_size >= MAX_HEAD_SIZE - 0.001


func randomize_all(rng: RandomNumberGenerator) -> void:
	for category in CATEGORIES:
		set_choice(category, rng.randi_range(0, option_count(category) - 1))
	set_choice("body_shape", rng.randi_range(0, option_count("body_shape") - 1))
	body_color = BODY_DEFAULT_COLORS[body_shape]


func skin_color() -> Color:
	return SKIN_TONES[skin_tone]


func to_dict() -> Dictionary:
	var data := {
		"player_name": player_name,
		"head_size": head_size,
		"body_shape": body_shape,
		"body_color": body_color.to_html(false),
		"use_body_texture": use_body_texture,
	}
	for category in CATEGORIES:
		data[category] = get_choice(category)
	return data


static func from_dict(data: Dictionary) -> HeadBuild:
	var build := HeadBuild.new()
	build.player_name = str(data.get("player_name", "")).left(MAX_NAME_LENGTH)
	for category in CATEGORIES:
		build.set_choice(category, int(data.get(category, build.get_choice(category))))
	build.set_head_size(float(data.get("head_size", 1.0)))
	build.set_choice("body_shape", int(data.get("body_shape", 0)))
	build.body_color = Color.from_string(str(data.get("body_color", "")), BODY_DEFAULT_COLORS[build.body_shape])
	build.use_body_texture = bool(data.get("use_body_texture", false))
	return build
