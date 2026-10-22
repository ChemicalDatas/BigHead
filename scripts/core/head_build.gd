class_name HeadBuild
extends RefCounted
## One player-made bobblehead: head layers, colors, head size and body.
## Head layers stay separate so the Steam face can later replace only the
## face layer while hair and accessory stay on.
##
## Shapes are stored as indices into Catalog.BASES; Catalog turns them into item
## ids for the inventory. Hair and skin colors are free; body color comes from
## the body's variant (or an uploaded texture).

## The pickable head parts, in the order the builder shows them.
const CATEGORIES: Array[String] = ["face_shape", "hair", "eyes", "mouth", "accessory"]

const CATEGORY_LABELS := {
	"face_shape": "Face shape",
	"hair": "Hair",
	"eyes": "Eyes",
	"mouth": "Mouth",
	"accessory": "Accessory",
	"body_shape": "Body",
}

## Swatches offered next to the free pickers.
const SKIN_PRESETS: Array[Color] = [
	Color("#f8dcc4"), Color("#ecc29c"), Color("#d49c6f"),
	Color("#a86d46"), Color("#7b4b2d"), Color("#4f301e"),
]
const HAIR_PRESETS: Array[Color] = [
	Color("#3b2416"), Color("#1c1412"), Color("#7a4a26"), Color("#d9a84e"),
	Color("#b5532d"), Color("#c0392b"), Color("#9aa3ad"), Color("#6b4ab0"),
]

const MAX_NAME_LENGTH := 20
const MIN_HEAD_SIZE := 0.8
const MAX_HEAD_SIZE := 1.5

var player_name := ""
var face_shape := 0
var hair := 1
var eyes := 0
var mouth := 0
## 0 = no accessory; 1.. = Catalog.BASES["accessory"][accessory - 1]
var accessory := 0
var accessory_variant := 0
var hair_color := HAIR_PRESETS[0]
var skin := SKIN_PRESETS[1]
var head_size := 1.0
var body_shape := 0
var body_variant := 0
## True when the player uploaded a body texture (the image lives in UploadStore).
var use_body_texture := false


# --------------------------------------------------------------------------
# Options and item ids
# --------------------------------------------------------------------------

## Catalog slot for a builder category.
static func slot_of(category: String) -> String:
	return "body" if category == "body_shape" else category


## How many choices a category has (accessory includes "None").
static func option_count(category: String) -> int:
	var n := Catalog.base_count(slot_of(category))
	return n + 1 if category == "accessory" else n


static func option_label(category: String, index: int) -> String:
	if category == "accessory":
		return "None" if index == 0 else Catalog.label("accessory", index - 1)
	return Catalog.label(slot_of(category), index)


## The catalog item behind a choice, or "" for "no accessory" (always available).
func item_id_for(category: String, index: int) -> String:
	match category:
		"accessory":
			return "" if index == 0 else Catalog.item_id("accessory", index - 1, accessory_variant)
		"body_shape":
			return Catalog.item_id("body", index, body_variant)
	return Catalog.item_id(category, index)


func is_option_owned(category: String, index: int, inventory: InventoryPort) -> bool:
	var id := item_id_for(category, index)
	return id == "" or inventory.owns(id)


## Categories whose current choice the player doesn't own yet.
func locked_categories(inventory: InventoryPort) -> Array[String]:
	var locked: Array[String] = []
	for category in CATEGORIES + ["body_shape"]:
		if not is_option_owned(category, get_choice(category), inventory):
			locked.append(category)
	return locked


## Replaces any choice the player doesn't own with the first one they do.
## Returns the categories that changed.
func sanitize(inventory: InventoryPort) -> Array[String]:
	var changed := locked_categories(inventory)
	for category in changed:
		if category == "accessory":
			accessory = 0
			continue
		for index in option_count(category):
			if is_option_owned(category, index, inventory):
				set_choice(category, index)
				break
	return changed


# --------------------------------------------------------------------------
# Choices
# --------------------------------------------------------------------------

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


## Random look from the items the player owns.
func randomize_all(rng: RandomNumberGenerator, inventory: InventoryPort) -> void:
	for category in CATEGORIES + ["body_shape"]:
		var owned: Array[int] = []
		for index in option_count(category):
			if is_option_owned(category, index, inventory):
				owned.append(index)
		if not owned.is_empty():
			set_choice(category, owned[rng.randi_range(0, owned.size() - 1)])
	hair_color = HAIR_PRESETS[rng.randi_range(0, HAIR_PRESETS.size() - 1)]
	skin = SKIN_PRESETS[rng.randi_range(0, SKIN_PRESETS.size() - 1)]


func skin_color() -> Color:
	return skin


func body_paint() -> Color:
	return Catalog.body_color(body_shape, body_variant)


# --------------------------------------------------------------------------
# Saving
# --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"face_shape": face_shape,
		"hair": hair,
		"eyes": eyes,
		"mouth": mouth,
		"accessory": accessory,
		"accessory_variant": accessory_variant,
		"hair_color": hair_color.to_html(false),
		"skin": skin.to_html(false),
		"head_size": head_size,
		"body_shape": body_shape,
		"body_variant": body_variant,
		"use_body_texture": use_body_texture,
	}


static func from_dict(data: Dictionary) -> HeadBuild:
	var build := HeadBuild.new()
	build.player_name = str(data.get("player_name", "")).left(MAX_NAME_LENGTH)
	for category in CATEGORIES + ["body_shape"]:
		build.set_choice(category, int(data.get(category, build.get_choice(category))))
	build.accessory_variant = clampi(int(data.get("accessory_variant", 0)), 0, Catalog.variant_count("accessory") - 1)
	build.body_variant = clampi(int(data.get("body_variant", 0)), 0, Catalog.variant_count("body") - 1)
	build.hair_color = Color.from_string(str(data.get("hair_color", "")), HAIR_PRESETS[0])
	if data.has("skin"):
		build.skin = Color.from_string(str(data["skin"]), SKIN_PRESETS[1])
	elif data.has("skin_tone"):
		# Saves from before the skin color picker stored one of six tones.
		build.skin = SKIN_PRESETS[clampi(int(data["skin_tone"]), 0, SKIN_PRESETS.size() - 1)]
	build.set_head_size(float(data.get("head_size", 1.0)))
	build.use_body_texture = bool(data.get("use_body_texture", false))
	return build
