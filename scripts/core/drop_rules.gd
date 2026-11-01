class_name DropRules
extends RefCounted
## What drops, and where. Pure rules: randomness comes in, a result goes out.
##
## Where each rarity can drop (Catalog.Rarity):
##   playground (single player)  COMMON
##   shared room (multiplayer)   COMMON, SUPER_RARE, MULTIPLAYER
##   desktop buddy               COMMON, SUPER_RARE, EFFECT
##
## Fireworks (playground and room) roll once per rocket, so friends' rockets
## and big barrages drop more. The desktop buddy has no fireworks: it gets
## timed drops instead (Game.TIMED_DROP_MIN/MAX), each of which always drops.
##
## Picking an item: owned items stay in every pool (an owned item becomes a
## burst of confetti), but each item you don't own yet is NEW_ITEM_WEIGHT
## times as likely as one you do. That keeps the end of the collection from
## dragging on for hours.
##
## Tuning target: someone who plays about 5 fireworks a minute and splits
## their time between the three modes owns everything after about 4 hours
## on average (simulated: mean 3.9 h, median 3.75 h, 90% within 5 h).
## Some super-rares (the rigs) only join their pool after a fireworks
## milestone; see Catalog.FIREWORKS_TO_UNLOCK.

## Chance per rocket of a regular drop (gift box or confetti). Playground and room.
const DEFAULT_DROP_RATE := 0.18
## Chance per rocket in a shared room of a super-rare or multiplayer-only
## drop, rolled before the regular one.
const ROOM_SPECIAL_RATE := 0.07
## What a desktop buddy timed drop is: these shares of effects and super-rares,
## the rest regular items.
const BUDDY_EFFECT_SHARE := 0.4
const BUDDY_SPECIAL_SHARE := 0.3
## How much likelier an item you don't own yet is to be picked than one you do.
const NEW_ITEM_WEIGHT := 3.0

enum Kind { NOTHING, NEW_ITEM, DUPLICATE }
enum Source { PLAYGROUND, ROOM, BUDDY }


class Result:
	var kind: Kind = Kind.NOTHING
	var item_id := ""
	## True for SUPER_RARE and MULTIPLAYER items (the rainbow gift box).
	var super_rare := false


## One rocket's roll, in the playground or a shared room.
## `owned` should include items waiting in unopened gift boxes, so two boxes
## never hold the same new item.
static func roll_firework(rng: RandomNumberGenerator, source: Source, drop_rate: float, owned: Callable, fireworks_launched := 0) -> Result:
	var result := Result.new()
	if source == Source.ROOM and rng.randf() < ROOM_SPECIAL_RATE:
		var special := pool(Catalog.Rarity.SUPER_RARE, fireworks_launched)
		special.append_array(pool(Catalog.Rarity.MULTIPLAYER, fireworks_launched))
		if not special.is_empty():
			_pick(rng, special, owned, result)
			return result
	if rng.randf() < drop_rate:
		_pick(rng, pool(Catalog.Rarity.COMMON), owned, result)
	return result


## A desktop buddy timed drop: always something (an effect, a super-rare or
## a regular item; never a multiplayer-only one). Every regular item the
## player is missing is in the buddy's pool too, and once the effects or
## super-rares are all owned, their share goes to the regular items instead.
static func roll_timed(rng: RandomNumberGenerator, owned: Callable, fireworks_launched := 0) -> Result:
	var result := Result.new()
	var x := rng.randf()
	var from: Array[String] = []
	if x < BUDDY_EFFECT_SHARE:
		from = pool(Catalog.Rarity.EFFECT)
	elif x < BUDDY_EFFECT_SHARE + BUDDY_SPECIAL_SHARE:
		from = pool(Catalog.Rarity.SUPER_RARE, fireworks_launched)
	if from.is_empty() or _all_owned(from, owned):
		from = pool(Catalog.Rarity.COMMON)
	_pick(rng, from, owned, result)
	return result


## Items of a rarity that can drop now. Leave `fireworks_launched` out to
## ignore the fireworks milestones.
static func pool(rarity: Catalog.Rarity, fireworks_launched := 1 << 30) -> Array[String]:
	var ids: Array[String] = []
	for id in Catalog.all_ids():
		if Catalog.rarity(id) == rarity and Catalog.can_drop_yet(id, fireworks_launched):
			ids.append(id)
	return ids


static func _all_owned(ids: Array[String], owned: Callable) -> bool:
	for id in ids:
		if not owned.call(id):
			return false
	return true


## Weighted pick: unowned items count NEW_ITEM_WEIGHT, owned ones 1.
static func _pick(rng: RandomNumberGenerator, from: Array[String], owned: Callable, result: Result) -> void:
	if from.is_empty():
		return
	var weights := PackedFloat32Array()
	for id in from:
		weights.append(1.0 if owned.call(id) else NEW_ITEM_WEIGHT)
	result.item_id = from[rng.rand_weighted(weights)]
	result.kind = Kind.DUPLICATE if owned.call(result.item_id) else Kind.NEW_ITEM
	var rarity := Catalog.rarity(result.item_id)
	result.super_rare = rarity == Catalog.Rarity.SUPER_RARE or rarity == Catalog.Rarity.MULTIPLAYER
