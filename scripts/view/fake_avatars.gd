class_name FakeAvatars
extends RefCounted
## Stand-in Steam avatars for --fake-friends: a bright square with a simple
## cartoon face, different for each friend.

const BACKGROUNDS: Array[Color] = [
	Color("#e17055"), Color("#00b894"), Color("#0984e3"), Color("#6c5ce7"),
	Color("#fdcb6e"), Color("#e84393"), Color("#2d3436"), Color("#55efc4"),
]


static func make(index: int) -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg := BACKGROUNDS[index % BACKGROUNDS.size()]
	image.fill(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 7919 + 17
	# A stripe or a band across the top, so they don't all look alike.
	var band := bg.lightened(0.25) if bg.get_luminance() < 0.5 else bg.darkened(0.18)
	var band_h := rng.randi_range(10, 22)
	image.fill_rect(Rect2i(0, 0, size, band_h), band)
	var ink := Color.WHITE if bg.get_luminance() < 0.45 else Color("#2a1d17")
	# Eyes
	var eye_y := rng.randi_range(24, 30)
	for x in [20, 44]:
		_disc(image, Vector2(x, eye_y), rng.randf_range(3.0, 5.0), ink)
	# Mouth: a smile made of small dots
	var mouth_w := rng.randf_range(10.0, 16.0)
	for k in 13:
		var t := float(k) / 12.0
		var p := Vector2(32.0 + (t - 0.5) * 2.0 * mouth_w, 44.0 + sin(t * PI) * rng.randf_range(4.0, 7.0))
		_disc(image, p, 1.8, ink)
	return ImageTexture.create_from_image(image)


static func _disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() \
					and Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
