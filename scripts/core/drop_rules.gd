class_name DropRules
extends RefCounted
## What a right-click drops. Pure rules: randomness comes in, a result goes out.
##
## Each right-click rolls once, however many rockets it launches:
##   1. The super-rare roll (its own chance, its own pool). A hit there wins.
##   2. Otherwise the regular roll: the item is picked from the WHOLE regular
##      pool, owned items included. An owned item becomes a burst of confetti,
##      so new items get rarer as the collection grows (no pity timer).
## Some super-rares (the rigs) only join their pool after a fireworks
## milestone; see Catalog.FIREWORKS_TO_UNLOCK.

## Default chance per right-click of a regular drop (gift box or confetti).
const DEFAULT_DROP_RATE := 0.05
## Chance per right-click of a super-rare drop, rolled before the regular one.
const SUPER_RARE_RATE := 0.002

enum Kind { NOTHING, NEW_ITEM, DUPLICATE }


class Result:
	var kind: Kind = Kind.NOTHING
	var item_id := ""
	var super_rare := false


## `owned` should include items waiting in unopened gift boxes, so two boxes
## never hold the same new item.
static func roll(rng: RandomNumberGenerator, drop_rate: float, owned: Callable, fireworks_launched := 0) -> Result:
	var result := Result.new()
	var super_pool := pool(Catalog.Rarity.SUPER_RARE, fireworks_launched)
	if not super_pool.is_empty() and rng.randf() < SUPER_RARE_RATE:
		result.super_rare = true
		_pick(rng, super_pool, owned, result)
		return result
	if rng.randf() < drop_rate:
		_pick(rng, pool(Catalog.Rarity.COMMON), owned, result)
	return result


## Items of a rarity that can drop now. Leave `fireworks_launched` out to
## ignore the fireworks milestones.
static func pool(rarity: Catalog.Rarity, fireworks_launched := 1 << 30) -> Array[String]:
	var ids: Array[String] = []
	for id in Catalog.all_ids():
		if Catalog.rarity(id) == rarity and Catalog.can_drop_yet(id, fireworks_launched):
			ids.append(id)
	return ids


static func _pick(rng: RandomNumberGenerator, from: Array[String], owned: Callable, result: Result) -> void:
	if from.is_empty():
		return
	result.item_id = from[rng.randi_range(0, from.size() - 1)]
	result.kind = Kind.DUPLICATE if owned.call(result.item_id) else Kind.NEW_ITEM
