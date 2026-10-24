class_name CheatCodes
extends RefCounted
## Words typed while playing (no console: just type the word in the
## playground). Codes are for fun and never unlock items or achievements, so
## the collection and Steam stats stay honest.
##
## `release` decides which codes ship: true = works for players, false =
## development builds only. Flip these before shipping (see docs/plan.md,
## "Before shipping").

const CODES := {
	"confetti": {"release": true, "what": "A confetti burst"},
	"party": {"release": true, "what": "A big fireworks barrage (doesn't count toward achievements)"},
	"dizzy": {"release": true, "what": "Dizzy stars, any time"},
	"bighead": {"release": false, "what": "Head bigger than the slider allows, until you leave the playground"},
	"fastfaces": {"release": false, "what": "Face swaps 10x faster, until you quit"},
	"dropall": {"release": false, "what": "Every right-click drops something, until you quit"},
}

const MAX_LENGTH := 12

var _typed := ""


## Codes that work in this build.
static func available() -> Array[String]:
	var codes: Array[String] = []
	for code in CODES:
		if OS.is_debug_build() or bool(CODES[code]["release"]):
			codes.append(code)
	return codes


## Feed one typed character; returns a code when one has just been typed.
func type_char(c: String) -> String:
	_typed = (_typed + c.to_lower()).right(MAX_LENGTH)
	for code in available():
		if _typed.ends_with(code):
			_typed = ""
			return code
	return ""
