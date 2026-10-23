class_name Variants
extends RefCounted
## The four numbered variants (#1-#4) of every accessory and body. A variant
## never changes the shape, only colors and patterns:
##   base    main color
##   pattern "" (plain) or a Patterns kind drawn in `accent`
##   accent  pattern color (glasses: lens tint)
##   trim    secondary color (hat band, pom-pom, tie, hoodie strings)
##   gems    crown jewels
## Variant #1 of each item is its original look.

const ACCESSORIES := {
	"glasses": [
		{"base": Color("#2a1d17"), "pattern": "", "accent": Color(0.7, 0.85, 1.0, 0.18)},
		{"base": Color("#c0392b"), "pattern": "", "accent": Color(1.0, 0.62, 0.7, 0.3)},
		{"base": Color("#d4a017"), "pattern": "", "accent": Color(0.44, 0.72, 1.0, 0.3)},
		{"base": Color("#121214"), "pattern": "", "accent": Color(0.08, 0.08, 0.1, 0.85)},
	],
	"party_hat": [
		{"base": Color("#8e44ad"), "pattern": "hstripes", "accent": Color("#f1c40f"), "trim": Color("#f1c40f")},
		{"base": Color("#16a085"), "pattern": "dots", "accent": Color("#f7f1e3"), "trim": Color("#f39c12")},
		{"base": Color("#e84393"), "pattern": "stars", "accent": Color("#fff2a8"), "trim": Color("#ffffff")},
		{"base": Color("#e67e22"), "pattern": "zigzag", "accent": Color("#2d1b4e"), "trim": Color("#2d1b4e")},
	],
	"crown": [
		{"base": Color("#f2c037"), "pattern": "", "gems": [Color("#e74c3c"), Color("#3498db"), Color("#2ecc71")]},
		{"base": Color("#cfd6dd"), "pattern": "", "gems": [Color("#3a7bd5"), Color("#3a7bd5"), Color("#3a7bd5")]},
		{"base": Color("#e8a39b"), "pattern": "", "gems": [Color("#e84393"), Color("#ffffff"), Color("#ffffff")]},
		{"base": Color("#3b3b45"), "pattern": "", "gems": [Color("#9b59b6"), Color("#c0392b"), Color("#c0392b")]},
	],
	"goat_horns": [
		{"base": Color("#efe2c6"), "pattern": ""},
		{"base": Color("#4a4a52"), "pattern": ""},
		{"base": Color("#f2c037"), "pattern": ""},
		{"base": Color("#ffffff"), "pattern": "candy", "accent": Color("#d6303d")},
	],
	"wizard_hat": [
		{"base": Color("#2b3a8c"), "pattern": "stars", "accent": Color("#f7d046"), "trim": Color("#f7d046")},
		{"base": Color("#a8232f"), "pattern": "stripes", "accent": Color("#d1525a"), "trim": Color("#f2c037")},
		{"base": Color("#1f7a4d"), "pattern": "dots", "accent": Color("#9be3b8"), "trim": Color("#d8dde3")},
		{"base": Color("#1d1530"), "pattern": "zigzag", "accent": Color("#7b4bd8"), "trim": Color("#b48cff")},
	],
}

const BODIES := {
	"suit": [
		{"base": Color("#2f3a5c"), "pattern": "", "trim": Color("#c0392b")},
		{"base": Color("#3a3d45"), "pattern": "pinstripe", "accent": Color("#6a6e78"), "trim": Color("#2e86de")},
		{"base": Color("#7b1e2b"), "pattern": "", "trim": Color("#f2c037")},
		{"base": Color("#5b6b3a"), "pattern": "plaid", "accent": Color("#46532c"), "trim": Color("#1c1412")},
	],
	"hoodie": [
		{"base": Color("#3c8d5a"), "pattern": "", "trim": Color("#ffffff")},
		{"base": Color("#e05a8a"), "pattern": "stripes", "accent": Color("#f7c1d3"), "trim": Color("#ffffff")},
		{"base": Color("#7a8a52"), "pattern": "camo", "accent": Color("#4f5e33"), "trim": Color("#e8e2c8")},
		{"base": Color("#2f2f3a"), "pattern": "checks", "accent": Color("#e8e8e8"), "trim": Color("#e74c3c")},
	],
	"tshirt": [
		{"base": Color("#d35454"), "pattern": ""},
		{"base": Color("#2e86de"), "pattern": "hstripes", "accent": Color("#ffffff")},
		{"base": Color("#f1c40f"), "pattern": "dots", "accent": Color("#e67e22")},
		{"base": Color("#6b4ab0"), "pattern": "stars", "accent": Color("#f7d046")},
	],
	"robe": [
		{"base": Color("#6b4a9b"), "pattern": "", "trim": Color("#f2c037")},
		{"base": Color("#1f2a5a"), "pattern": "stars", "accent": Color("#f7d046"), "trim": Color("#f7d046")},
		{"base": Color("#a8232f"), "pattern": "zigzag", "accent": Color("#f2c037"), "trim": Color("#f2c037")},
		{"base": Color("#ece9e2"), "pattern": "dots", "accent": Color("#d4a017"), "trim": Color("#d4a017")},
	],
	"goat": [
		{"base": Color("#ece4d4"), "pattern": ""},
		{"base": Color("#8a5a3b"), "pattern": ""},
		{"base": Color("#2b2522"), "pattern": ""},
		{"base": Color("#ece4d4"), "pattern": "spots", "accent": Color("#8a5a3b")},
	],
}


static func accessory(base_name: String, variant: int) -> Dictionary:
	var list: Array = ACCESSORIES[base_name]
	return list[clampi(variant, 0, list.size() - 1)]


static func body(base_name: String, variant: int) -> Dictionary:
	var list: Array = BODIES[base_name]
	return list[clampi(variant, 0, list.size() - 1)]
