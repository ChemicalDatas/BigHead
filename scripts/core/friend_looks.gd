class_name FriendLooks
extends RefCounted
## A friend on the shelf: their Steam avatar as the face, on a body, hair and
## accessory picked from their Steam ID. The same friend always gets the same
## look (the ID seeds the random picks), and their real custom build is never
## fetched, so nothing has to be shared or synced to fill the shelf.
##
## Picks come from the common items only: no unicorn set, no rigs.

## Hair styles, bodies and accessories a friend can get (Catalog base names).
## "" for the accessory means none.
const HAIR := ["bald", "buzz", "spiky", "mop", "mohawk"]
const BODIES := ["suit", "hoodie", "tshirt", "robe", "goat"]
const ACCESSORIES := ["", "", "glasses", "party_hat", "crown", "goat_horns", "wizard_hat"]
const FACES := ["round", "oval", "square", "egg"]


static func build_for(steam_id: int, name := "") -> HeadBuild:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("big-head-friend-%d" % steam_id)
	var build := HeadBuild.new()
	build.player_name = name
	build.face_shape = _index("face_shape", FACES[rng.randi_range(0, FACES.size() - 1)])
	build.hair = _index("hair", HAIR[rng.randi_range(0, HAIR.size() - 1)])
	build.hair_color = HeadBuild.HAIR_PRESETS[rng.randi_range(0, HeadBuild.HAIR_PRESETS.size() - 1)]
	build.skin = HeadBuild.SKIN_PRESETS[rng.randi_range(0, HeadBuild.SKIN_PRESETS.size() - 1)]
	build.eyes = rng.randi_range(0, 3)
	build.mouth = rng.randi_range(0, 3)
	build.body_shape = _index("body", BODIES[rng.randi_range(0, BODIES.size() - 1)])
	build.body_variant = rng.randi_range(0, Catalog.variant_count("body") - 1)
	var hat: String = ACCESSORIES[rng.randi_range(0, ACCESSORIES.size() - 1)]
	build.accessory = 0 if hat == "" else _index("accessory", hat) + 1
	build.accessory_variant = rng.randi_range(0, Catalog.variant_count("accessory") - 1)
	return build


static func _index(slot: String, base_name: String) -> int:
	return maxi((Catalog.BASES[slot] as Array).find(base_name), 0)
