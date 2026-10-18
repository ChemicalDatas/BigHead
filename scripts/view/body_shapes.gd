class_name BodyShapes
extends RefCounted
## Body outlines in HeadView's local space (origin = neck pivot).
## A body texture maps onto TEXTURE_BOX: the whole uploaded image covers that
## box, and each shape shows the part of it inside its outline.

const TEXTURE_BOX := Rect2(-90, 30, 180, 150)


static func outline(shape: int) -> PackedVector2Array:
	match shape:
		1:  # Hoodie
			return PackedVector2Array([
				Vector2(-72, 172), Vector2(-71, 84), Vector2(-60, 50), Vector2(-34, 34),
				Vector2(34, 34), Vector2(60, 50), Vector2(71, 84), Vector2(72, 172),
			])
		2:  # T-shirt, with sleeves
			return PackedVector2Array([
				Vector2(-58, 172), Vector2(-57, 98), Vector2(-74, 106), Vector2(-88, 72),
				Vector2(-50, 36), Vector2(50, 36), Vector2(88, 72), Vector2(74, 106),
				Vector2(57, 98), Vector2(58, 172),
			])
		3:  # Robe
			return PackedVector2Array([
				Vector2(-88, 178), Vector2(-62, 64), Vector2(-38, 36), Vector2(38, 36),
				Vector2(62, 64), Vector2(88, 178),
			])
		4:  # Goat: a fluffy blob standing on four legs (see goat_legs)
			var pts := PackedVector2Array()
			for i in range(168):
				var t := TAU * float(i) / 168.0
				var fluff := 1.0 + 0.07 * sin(t * 14.0)
				pts.append(Vector2(0, 98) + Vector2(cos(t) * 74.0, sin(t) * 56.0) * fluff)
			return pts
		_:  # Suit
			return PackedVector2Array([
				Vector2(-70, 172), Vector2(-62, 70), Vector2(-40, 36), Vector2(40, 36),
				Vector2(62, 70), Vector2(70, 172),
			])


## The goat's legs as rectangles (drawn behind the body, hooves at the bottom).
static func goat_legs() -> Array[Rect2]:
	var legs: Array[Rect2] = []
	for x in [-50.0, -22.0, 10.0, 38.0]:
		legs.append(Rect2(x, 130, 13, 46))
	return legs


static func uvs(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append((p - TEXTURE_BOX.position) / TEXTURE_BOX.size)
	return out
