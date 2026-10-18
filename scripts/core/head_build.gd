class_name HeadBuild
extends RefCounted
## One player-made head. Layers stay separate so the Steam face can later
## replace only the face layer while hair and accessory stay on.

const CATEGORIES: Array[String] = ["face_shape", "skin_tone", "hair", "eyes", "mouth", "accessory"]

const CATEGORY_LABELS := {
	"face_shape": "Face shape",
	"skin_tone": "Skin tone",
	"hair": "Hair",
	"eyes": "Eyes",
	"mouth": "Mouth",
	"accessory": "Accessory",
}

const OPTIONS := {
	"face_shape": ["Round", "Oval", "Square", "Egg"],
	"skin_tone": ["Tone 1", "Tone 2", "Tone 3", "Tone 4", "Tone 5", "Tone 6"],
	"hair": ["Bald", "Buzz", "Spiky", "Mop", "Mohawk"],
	"eyes": ["Dots", "Googly", "Happy", "Angry"],
	"mouth": ["Smile", "Grin", "Oh", "Flat"],
	"accessory": ["None", "Glasses", "Party hat", "Crown", "Goat horns"],
}

const SKIN_TONES: Array[Color] = [
	Color("#f8dcc4"), Color("#ecc29c"), Color("#d49c6f"),
	Color("#a86d46"), Color("#7b4b2d"), Color("#4f301e"),
]

const MAX_NAME_LENGTH := 20

var player_name := ""
var face_shape := 0
var skin_tone := 1
var hair := 2
var eyes := 1
var mouth := 0
var accessory := 2


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


func randomize_all(rng: RandomNumberGenerator) -> void:
	for category in CATEGORIES:
		set_choice(category, rng.randi_range(0, option_count(category) - 1))


func skin_color() -> Color:
	return SKIN_TONES[skin_tone]


func to_dict() -> Dictionary:
	var data := {"player_name": player_name}
	for category in CATEGORIES:
		data[category] = get_choice(category)
	return data


static func from_dict(data: Dictionary) -> HeadBuild:
	var build := HeadBuild.new()
	build.player_name = str(data.get("player_name", "")).left(MAX_NAME_LENGTH)
	for category in CATEGORIES:
		build.set_choice(category, int(data.get(category, build.get_choice(category))))
	return build
