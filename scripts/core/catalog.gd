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

const SLOTS: Array[String] = ["face_shape", "hair", "eyes", "mouth", "body", "accessory", "rig"]

const BASES := {
	"face_shape": ["round", "oval", "square", "egg", "unicorn"],
	"hair": ["bald", "buzz", "spiky", "mop", "mohawk", "rainbow"],
	"eyes": ["dots", "googly", "happy", "angry"],
	"mouth": ["smile", "grin", "oh", "flat"],
	"body": ["suit", "hoodie", "tshirt", "robe", "goat", "unicorn"],
	"accessory": ["glasses", "party_hat", "crown", "goat_horns", "wizard_hat", "unicorn_horn"],
	## What holds the head up. The spring-neck Bobble is the default and isn't an
	## item (rig index 0, like "no accessory"); the rest are collected.
	"rig": ["balloon", "marionette"],
}

const LABELS := {
	"face_shape": ["Round", "Oval", "Square", "Egg", "Unicorn"],
	"hair": ["Bald", "Buzz", "Spiky", "Mop", "Mohawk", "Rainbow mane"],
	"eyes": ["Dots", "Googly", "Happy", "Angry"],
	"mouth": ["Smile", "Grin", "Oh", "Flat"],
	"body": ["Suit", "Hoodie", "T-shirt", "Robe", "Goat", "Unicorn"],
	"accessory": ["Glasses", "Party hat", "Crown", "Goat horns", "Wizard hat", "Unicorn horn"],
	"rig": ["Balloon", "Marionette"],
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

## Rarity tiers.
##   COMMON       the regular drop pool
##   SUPER_RARE   the unicorn set: its own 1-in-500 roll (DropRules)
##   MULTIPLAYER  the rarest: unicorn horns #2-#4, which only drop in
##                multiplayer (iteration 3). No single-player pool has them.
enum Rarity { COMMON, SUPER_RARE, MULTIPLAYER }

## The unicorn set. Every style of the unicorn body counts; only horn #1 drops
## in single player.
const SUPER_RARE_ITEMS: Array[String] = [
	"face_shape/unicorn", "hair/rainbow",
	"body/unicorn/0", "body/unicorn/1", "body/unicorn/2", "body/unicorn/3",
	"accessory/unicorn_horn/0",
	"rig/balloon",
	"rig/marionette",
]
## Super-rares that only join the drop pool once the player has launched this
## many fireworks in total (the lifetime fireworks stat).
const FIREWORKS_TO_UNLOCK := {"rig/balloon": 500, "rig/marionette": 1000}

const MULTIPLAYER_ITEMS: Array[String] = [
	"accessory/unicorn_horn/1", "accessory/unicorn_horn/2", "accessory/unicorn_horn/3",
]


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


static func rarity(id: String) -> Rarity:
	if id in SUPER_RARE_ITEMS:
		return Rarity.SUPER_RARE
	if id in MULTIPLAYER_ITEMS:
		return Rarity.MULTIPLAYER
	return Rarity.COMMON


## False while an item is still waiting on its fireworks milestone.
static func can_drop_yet(id: String, fireworks_launched: int) -> bool:
	return fireworks_launched >= int(FIREWORKS_TO_UNLOCK.get(id, 0))


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
		"hair": return name if name.ends_with("mane") else "%s hair" % name
		"eyes": return "%s eyes" % name
		"mouth": return "%s mouth" % name
		"rig": return "%s rig" % name
	if parts.size() > 2:
		return "%s #%d" % [name, int(parts[2]) + 1]
	return name


static func body_color(base: int, variant: int) -> Color:
	return Variants.body(BASES["body"][base], variant)["base"]
