class_name GiftBox
extends Node2D
## A dropped item in a wrapped box. It falls from where the fireworks burst,
## bounces onto the floor, then bobs and glows until clicked. Clicking pops
## the lid and emits `opened`. Never saved: an unclicked box is lost at quit.

signal opened(item_id: String)

const SIZE := Vector2(58, 46)
const GRAVITY := 1400.0
const OUTLINE := Color("#2a1d17")
const WRAPS: Array[Color] = [
	Color("#e74c3c"), Color("#3498db"), Color("#2ecc71"), Color("#9b59b6"), Color("#ff7eb6"), Color("#f39c12"),
]

var item_id := ""
var super_rare := false
## Where the box comes to rest (its bottom edge), in parent coordinates.
var floor_y := 600.0
## The floor spot it drifts toward while falling, so boxes don't pile up.
var target_x := 0.0

var _velocity := Vector2.ZERO
var _landed := false
var _opening := false
var _time := 0.0
var _wrap := WRAPS[0]
var _hover := false


func _ready() -> void:
	_wrap = WRAPS[randi() % WRAPS.size()]
	_velocity = Vector2(0.0, -220.0)
	rotation = randf_range(-0.3, 0.3)


func _process(delta: float) -> void:
	_time += delta
	if not _landed:
		_velocity.y += GRAVITY * delta
		position += _velocity * delta
		position.x = lerpf(position.x, target_x, minf(1.0, delta * 4.0))
		rotation = lerpf(rotation, 0.0, delta * 3.0)
		if position.y >= floor_y:
			position.y = floor_y
			if _velocity.y > 260.0:
				_velocity = Vector2(_velocity.x * 0.5, -_velocity.y * 0.35)
			else:
				_landed = true
				rotation = 0.0
	_hover = _clickable_here() and _is_front_most()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _opening or not _landed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _clickable_here() and _is_front_most():
			get_viewport().set_input_as_handled()
			open()


func _clickable_here() -> bool:
	return _landed and not _opening and _contains(get_local_mouse_position())


## In a pile, boxes overlap: only the one drawn in front (highest z_index,
## then the one added last) answers the cursor.
func _is_front_most() -> bool:
	for other in get_parent().get_children():
		if other == self or not other is GiftBox:
			continue
		var box := other as GiftBox
		if not box._clickable_here():
			continue
		if box.z_index > z_index or (box.z_index == z_index and box.get_index() > get_index()):
			return false
	return true


## Pop the lid, then report the item and disappear.
func open() -> void:
	if _opening:
		return
	_opening = true
	var size := scale
	var tween := create_tween()
	tween.tween_property(self, "scale", size * Vector2(1.3, 0.75), 0.08)
	tween.tween_property(self, "scale", size * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: opened.emit(item_id))
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


## The box is drawn with its bottom edge at the origin.
func _contains(p: Vector2) -> bool:
	return Rect2(Vector2(-SIZE.x * 0.6, -SIZE.y - 30.0), Vector2(SIZE.x * 1.2, SIZE.y + 34.0)).has_point(p)


func _draw() -> void:
	var bob := 0.0 if not _landed or _opening else sin(_time * 3.0) * 3.0
	var base := Vector2(0, bob)
	# A soft glow that pulses, stronger on hover: "click me".
	if _landed and not _opening:
		var glow := Color(1.0, 0.9, 0.4, 0.18 + 0.1 * sin(_time * 4.0) + (0.15 if _hover else 0.0))
		draw_circle(base + Vector2(0, -SIZE.y * 0.5), SIZE.x * 0.95, glow)
	var body := Rect2(base + Vector2(-SIZE.x * 0.5, -SIZE.y), SIZE)
	var ribbon := Color("#f7d046")
	var wrap := _wrap
	if super_rare:
		wrap = Color.from_hsv(fmod(_time * 0.3, 1.0), 0.6, 1.0)
		ribbon = Color.WHITE
	draw_rect(body, wrap)
	draw_rect(Rect2(base + Vector2(-6, -SIZE.y), Vector2(12, SIZE.y)), ribbon)
	draw_rect(body, OUTLINE, false, 3.0)
	# Lid, lifted when opening.
	var lift := -14.0 if _opening else 0.0
	var lid := Rect2(base + Vector2(-SIZE.x * 0.58, -SIZE.y - 14 + lift), Vector2(SIZE.x * 1.16, 14))
	draw_rect(lid, wrap.lightened(0.15))
	draw_rect(Rect2(lid.position + Vector2(lid.size.x * 0.5 - 6, 0), Vector2(12, 14)), ribbon)
	draw_rect(lid, OUTLINE, false, 3.0)
	# Bow
	var knot := lid.position + Vector2(lid.size.x * 0.5, 0)
	for side in [-1.0, 1.0]:
		var loop := PackedVector2Array([knot, knot + Vector2(side * 16, -12), knot + Vector2(side * 18, 2)])
		draw_colored_polygon(loop, ribbon)
		draw_polyline(PackedVector2Array([loop[0], loop[1], loop[2], loop[0]]), OUTLINE, 2.5, true)
	draw_circle(knot, 5, ribbon)
	draw_arc(knot, 5, 0, TAU, 12, OUTLINE, 2.0, true)
	if super_rare and _landed:
		for i in 4:
			var a := _time * 1.5 + TAU * i / 4.0
			var p := base + Vector2(0, -SIZE.y * 0.5) + Vector2(cos(a), sin(a) * 0.6) * SIZE.x * 0.85
			draw_circle(p, 3.0, Color(1, 1, 1, 0.8))
