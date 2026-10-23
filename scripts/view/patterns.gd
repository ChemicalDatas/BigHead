class_name Patterns
extends RefCounted
## Small tiling pattern textures for item variants, generated in code and
## cached. A variant is a base color plus a pattern drawn in an accent color.

const SIZE := 128

static var _cache := {}


static func texture(kind: String, base: Color, accent: Color) -> Texture2D:
	var key := "%s|%s|%s" % [kind, base.to_html(), accent.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(base)
	match kind:
		"stripes": _stripes(img, accent)
		"dots": _dots(img, accent)
		"stars": _stars(img, accent)
		"camo": _camo(img, base, accent)
		"checks": _checks(img, accent)
		"zigzag": _zigzag(img, accent)
		"hstripes": _hstripes(img, accent)
		"pinstripe": _pinstripe(img, accent)
		"plaid": _plaid(img, accent)
		"spots": _spots(img, accent)
		"candy": _stripes(img, accent)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _stripes(img: Image, c: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			if posmod(x + y, 32) < 12:
				img.set_pixel(x, y, c)


static func _hstripes(img: Image, c: Color) -> void:
	for y in SIZE:
		if posmod(y, 32) < 12:
			for x in SIZE:
				img.set_pixel(x, y, c)


static func _pinstripe(img: Image, c: Color) -> void:
	for x in SIZE:
		if posmod(x, 16) < 2:
			for y in SIZE:
				img.set_pixel(x, y, c)


## Two crossing sets of soft bands.
static func _plaid(img: Image, c: Color) -> void:
	var soft := Color(c, 0.6)
	for y in SIZE:
		for x in SIZE:
			var hx := posmod(x, 32) < 10
			var hy := posmod(y, 32) < 10
			if hx and hy:
				img.set_pixel(x, y, c)
			elif hx or hy:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(soft))
			if posmod(x, 32) == 20 or posmod(y, 32) == 20:
				img.set_pixel(x, y, c.darkened(0.3))


## Irregular animal spots.
static func _spots(img: Image, c: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var p := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var rad := rng.randf_range(9.0, 16.0)
		_disc(img, p, rad, c)
		_disc(img, p + Vector2(rad * 0.6, rad * 0.3), rad * 0.6, c)


static func _dots(img: Image, c: Color) -> void:
	for cy in [0, 32, 64, 96]:
		for cx in [0, 32, 64, 96]:
			var ox := 16 if (cy / 32) % 2 == 1 else 0
			_disc(img, Vector2(cx + ox + 8, cy + 16), 7.0, c)


static func _checks(img: Image, c: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			if ((x / 32) + (y / 32)) % 2 == 0:
				img.set_pixel(x, y, c)


static func _zigzag(img: Image, c: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			var tri := absf(fmod(float(x), 32.0) - 16.0)
			if posmod(y - int(tri), 32) < 8:
				img.set_pixel(x, y, c)


static func _camo(img: Image, base: Color, c: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var second := base.lerp(c, 0.5).darkened(0.15)
	for i in 14:
		var p := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		_disc(img, p, rng.randf_range(10.0, 20.0), c if i % 2 == 0 else second)


static func _stars(img: Image, c: Color) -> void:
	for p in [Vector2(20, 22), Vector2(84, 14), Vector2(52, 60), Vector2(108, 76), Vector2(22, 100), Vector2(78, 110)]:
		_star(img, p, 9.0, c)
	for p in [Vector2(60, 24), Vector2(10, 62), Vector2(100, 42), Vector2(46, 96), Vector2(120, 118)]:
		_disc(img, p, 2.0, c)


## Draws with wrap-around so every pattern tiles seamlessly.
static func _disc(img: Image, center: Vector2, radius: float, c: Color) -> void:
	for dy in range(-int(radius) - 1, int(radius) + 2):
		for dx in range(-int(radius) - 1, int(radius) + 2):
			if Vector2(dx, dy).length() <= radius:
				img.set_pixel(posmod(int(center.x) + dx, SIZE), posmod(int(center.y) + dy, SIZE), c)


static func _star(img: Image, center: Vector2, radius: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + TAU * k / 10.0
		pts.append(center + Vector2.from_angle(a) * (radius if k % 2 == 0 else radius * 0.45))
	for dy in range(-int(radius) - 1, int(radius) + 2):
		for dx in range(-int(radius) - 1, int(radius) + 2):
			var p := center + Vector2(dx, dy)
			if Geometry2D.is_point_in_polygon(p, pts):
				img.set_pixel(posmod(int(p.x), SIZE), posmod(int(p.y), SIZE), c)
