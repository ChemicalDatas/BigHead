extends Node2D
## Renders the Steam achievement icons (256 x 256 PNG, achieved and
## unachieved) from the game's own drawing code, into steam/achievements/.
## The unachieved versions are made grayscale by tools/finish_icons.py.
##
## Run (needs a display; xvfb-run works):
##   godot --path . --resolution 1280x960 tools/achievement_icons.tscn
##   python3 tools/finish_icons.py

const SIZE := 256.0
const OUT_DIR := "res://steam/achievements/"
const OUTLINE := Color("#2a1d17")

## API name, background top and bottom colors.
const ICONS := [
	["BIG_HEAD", "#c0392b", "#7b1e2b"],
	["WHIPLASH", "#2e86de", "#1b3a6b"],
	["PERPETUAL_MOTION", "#16a085", "#0b4f42"],
	["BOBBLE_BOOP", "#e84393", "#7a1f52"],
	["OOH_AAH", "#2d1b4e", "#120a24"],
	["ITS_A_PARTY", "#8e44ad", "#3d1a52"],
	["GRAND_FINALE", "#d4a017", "#6b4a0b"],
	["LEVEL_HEADED", "#27ae60", "#145a32"],
	["SWELLED_HEAD", "#e67e22", "#7a3e0b"],
	["POP_GOES_THE_HEAD", "#0984e3", "#063a63"],
]

var _heads := {}


func _ready() -> void:
	for i in ICONS.size():
		var origin := _origin(i)
		var id: String = ICONS[i][0]
		_heads[id] = _make_head(id, origin)
	queue_redraw()
	# Pop Goes the Head is caught mid-pop.
	await get_tree().create_timer(0.66).timeout
	var balloon: HeadView = _heads["POP_GOES_THE_HEAD"]
	balloon.pop_balloon(balloon.head_center() + Vector2(0.6, -0.8) * balloon.radius(), "icon")
	# Wait for the tear to start, then catch it about halfway across.
	while balloon._balloon != HeadView.Balloon.POPPING:
		await get_tree().process_frame
	while balloon._balloon_t < HeadView.POP_SECONDS * 0.3:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i in ICONS.size():
		var o := _origin(i)
		var icon := image.get_region(Rect2i(int(o.x), int(o.y), int(SIZE), int(SIZE)))
		icon.save_png(OUT_DIR + "%s_ACHIEVED.png" % ICONS[i][0])
	print("[icons] Wrote %d achieved icons to %s" % [ICONS.size(), OUT_DIR])
	get_tree().quit()


## Icons are spread out so a figure poking past its own square never lands
## in a neighbour's (each square is cut out on its own).
func _origin(i: int) -> Vector2:
	return Vector2((i % 4) * 320.0 + 16.0, (i / 4) * 320.0 + 16.0)


## A bobblehead posed for each icon.
func _make_head(id: String, origin: Vector2) -> HeadView:
	var h := HeadView.new()
	h.interactive = false
	h.look_at_cursor = false
	h.base_radius = 125.0
	var b := h.build
	b.face_shape = 0
	b.hair = 1
	b.eyes = 1
	b.mouth = 1
	b.skin = HeadBuild.SKIN_PRESETS[1]
	b.body_shape = 0
	var fit := 0.42
	var pivot := Vector2(128, 170)
	match id:
		"BIG_HEAD":
			b.head_size = 1.5; fit = 0.36; pivot = Vector2(128, 178)
		"WHIPLASH":
			b.hair = 2; b.eyes = 3; b.mouth = 2
			h.bobble.angle = -0.55; h.bobble.offset = Vector2(-40, 10)
		"PERPETUAL_MOTION":
			b.eyes = 1; b.mouth = 1; h.bobble.angle = 0.35
		"BOBBLE_BOOP":
			b.hair = 3; b.mouth = 2; h.bobble.angle = 0.25; pivot = Vector2(118, 172)
		"OOH_AAH":
			b.mouth = 2; b.eyes = 1; fit = 0.34; pivot = Vector2(128, 200)
		"ITS_A_PARTY":
			b.accessory = 2; b.accessory_variant = 2; b.mouth = 1; fit = 0.36; pivot = Vector2(128, 190)
		"GRAND_FINALE":
			b.accessory = 3; b.accessory_variant = 0; b.mouth = 1; fit = 0.36; pivot = Vector2(128, 192)
		"LEVEL_HEADED":
			b.eyes = 2; b.mouth = 3; b.face_shape = 2
		"SWELLED_HEAD":
			b.head_size = 1.5; fit = 0.62; pivot = Vector2(128, 250); b.mouth = 2
		"POP_GOES_THE_HEAD":
			b.rig = HeadView.BALLOON_RIG; b.mouth = 2; fit = 0.36; pivot = Vector2(128, 182)
	h.scale = Vector2(fit, fit)
	h.position = origin + pivot
	add_child(h)
	return h


func _draw() -> void:
	for i in ICONS.size():
		var o := _origin(i)
		_background(o, Color(ICONS[i][1]), Color(ICONS[i][2]))
		match ICONS[i][0]:
			"WHIPLASH": _whiplash(o)
			"PERPETUAL_MOTION": _motion(o)
			"OOH_AAH": _bursts(o, [Vector2(70, 70), Vector2(186, 60), Vector2(128, 40)], 34.0)
			"ITS_A_PARTY": _bursts(o, [Vector2(40, 50), Vector2(90, 30), Vector2(166, 30), Vector2(216, 50), Vector2(128, 18)], 20.0)
			"GRAND_FINALE": _bursts(o, [Vector2(36, 40), Vector2(80, 22), Vector2(128, 14), Vector2(176, 22), Vector2(220, 40), Vector2(30, 110), Vector2(226, 110)], 22.0)
			"LEVEL_HEADED": _level(o)
			"BOBBLE_BOOP": _cursor(o + Vector2(196, 128))


## Rounded square with a top-to-bottom gradient.
func _background(o: Vector2, top: Color, bottom: Color) -> void:
	for y in int(SIZE):
		draw_line(o + Vector2(0, y), o + Vector2(SIZE, y), top.lerp(bottom, y / SIZE))
	draw_rect(Rect2(o + Vector2(4, 4), Vector2(SIZE - 8, SIZE - 8)), Color(1, 1, 1, 0.25), false, 4.0)


func _whiplash(o: Vector2) -> void:
	for k in 4:
		var y := 70.0 + k * 22.0
		draw_line(o + Vector2(150, y), o + Vector2(230, y - 6), Color(1, 1, 1, 0.7), 6.0, true)
	for k in 3:
		var p := o + Vector2(70 + k * 38, 44 - (k % 2) * 10)
		_star(p, 14.0, Color("#ffd84a"))


func _motion(o: Vector2) -> void:
	var c := o + Vector2(128, 118)
	draw_arc(c, 104, PI * 1.1, PI * 1.6, 24, Color(1, 1, 1, 0.85), 8.0, true)
	draw_arc(c, 104, PI * 0.1, PI * 0.6, 24, Color(1, 1, 1, 0.85), 8.0, true)
	_arrowhead(c + Vector2.from_angle(PI * 1.6) * 104, PI * 1.6 + PI / 2)
	_arrowhead(c + Vector2.from_angle(PI * 0.6) * 104, PI * 0.6 + PI / 2)


func _arrowhead(tip: Vector2, heading: float) -> void:
	var d := Vector2.from_angle(heading)
	draw_colored_polygon(PackedVector2Array([tip + d * 14, tip - d * 6 + d.orthogonal() * 12, tip - d * 6 - d.orthogonal() * 12]), Color(1, 1, 1, 0.85))


## A big mouse pointer, mid-boop, with a little impact burst.
func _cursor(tip: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 46), Vector2(11, 35), Vector2(20, 55), Vector2(29, 51), Vector2(20, 32), Vector2(35, 32)])
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(tip + p)
	draw_colored_polygon(moved, Color.WHITE)
	moved.append(moved[0])
	draw_polyline(moved, OUTLINE, 3.5, true)
	for k in 5:
		var d := Vector2.from_angle(PI * (0.95 + 0.15 * k))
		draw_line(tip + d * 10, tip + d * 24, Color("#ffd84a"), 4.0, true)


func _level(o: Vector2) -> void:
	var r := Rect2(o + Vector2(48, 214), Vector2(160, 28))
	draw_rect(r, Color("#f1c40f"))
	draw_rect(r, OUTLINE, false, 3.0)
	var vial := Rect2(o + Vector2(98, 220), Vector2(60, 16))
	draw_rect(vial, Color("#b8f0c8"))
	draw_circle(vial.get_center(), 6.0, Color.WHITE)
	draw_line(vial.position + Vector2(18, 0), vial.position + Vector2(18, 16), OUTLINE, 2.0)
	draw_line(vial.position + Vector2(42, 0), vial.position + Vector2(42, 16), OUTLINE, 2.0)
	draw_rect(vial, OUTLINE, false, 2.0)


func _bursts(o: Vector2, centers: Array, radius: float) -> void:
	var colors := [Color("#ff5e5e"), Color("#ffd166"), Color("#06d6a0"), Color("#4cc9f0"), Color("#c77dff"), Color("#ff7eb6"), Color.WHITE]
	for i in centers.size():
		var c: Vector2 = o + centers[i]
		var col: Color = colors[i % colors.size()]
		for k in 14:
			var d := Vector2.from_angle(TAU * k / 14.0)
			draw_line(c + d * radius * 0.25, c + d * radius, col, 3.0, true)
			draw_circle(c + d * radius, 2.6, col)


func _star(p: Vector2, size: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(p + Vector2.from_angle(-PI / 2.0 + TAU * k / 10.0) * (size if k % 2 == 0 else size * 0.45))
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE, 2.5, true)
