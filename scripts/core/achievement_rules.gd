class_name AchievementRules
extends RefCounted
## Game events in, achievement unlocks out. No Steam calls here.
##
## Events and their data:
##   "reveal_finished"      {}
##   "head_clicked"         {}                       (stats.clicks already counted)
##   "drag_released"        {"speed": px/s}
##   "fireworks_launched"   {"count": rockets in this click}  (stats.fireworks already counted)
##   "bobbling_for"         {"seconds": continuous bobbling}
##   "still_for"            {"seconds": continuous rest}
##   "head_size_maxed"      {}
##   "balloon_popped"       {"cause": "whiplash" | "ground" | "firework"}

const BIG_HEAD := "BIG_HEAD"
const WHIPLASH := "WHIPLASH"
const PERPETUAL_MOTION := "PERPETUAL_MOTION"
const BOBBLE_BOOP := "BOBBLE_BOOP"
const OOH_AAH := "OOH_AAH"
const ITS_A_PARTY := "ITS_A_PARTY"
const GRAND_FINALE := "GRAND_FINALE"
const LEVEL_HEADED := "LEVEL_HEADED"
const SWELLED_HEAD := "SWELLED_HEAD"
const POP_GOES_THE_HEAD := "POP_GOES_THE_HEAD"

const ALL: Array[String] = [
	BIG_HEAD, WHIPLASH, PERPETUAL_MOTION, BOBBLE_BOOP, OOH_AAH,
	ITS_A_PARTY, GRAND_FINALE, LEVEL_HEADED, SWELLED_HEAD, POP_GOES_THE_HEAD,
]

const WHIPLASH_SPEED := 2200.0        ## px/s at drag release
const PERPETUAL_SECONDS := 60.0
const BOBBLE_BOOP_CLICKS := 100
const OOH_AAH_FIREWORKS := 50
const PARTY_ROCKETS := 5              ## you + 4 friends with Big Head
const FINALE_ROCKETS := 20            ## you + 19 friends with Big Head
const LEVEL_HEADED_SECONDS := 300.0

## Stat names (see StatsPort).
const STAT_CLICKS := "clicks"
const STAT_FIREWORKS := "fireworks"


static func unlocks_for(event: String, data: Dictionary, stats: Dictionary, steam_available: bool) -> Array[String]:
	var unlocks: Array[String] = []
	# Non-Steam players get no achievements and no toasts.
	if not steam_available:
		return unlocks
	match event:
		"reveal_finished":
			unlocks.append(BIG_HEAD)
		"head_clicked":
			if int(stats.get(STAT_CLICKS, 0)) >= BOBBLE_BOOP_CLICKS:
				unlocks.append(BOBBLE_BOOP)
		"drag_released":
			if float(data.get("speed", 0.0)) >= WHIPLASH_SPEED:
				unlocks.append(WHIPLASH)
		"fireworks_launched":
			var count := int(data.get("count", 0))
			if count >= PARTY_ROCKETS:
				unlocks.append(ITS_A_PARTY)
			if count >= FINALE_ROCKETS:
				unlocks.append(GRAND_FINALE)
			if int(stats.get(STAT_FIREWORKS, 0)) >= OOH_AAH_FIREWORKS:
				unlocks.append(OOH_AAH)
		"bobbling_for":
			if float(data.get("seconds", 0.0)) >= PERPETUAL_SECONDS:
				unlocks.append(PERPETUAL_MOTION)
		"still_for":
			if float(data.get("seconds", 0.0)) >= LEVEL_HEADED_SECONDS:
				unlocks.append(LEVEL_HEADED)
		"head_size_maxed":
			unlocks.append(SWELLED_HEAD)
		"balloon_popped":
			unlocks.append(POP_GOES_THE_HEAD)
	return unlocks


## Which stat an event bumps, and by how much.
static func stat_deltas(event: String, data: Dictionary) -> Dictionary:
	match event:
		"head_clicked":
			return {STAT_CLICKS: 1}
		"fireworks_launched":
			return {STAT_FIREWORKS: int(data.get("count", 0))}
	return {}
