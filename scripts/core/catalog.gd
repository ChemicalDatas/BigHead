class_name Catalog
extends RefCounted
## Every collectible item, as data. An item id looks like "hair/spiky",
## "body/suit/0" or "accessory/crown/0" (slot / base / variant).
##
## Slots with variants (body, accessory) keep the same shape across variants
## and differ only by colors and patterns (see Variants). Players see variants
## numbered #1-#4; ids count from 0.
##
## HeadBuild still stores choices as indices; this file maps them to ids.
## Accessory index 0 means "none" and is never an item; index 1 is the first base.

const SLOTS: Array[String] = ["face_shape", "hair", "eyes", "mouth", "body", "accessory"]

const BASES := {
	"face_shape": ["round", "oval", "square", "egg"],
	"hair": ["bald", "buzz", "spiky", "mop", "mohawk"],
	"eyes": ["dots", "googly", "happy", "angry"],
	"mouth": ["smile", "grin", "oh", "flat"],
	"body": ["suit", "hoodie", "tshirt", "robe", "goat"],
	"accessory": ["glasses", "party_hat", "crown", "goat_horns", "wizard_hat"],
}

const LABELS := {
	"face_shape": ["Round", "Oval", "Square", "Egg"],
	"hair": ["Bald", "Buzz", "Spiky", "Mop", "Mohawk"],
	"eyes": ["Dots", "Googly", "Happy", "Angry"],
	"mouth": ["Smile", "Grin", "Oh", "Flat"],
	"body": ["Suit", "Hoodie", "T-shirt", "Robe", "Goat"],
	"accessory": ["Glasses", "Party hat", "Crown", "Goat horns", "Wizard hat"],
}

## Variants per base.
const VARIANT_COUNT := {"body": 4, "accessory": 4}

## What every new player owns: two options each of face shape, hair style,
## eyes, mouth and body. No accessories; the first one comes from a drop.
const STARTING_SET: Array[String] = [
	"face_shape/round", "face_shape/oval",
	"hair/buzz", "hair/spiky",
	"eyes/dots", "eyes/googly",
	"mouth/smile", "mouth/grin",
]
## Starting items that come in styles: each new player gets one randomly
## chosen style (#1-#4) of each.
const STARTING_STYLED := {"body": ["suit", "tshirt"]}

## Rarity tiers. Super-rares (the unicorn set, step 3) roll separately from the
## regular drop pool.
enum Rarity { COMMON, SUPER_RARE }


## The starting items for a new player, with random styles for STARTING_STYLED.
static func starting_items(rng: RandomNumberGenerator) -> Array[String]:
	var ids: Array[String] = STARTING_SET.duplicate()
	for slot in STARTING_STYLED:
		for base_name in STARTING_STYLED[slot]:
			var base: int = (BASES[slot] as Array).find(base_name)
			ids.append(item_id(slot, base, rng.randi_range(0, variant_count(slot) - 1)))
	return ids


static func base_count(slot: String) -> int:
	return (BASES[slot] as Array).size()


static func variant_count(slot: String) -> int:
	return int(VARIANT_COUNT.get(slot, 1))


static func label(slot: String, base: int) -> String:
	return str((LABELS[slot] as Array)[base])


static func item_id(slot: String, base: int, variant := 0) -> String:
	var id := "%s/%s" % [slot, (BASES[slot] as Array)[base]]
	if VARIANT_COUNT.has(slot):
		id += "/%d" % variant
	return id


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for slot in SLOTS:
		for base in base_count(slot):
			for variant in variant_count(slot):
				ids.append(item_id(slot, base, variant))
	return ids


static func rarity(_id: String) -> Rarity:
	return Rarity.COMMON


## A player-facing name for an item: "Mop hair", "Party hat #2", "Hoodie #3".
static func display_name(id: String) -> String:
	var parts := id.split("/")
	var slot := parts[0]
	var base: int = (BASES[slot] as Array).find(parts[1])
	if base < 0:
		return id
	var name := label(slot, base)
	match slot:
		"face_shape": return "%s face" % name
		"hair": return "%s hair" % name
		"eyes": return "%s eyes" % name
		"mouth": return "%s mouth" % name
	if parts.size() > 2:
		return "%s #%d" % [name, int(parts[2]) + 1]
	return name


static func body_color(base: int, variant: int) -> Color:
	return Variants.body(BASES["body"][base], variant)["base"]
