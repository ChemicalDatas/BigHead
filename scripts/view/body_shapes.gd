class_name BodyShapes
extends RefCounted
## Body outlines in HeadView's local space (origin = neck pivot).
## A body texture maps onto TEXTURE_BOX: the whole uploaded image covers that
## box, and each shape shows the part of it inside its outlines (torso, plus
## arms for people and legs for animals).
##
## People (suit, hoodie, T-shirt, robe) have two arms; animals (goat, unicorn)
## have four legs and no arms. Arms and legs belong to the body: they stay put
## while the head bobbles.

const TEXTURE_BOX := Rect2(-90, 30, 180, 150)

## People bodies are drawn this much narrower than their outlines below, so
## the head stays the focal point. Animals keep their full width.
const PEOPLE_WIDTH := 0.72

const GOAT := 4
const UNICORN := 5

## The right arm of each person body (the left one mirrors it), and where its
## hand sits. The inner edge tucks under the torso, which is drawn on top.
const _ARMS := {
	0: [Vector2(50, 44), Vector2(68, 56), Vector2(96, 140), Vector2(80, 147), Vector2(62, 92)],   # Suit
	1: [Vector2(52, 42), Vector2(72, 52), Vector2(100, 140), Vector2(84, 147), Vector2(68, 96)],  # Hoodie
	2: [Vector2(60, 94), Vector2(74, 100), Vector2(82, 146), Vector2(68, 148)],                   # T-shirt: bare arm below the sleeve
	3: [Vector2(44, 42), Vector2(64, 56), Vector2(110, 124), Vector2(86, 140), Vector2(60, 100)], # Robe: wide sleeve
}
const _HANDS := {0: Vector2(90, 151), 1: Vector2(94, 151), 2: Vector2(76, 153), 3: Vector2(100, 138)}
const HAND_RADIUS := 9.0


static func is_animal(shape: int) -> bool:
	return shape == GOAT or shape == UNICORN


## Horizontal scale for a body shape (see PEOPLE_WIDTH).
static func width_scale(shape: int) -> float:
	return 1.0 if is_animal(shape) else PEOPLE_WIDTH


static func _slim(shape: int, pts: PackedVector2Array) -> PackedVector2Array:
	var k := width_scale(shape)
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * k, p.y))
	return out


## Both arms (right, then left), or none for animals.
static func arms(shape: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not _ARMS.has(shape):
		return out
	var right := _slim(shape, PackedVector2Array(_ARMS[shape]))
	var left := PackedVector2Array()
	for p in right:
		left.append(Vector2(-p.x, p.y))
	out.append(right)
	out.append(left)
	return out


static func hands(shape: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if _HANDS.has(shape):
		var h: Vector2 = _HANDS[shape] * Vector2(width_scale(shape), 1.0)
		out.append(h)
		out.append(Vector2(-h.x, h.y))
	return out


## True when the arm is bare skin (the T-shirt) rather than a sleeve.
static func bare_arms(shape: int) -> bool:
	return shape == 2


static func outline(shape: int) -> PackedVector2Array:
	return _slim(shape, _full_outline(shape))


static func _full_outline(shape: int) -> PackedVector2Array:
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
		UNICORN:  # Unicorn: a smooth barrel on four legs, rainbow tail behind (see tail)
			var smooth := PackedVector2Array()
			for i in range(96):
				var t := TAU * float(i) / 96.0
				smooth.append(Vector2(0, 98) + Vector2(cos(t) * 74.0, sin(t) * 52.0))
			return smooth
		GOAT:  # Goat: a fluffy blob standing on four legs (see legs)
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


## An animal's four legs as rectangles (drawn behind the body, hooves at the
## bottom). People have none.
static func legs(shape: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if is_animal(shape):
		for x in [-50.0, -22.0, 10.0, 38.0]:
			out.append(Rect2(x, 130, 13, 46))
	return out


static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## The center line of the unicorn's tail, from the rump out and down.
static func tail_curve() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a := Vector2(-64, 84)
	var b := Vector2(-116, 92)
	var c := Vector2(-94, 164)
	for i in range(21):
		var t := float(i) / 20.0
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return pts


static func uvs(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append((p - TEXTURE_BOX.position) / TEXTURE_BOX.size)
	return out
