class_name HeadView
extends Node2D
## Draws a bobblehead entirely in code: base, body, spring neck, and a head
## made of separate layers (hair back, face, hair front, accessory).
##
## The node's origin is the neck pivot. The head swings around it.

signal popped
## A left click that didn't turn into a drag. `on_head` is true when it hit the head.
signal clicked(on_head: bool)
## A drag ended; `speed` is the cursor speed at release in pixels per second.
signal drag_released(speed: float)

const OUTLINE := Color("#2a1d17")
const HAIR_COLOR := Color("#3b2416")
const BASE := Color("#c9a54a")
const BONE := Color("#efe2c6")
const GOLD := Color("#f2c037")

## Pixels the cursor must move while held before a press becomes a drag.
const DRAG_THRESHOLD := 8.0

## Head radius at head_size 1.0. The build's head_size multiplies it.
@export var base_radius := 140.0
@export var interactive := true
@export var show_body := true

var build: HeadBuild = HeadBuild.new()
## Uploaded body texture, drawn when build.use_body_texture is on.
var body_texture: Texture2D = null
var steam_texture: Texture2D = null
var show_steam_face := false
## Hides the face layer entirely (a Steam player with no built head, before the pop).
var face_hidden := false
## Squash-and-stretch applied to the face layer only.
var face_scale := Vector2.ONE

var bobble := BobbleState.new()

var _pressing := false
var _press_on_head := false
var _press_position := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _mouse_velocity := Vector2.ZERO


func radius() -> float:
	return base_radius * build.head_size


## Height of the whole figure above the pivot (head plus the tallest hat) and below it (the base).
func extent_above_pivot() -> float:
	return radius() * 2.8


func extent_below_pivot() -> float:
	return 232.0 if show_body else radius() * 0.1


func _physics_process(delta: float) -> void:
	if bobble.dragging:
		var mouse := get_local_mouse_position()
		var instant := (mouse - _last_mouse) / maxf(delta, 0.0001)
		_mouse_velocity = _mouse_velocity.lerp(instant, 0.5)
		_last_mouse = mouse
		bobble.update_drag(mouse - _grab_offset)
	bobble.step(delta)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press()
		elif _pressing:
			_end_press()
	elif event is InputEventMouseMotion and _pressing and _press_on_head and not bobble.dragging:
		if get_local_mouse_position().distance_to(_press_position) > DRAG_THRESHOLD:
			# The head is grabbed where it was pressed: keep that point under the cursor.
			_grab_offset = _press_position - bobble.offset
			_last_mouse = get_local_mouse_position()
			_mouse_velocity = Vector2.ZERO
			bobble.begin_drag()


func _begin_press() -> void:
	_pressing = true
	_press_position = get_local_mouse_position()
	_press_on_head = _press_position.distance_to(head_center()) <= radius() * 1.15


func _end_press() -> void:
	_pressing = false
	if bobble.dragging:
		bobble.end_drag(_mouse_velocity)
		drag_released.emit(_mouse_velocity.length())
		return
	var toward := get_local_mouse_position() - head_center()
	bobble.nudge_toward(toward, 1.0)
	clicked.emit(_press_on_head)


## Head centre in this node's local space, including the current bobble.
func head_center() -> Vector2:
	return bobble.offset + Vector2(0.0, -radius() * 0.92).rotated(bobble.angle)


## Squash, swap the face for the Steam avatar, spring it out.
func pop_to_steam_face(texture: Texture2D) -> void:
	steam_texture = texture
	var tween := create_tween()
	if not face_hidden:
		tween.tween_property(self, "face_scale", Vector2(1.25, 0.7), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "face_scale", Vector2(0.15, 0.15), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		show_steam_face = true
		face_hidden = false
		face_scale = Vector2(0.15, 0.15)
		bobble.pop(1.0)
		popped.emit())
	tween.tween_property(self, "face_scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	if show_body:
		_draw_base_and_body()
	_draw_neck()

	draw_set_transform(bobble.offset, bobble.angle, Vector2.ONE)
	var r := radius()
	var c := Vector2(0.0, -r * 0.92)
	_draw_hair_back(c, r)
	if not face_hidden:
		_draw_face(c, r)
	_draw_hair_front(c, r)
	_draw_accessory(c, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_base_and_body() -> void:
	# Stand
	var base := _ellipse(Vector2(0, 205), 120, 26, 40)
	draw_colored_polygon(base, BASE)
	draw_polyline(_closed(base), OUTLINE, 4.0, true)
	draw_rect(Rect2(-120, 180, 240, 25), BASE)
	var front := _ellipse(Vector2(0, 180), 120, 26, 40)
	draw_colored_polygon(front, BASE.lightened(0.15))
	draw_polyline(_closed(front), OUTLINE, 4.0, true)
	draw_line(Vector2(-120, 180), Vector2(-120, 205), OUTLINE, 4.0)
	draw_line(Vector2(120, 180), Vector2(120, 205), OUTLINE, 4.0)
	# Body: deliberately tiny next to the head.
	var body := BodyShapes.outline(build.body_shape)
	var textured := build.use_body_texture and body_texture != null
	if textured:
		draw_colored_polygon(body, Color.WHITE, BodyShapes.uvs(body), body_texture)
	else:
		draw_colored_polygon(body, build.body_color)
		_draw_body_details(build.body_shape, build.body_color)
	draw_polyline(_closed(body), OUTLINE, 4.0, true)


## Trim per body shape, tinted from the body color. Skipped for textured bodies.
func _draw_body_details(shape: int, color: Color) -> void:
	var light := color.lightened(0.18)
	var dark := color.darkened(0.25)
	match shape:
		0:  # Suit: shirt, tie, lapels
			draw_colored_polygon(PackedVector2Array([Vector2(-16, 36), Vector2(16, 36), Vector2(0, 80)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 44), Vector2(6, 44), Vector2(9, 110), Vector2(0, 122), Vector2(-9, 110)]), Color("#c0392b"))
			draw_line(Vector2(-40, 36), Vector2(-8, 100), light, 5.0)
			draw_line(Vector2(40, 36), Vector2(8, 100), light, 5.0)
		1:  # Hoodie: hood rim, pocket, strings
			draw_arc(Vector2(0, 40), 34, 0.1, PI - 0.1, 16, dark, 8.0, true)
			draw_rect(Rect2(-36, 118, 72, 34), dark)
			draw_line(Vector2(-10, 46), Vector2(-12, 90), Color.WHITE, 3.0, true)
			draw_line(Vector2(10, 46), Vector2(12, 90), Color.WHITE, 3.0, true)
		2:  # T-shirt: collar and a star
			draw_arc(Vector2(0, 36), 16, 0.0, PI, 12, dark, 5.0, true)
			var star := PackedVector2Array()
			for i in range(10):
				var a := -PI / 2 + TAU * float(i) / 10.0
				star.append(Vector2(0, 112) + Vector2.from_angle(a) * (20.0 if i % 2 == 0 else 9.0))
			draw_colored_polygon(star, Color("#f1c40f"))
		3:  # Robe: V collar and belt
			draw_colored_polygon(PackedVector2Array([Vector2(-20, 36), Vector2(20, 36), Vector2(0, 76)]), light)
			draw_rect(Rect2(-66, 112, 132, 12), Color("#f1c40f"))
		4:  # Goat: a few tufts and a bell
			for p in [Vector2(-40, 90), Vector2(30, 80), Vector2(-10, 140), Vector2(42, 140)]:
				draw_arc(p, 9, PI, TAU, 8, dark, 3.0, true)
			draw_circle(Vector2(0, 58), 10, GOLD)
			draw_arc(Vector2(0, 58), 10, 0, TAU, 16, OUTLINE, 2.0, true)


func _draw_neck() -> void:
	# A coiled spring from the collar to the bottom of the head.
	var from := Vector2(0, 40)
	var to := bobble.offset + Vector2(0, -radius() * 0.05).rotated(bobble.angle)
	var points := PackedVector2Array()
	var coils := 7
	var axis := to - from
	var side := axis.orthogonal().normalized()
	for i in range(coils * 2 + 1):
		var t := float(i) / float(coils * 2)
		var wiggle := 0.0 if i == 0 or i == coils * 2 else (14.0 if i % 2 == 0 else -14.0)
		points.append(from + axis * t + side * wiggle)
	draw_polyline(points, Color("#9aa3ad"), 6.0, true)
	draw_polyline(points, OUTLINE, 2.0, true)


func _draw_face(c: Vector2, r: float) -> void:
	var outline := _face_polygon(build.face_shape, c, r)
	var scaled := PackedVector2Array()
	for p in outline:
		scaled.append(c + (p - c) * face_scale)

	if show_steam_face and steam_texture != null:
		# The Steam avatar, masked to the chosen face shape.
		var bounds := _bounds(scaled)
		var side := maxf(bounds.size.x, bounds.size.y)
		var origin := bounds.get_center() - Vector2(side, side) * 0.5
		var uvs := PackedVector2Array()
		for p in scaled:
			uvs.append((p - origin) / side)
		draw_colored_polygon(scaled, Color.WHITE, uvs, steam_texture)
		draw_polyline(_closed(scaled), OUTLINE, 5.0, true)
		return

	draw_colored_polygon(scaled, build.skin_color())
	draw_polyline(_closed(scaled), OUTLINE, 5.0, true)
	var s := face_scale
	_draw_eyes(c, r, s)
	_draw_mouth(c, r, s)


func _draw_eyes(c: Vector2, r: float, s: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.32, -r * 0.12) * s
		match build.eyes:
			0:  # Dots
				draw_circle(e, r * 0.075 * s.y, OUTLINE)
			1:  # Googly: pupils lag behind the bobble
				draw_circle(e, r * 0.17 * s.y, Color.WHITE)
				draw_arc(e, r * 0.17 * s.y, 0, TAU, 32, OUTLINE, 3.0, true)
				var lag := Vector2(-bobble.angle * 28.0, 6.0 - bobble.offset_velocity.y * 0.01).limit_length(r * 0.08)
				draw_circle(e + lag * s, r * 0.075 * s.y, OUTLINE)
			2:  # Happy (closed, curved)
				draw_arc(e + Vector2(0, r * 0.05) * s, r * 0.1 * s.y, PI, TAU, 16, OUTLINE, 5.0, true)
			3:  # Angry
				draw_circle(e + Vector2(0, r * 0.03) * s, r * 0.07 * s.y, OUTLINE)
				var inner := Vector2(-side * r * 0.04, -r * 0.08) * s
				var outer := Vector2(side * r * 0.16, -r * 0.17) * s
				draw_line(e + inner, e + outer, OUTLINE, 6.0, true)


func _draw_mouth(c: Vector2, r: float, s: Vector2) -> void:
	var m := c + Vector2(0, r * 0.38) * s
	match build.mouth:
		0:  # Smile
			draw_arc(m + Vector2(0, -r * 0.14) * s, r * 0.26 * s.x, PI * 0.18, PI * 0.82, 20, OUTLINE, 6.0, true)
		1:  # Grin
			var pts := PackedVector2Array()
			for i in range(17):
				var a := PI * float(i) / 16.0
				pts.append(m + Vector2(cos(a) * r * 0.3, sin(a) * r * 0.2) * s)
			draw_colored_polygon(pts, Color("#5a1e1e"))
			draw_rect(Rect2(m + Vector2(-r * 0.24, 0) * s, Vector2(r * 0.48, r * 0.06) * s), Color.WHITE)
			draw_polyline(_closed(pts), OUTLINE, 4.0, true)
		2:  # Oh
			draw_circle(m, r * 0.1 * s.y, Color("#5a1e1e"))
			draw_arc(m, r * 0.1 * s.y, 0, TAU, 24, OUTLINE, 4.0, true)
		3:  # Flat
			draw_line(m + Vector2(-r * 0.2, 0) * s, m + Vector2(r * 0.2, 0) * s, OUTLINE, 6.0, true)


func _draw_hair_back(c: Vector2, r: float) -> void:
	if build.hair == 3:  # Mop: a big mass behind the face
		draw_circle(c + Vector2(0, -r * 0.08), r * 1.06, HAIR_COLOR)
		draw_arc(c + Vector2(0, -r * 0.08), r * 1.06, 0, TAU, 48, OUTLINE, 4.0, true)


func _draw_hair_front(c: Vector2, r: float) -> void:
	match build.hair:
		1:  # Buzz
			_draw_cap(c, r * 0.99, r * 0.84, PI * 1.08, PI * 1.92)
		2:  # Spiky
			_draw_cap(c, r * 0.99, r * 0.82, PI * 1.05, PI * 1.95)
			for i in range(7):
				var a := lerpf(PI * 1.12, PI * 1.88, float(i) / 6.0)
				var dir := Vector2.from_angle(a)
				var tangent := dir.orthogonal()
				var root := c + dir * r * 0.9
				var spike := PackedVector2Array([root + tangent * r * 0.12, root + dir * r * 0.42, root - tangent * r * 0.12])
				draw_colored_polygon(spike, HAIR_COLOR)
				draw_polyline(spike, OUTLINE, 3.0, true)
		3:  # Mop fringe with a wavy edge
			var pts := PackedVector2Array()
			for i in range(25):
				var a := lerpf(PI * 1.0, PI * 2.0, float(i) / 24.0)
				pts.append(c + Vector2.from_angle(a) * r * 1.0)
			for i in range(24, -1, -1):
				var a := lerpf(PI * 1.0, PI * 2.0, float(i) / 24.0)
				var wave := 0.62 + 0.08 * sin(float(i) * 1.6)
				pts.append(c + Vector2.from_angle(a) * r * wave + Vector2(0, r * 0.12))
			draw_colored_polygon(pts, HAIR_COLOR)
			draw_polyline(_closed(pts), OUTLINE, 3.0, true)
		4:  # Mohawk
			var pts := PackedVector2Array()
			for i in range(7):
				var a := lerpf(PI * 1.4, PI * 1.6, float(i) / 6.0)
				var reach := 1.55 if i % 2 == 1 else 1.2
				pts.append(c + Vector2.from_angle(a) * r * reach)
			pts.append(c + Vector2.from_angle(PI * 1.6) * r * 0.8)
			pts.append(c + Vector2.from_angle(PI * 1.4) * r * 0.8)
			draw_colored_polygon(pts, Color("#c0392b"))
			draw_polyline(_closed(pts), OUTLINE, 3.0, true)


func _draw_accessory(c: Vector2, r: float) -> void:
	match build.accessory:
		1:  # Glasses
			for side in [-1.0, 1.0]:
				var e := c + Vector2(side * r * 0.32, -r * 0.12)
				draw_arc(e, r * 0.2, 0, TAU, 32, OUTLINE, 6.0, true)
				draw_circle(e, r * 0.2, Color(0.7, 0.85, 1.0, 0.18))
			draw_line(c + Vector2(-r * 0.12, -r * 0.14), c + Vector2(r * 0.12, -r * 0.14), OUTLINE, 6.0, true)
			draw_line(c + Vector2(-r * 0.52, -r * 0.14), c + Vector2(-r * 0.8, -r * 0.2), OUTLINE, 6.0, true)
			draw_line(c + Vector2(r * 0.52, -r * 0.14), c + Vector2(r * 0.8, -r * 0.2), OUTLINE, 6.0, true)
		2:  # Party hat
			var apex := c + Vector2(r * 0.12, -r * 1.75)
			var left := c + Vector2(-r * 0.38, -r * 0.8)
			var right := c + Vector2(r * 0.42, -r * 0.84)
			var hat := PackedVector2Array([left, apex, right])
			draw_colored_polygon(hat, Color("#8e44ad"))
			for t in [0.3, 0.55, 0.78]:
				draw_line(left.lerp(apex, t), right.lerp(apex, t), Color("#f1c40f"), 7.0, true)
			draw_polyline(_closed(hat), OUTLINE, 4.0, true)
			draw_circle(apex, r * 0.09, Color("#f1c40f"))
			draw_arc(apex, r * 0.09, 0, TAU, 20, OUTLINE, 3.0, true)
		3:  # Crown
			var y0 := c.y - r * 0.82
			var w := r * 0.55
			var crown := PackedVector2Array([
				Vector2(c.x - w, y0), Vector2(c.x - w, y0 - r * 0.42), Vector2(c.x - w * 0.5, y0 - r * 0.22),
				Vector2(c.x, y0 - r * 0.5), Vector2(c.x + w * 0.5, y0 - r * 0.22), Vector2(c.x + w, y0 - r * 0.42),
				Vector2(c.x + w, y0),
			])
			draw_colored_polygon(crown, GOLD)
			draw_polyline(_closed(crown), OUTLINE, 4.0, true)
			draw_circle(Vector2(c.x, y0 - r * 0.12), r * 0.06, Color("#e74c3c"))
			draw_circle(Vector2(c.x - w * 0.6, y0 - r * 0.1), r * 0.045, Color("#3498db"))
			draw_circle(Vector2(c.x + w * 0.6, y0 - r * 0.1), r * 0.045, Color("#2ecc71"))
		4:  # Goat horns (a Scapegoat nod)
			var thickness := r * 0.14
			var lc := c + Vector2(-r * 0.62, -r * 0.78)
			var rc := c + Vector2(r * 0.62, -r * 0.78)
			draw_arc(lc, r * 0.3, PI * 0.3, -PI * 1.0, 24, OUTLINE, thickness + 6.0, true)
			draw_arc(lc, r * 0.3, PI * 0.3, -PI * 1.0, 24, BONE, thickness, true)
			draw_arc(rc, r * 0.3, PI * 0.7, PI * 2.0, 24, OUTLINE, thickness + 6.0, true)
			draw_arc(rc, r * 0.3, PI * 0.7, PI * 2.0, 24, BONE, thickness, true)


# --------------------------------------------------------------------------
# Geometry helpers
# --------------------------------------------------------------------------

## Face outline for each shape. All shapes fit inside one standard head
## outline of radius r, so hair and accessories fit every face.
func _face_polygon(shape: int, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 64
	for i in range(n):
		var t := TAU * float(i) / float(n)
		var p := Vector2.ZERO
		match shape:
			0:  # Round
				p = Vector2(cos(t), sin(t)) * r * 0.92
			1:  # Oval
				p = Vector2(cos(t) * r * 0.76, sin(t) * r * 0.98)
			2:  # Square (superellipse)
				p = Vector2(signf(cos(t)) * pow(absf(cos(t)), 0.5), signf(sin(t)) * pow(absf(sin(t)), 0.5)) * r * 0.84
			3:  # Egg: wider at the jaw
				p = Vector2(cos(t) * r * 0.78 * (1.0 + 0.16 * sin(t)), sin(t) * r * 0.98)
		pts.append(c + p)
	return pts


func _draw_cap(c: Vector2, outer: float, inner: float, a0: float, a1: float) -> void:
	var pts := PackedVector2Array()
	var n := 24
	for i in range(n + 1):
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * outer)
	for i in range(n, -1, -1):
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * inner)
	draw_colored_polygon(pts, HAIR_COLOR)
	draw_polyline(_closed(pts), OUTLINE, 3.0, true)


func _ellipse(center: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var t := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	return pts


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


func _bounds(pts: PackedVector2Array) -> Rect2:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	return rect
