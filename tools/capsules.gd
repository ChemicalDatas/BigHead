extends Node
## Renders placeholder Steam capsule art at every size Valve asks for, into
## steam/capsules/. Title + a big bobblehead + a fireworks sky, built from the
## game's own drawing code. Capsules carry only the title, no other text.
## The library hero is artwork only; the library logo is the title alone on
## a transparent background.
##
## Run (needs a display; xvfb-run works):
##   godot --path . tools/capsules.tscn

const OUT_DIR := "res://steam/capsules/"
const FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")

## name, size, what goes in it: "full" (title + art), "art" (no text), "logo" (title only, transparent)
const CAPSULES := [
	["header_capsule", Vector2i(920, 430), "full"],
	["small_capsule", Vector2i(462, 174), "full"],
	["main_capsule", Vector2i(1232, 706), "full"],
	["vertical_capsule", Vector2i(748, 896), "full"],
	["library_capsule", Vector2i(600, 900), "full"],
	["library_header", Vector2i(920, 430), "full"],
	["library_hero", Vector2i(3840, 1240), "art"],
	["library_logo", Vector2i(1280, 720), "logo"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var viewports: Array[SubViewport] = []
	for c in CAPSULES:
		var vp := SubViewport.new()
		vp.size = c[1]
		vp.transparent_bg = c[2] == "logo"
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var art := CapsuleArt.new()
		art.size = Vector2(c[1])
		art.kind = c[2]
		vp.add_child(art)
		add_child(vp)
		viewports.append(vp)
	await get_tree().create_timer(1.0).timeout
	for i in CAPSULES.size():
		var path: String = OUT_DIR + "%s.png" % CAPSULES[i][0]
		viewports[i].get_texture().get_image().save_png(path)
		print("[capsules] %s %s" % [path, CAPSULES[i][1]])
	get_tree().quit()


class CapsuleArt:
	extends Node2D

	var size := Vector2(920, 430)
	var kind := "full"
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 42
		if kind == "logo":
			queue_redraw()
			return
		var tall := size.y > size.x
		var small := size.y < 200.0
		# The star: a big-headed bobblehead with a wizard hat.
		var head := _bobblehead(0)
		if kind == "art":
			# The hero: the star in the middle, friends either side.
			_place(head, Vector2(size.x * 0.5, size.y * 0.97), size.y * 0.9)
			for k in 4:
				var side := -1.0 if k % 2 == 0 else 1.0
				var friend := _bobblehead(k + 1)
				_place(friend, Vector2(size.x * 0.5 + side * size.x * (0.17 + 0.13 * (k / 2)), size.y * 0.97), size.y * (0.55 - 0.08 * (k / 2)))
		elif tall:
			_place(head, Vector2(size.x * 0.5, size.y * 0.98), size.y * 0.58)
		elif small:
			_place(head, Vector2(size.x * 0.84, size.y * 1.02), size.y * 1.05)
		else:
			_place(head, Vector2(size.x * 0.74, size.y * 0.98), size.y * 0.92)
		queue_redraw()

	## A bobblehead of a given look, scaled so the whole figure is `height` tall.
	func _bobblehead(look: int) -> HeadView:
		var h := HeadView.new()
		h.interactive = false
		h.look_at_cursor = false
		var b := h.build
		match look:
			0:
				b.face_shape = 1; b.hair = 3; b.hair_color = Color("#b5532d"); b.eyes = 1; b.mouth = 1
				b.accessory = 5; b.accessory_variant = 0; b.body_shape = 3; b.body_variant = 1
				b.head_size = 1.2
			1:
				b.face_shape = 0; b.hair = 2; b.eyes = 1; b.mouth = 1; b.accessory = 2; b.accessory_variant = 2
				b.body_shape = 1; b.body_variant = 1; b.skin = HeadBuild.SKIN_PRESETS[3]
			2:
				b.face_shape = 4; b.hair = 5; b.eyes = 1; b.mouth = 0; b.accessory = 6; b.body_shape = 5
			3:
				b.face_shape = 2; b.hair = 4; b.eyes = 3; b.mouth = 2; b.accessory = 1; b.body_shape = 0; b.body_variant = 2
				b.skin = HeadBuild.SKIN_PRESETS[0]
			4:
				b.face_shape = 9; b.eyes = 1; b.accessory = 4; b.accessory_variant = 3; b.body_shape = 4; b.body_variant = 1
		add_child(h)
		return h

	func _place(h: HeadView, stand_bottom: Vector2, height: float) -> void:
		var full := h.extent_above_pivot() + 231.0
		var s := height / full
		h.scale = Vector2(s, s)
		h.position = stand_bottom - Vector2(0, 231.0 * s)

	func _draw() -> void:
		if kind != "logo":
			_sky()
		if kind == "art":
			return
		var tall := size.y > size.x
		var small := size.y < 200.0
		var font_size := int(size.y * 0.3)
		var box := Rect2(Vector2(size.x * 0.05, size.y * 0.08), Vector2(size.x * 0.6, size.y * 0.8))
		if kind == "logo":
			font_size = int(size.y * 0.42)
			box = Rect2(Vector2.ZERO, size)
		elif tall:
			font_size = int(size.x * 0.24)
			box = Rect2(Vector2(0, size.y * 0.03), Vector2(size.x, size.y * 0.32))
		elif small:
			font_size = int(size.y * 0.42)
			box = Rect2(Vector2(size.x * 0.03, 0), Vector2(size.x * 0.68, size.y))
		_title(box, font_size, tall or kind == "logo")

	## "BIG / HEAD" stacked, chunky, outlined, a little tilted.
	func _title(box: Rect2, font_size: int, centered: bool) -> void:
		var lines := ["BIG", "HEAD"]
		var line_h := font_size * 0.92
		var top := box.get_center().y - line_h * lines.size() * 0.5 + font_size * 0.78
		for i in lines.size():
			var text: String = lines[i]
			var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var x := box.get_center().x - width * 0.5 if centered else box.position.x + (0.0 if i == 0 else font_size * 0.35)
			var pos := Vector2(x, top + i * line_h)
			var outline := maxi(4, font_size / 7)
			draw_string_outline(FONT, pos + Vector2(0, font_size * 0.06), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color("#2a1d17"))
			draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color("#2a1d17"))
			draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#ffd84a") if i == 0 else Color("#ff5e5e"))

	## Night sky gradient with stars and a few firework bursts.
	func _sky() -> void:
		var top := Color("#2a1b55")
		var bottom := Color("#5a2a6e")
		var steps := 64
		for i in steps:
			var y0 := size.y * i / steps
			draw_rect(Rect2(0, y0, size.x, size.y / steps + 1.0), top.lerp(bottom, float(i) / steps))
		for i in int(size.x * size.y / 4000.0):
			draw_circle(Vector2(_rng.randf() * size.x, _rng.randf() * size.y), _rng.randf_range(0.8, 2.2) * size.y / 600.0, Color(1, 1, 1, _rng.randf_range(0.3, 0.9)))
		var colors := [Color("#ff5e5e"), Color("#ffd166"), Color("#06d6a0"), Color("#4cc9f0"), Color("#c77dff"), Color("#ff7eb6")]
		for i in 7:
			var c := Vector2(_rng.randf() * size.x, _rng.randf_range(0.08, 0.5) * size.y)
			var r := _rng.randf_range(0.08, 0.16) * size.y
			var col: Color = colors[i % colors.size()]
			for k in 16:
				var d := Vector2.from_angle(TAU * k / 16.0)
				draw_line(c + d * r * 0.3, c + d * r, col, maxf(2.0, size.y / 220.0), true)
				draw_circle(c + d * r, maxf(2.0, size.y / 240.0), col)
