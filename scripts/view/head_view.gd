class_name HeadView
extends Node2D
## Draws a bobblehead entirely in code: base, body, spring neck, and a head
## made of separate layers (hair back, face, hair front, accessory).
##
## The node's origin is the neck pivot. The head swings around it.

signal popped
## A face swap finished swapping (the new face is now showing).
signal face_swapped(to_steam: bool)
## A left click that didn't turn into a drag. `on_head` is true when it hit the head.
signal clicked(on_head: bool)
## A drag ended; `speed` is the cursor speed at release in pixels per second.
signal drag_released(speed: float)
## The balloon head popped. `cause` is "whiplash", "ground" or "firework".
signal balloon_popped(cause: String)

## Balloon pop, in order: one frame to snapshot the head, the skin tearing
## away from the hit point, a limp scrap on the string, then reinflating.
enum Balloon { INFLATED, POP_PENDING, POPPING, DEFLATED, INFLATING }
const POP_SECONDS := 0.26
const DEFLATED_SECONDS := 3.0
const INFLATE_SECONDS := 0.7
## The balloon pops when its lowest point reaches this height (the stand's top).
const FLOOR_Y := 178.0
const STRING_COLOR := Color("#f4f0e6")

const OUTLINE := Color("#2a1d17")
const BASE := Color("#c9a54a")
const BONE := Color("#efe2c6")
const GOLD := Color("#f2c037")
## The unicorn set's rainbow (mane, tail), outside in.
const RAINBOW: Array[Color] = [
	Color("#e74c3c"), Color("#f39c12"), Color("#f1c40f"),
	Color("#2ecc71"), Color("#3498db"), Color("#9b59b6"),
]

## Indices into Catalog.BASES for the unicorn set's head parts.
const RAINBOW_HAIR := 5
const UNICORN_HORN := 6   ## build.accessory (0 is "none")
## build.rig for the Balloon (0 is the spring-neck Bobble).
const BALLOON_RIG := 1
const MARIONETTE_RIG := 2
const WOOD := Color("#a8743f")

## Pixels the cursor must move while held before a press becomes a drag.
const DRAG_THRESHOLD := 8.0

## How quickly the eyes catch up with the cursor (higher = snappier).
const GAZE_SMOOTHING := 8.0
## Largest head tilt toward the cursor, for faces whose eyes can't move (radians).
const MAX_LOOK_TILT := 0.18

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
## Draws only the head, unmoved, at the origin. Used for the balloon pop snapshot.
var head_only := false

var _rig_applied := -1
var _rope: Rope = null
var _balloon := Balloon.INFLATED
var _balloon_t := 0.0
var _balloon_frames := 0
## Head space, from the head's centre toward where it was hit.
var _pop_dir := Vector2.DOWN
var _snapshot: SubViewport = null
var _scrap := PackedVector2Array()
## Marionette: the puppet physics, and how the body is moved and tilted.
var _puppet: MarionetteState = null
var _puppet_key := ""
var _body_xform := Transform2D.IDENTITY
var _bar_grab := Vector2.ZERO
## True while the mouse holds the control bar.
var _bar_held := false
## Swing of each arm (around the shoulder) or leg (around its top), radians.
var _limb_swing: Array[float] = []
## Head scale while reinflating (1 when inflated).
var _inflate := 1.0
## Seconds after reinflating during which touching the floor doesn't pop it
## (it reinflates wherever the scrap landed, often on the floor).
var _ground_grace := 0.0

## Eyes (or, for faces whose eyes can't move, the head) follow the cursor.
var look_at_cursor := true
## Follow the cursor anywhere on screen, not just over this window (the
## desktop buddy). Works on Windows and X11; Wayland only reports the cursor
## while it's over the window.
var global_cursor := false
## Customize's "?" entry: the category whose part is drawn as a question mark
## (the build underneath doesn't change). "" for none.
var mystery := ""
## False for other players' heads in a shared room: their bobble comes over
## the network instead of from local physics.
var simulate := true
const MYSTERY_GREY := Color("#9a93a6")
## Where the eyes look: a direction with length 0..1 (1 = as far as they go), smoothed.
var _gaze := Vector2.ZERO
## Extra head tilt toward the cursor; drawing only, so it never disturbs the physics.
var _look_tilt := 0.0

## Dizzy stars circling the head: seconds left and total, 0 when off.
var _stars_left := 0.0
var _stars_total := 0.0
var _stars_spin := 0.0

var _pressing := false
var _press_on_head := false
var _press_position := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _mouse_velocity := Vector2.ZERO


## Extra head size from the "bighead" cheat code (never saved).
var size_boost := 1.0


func radius() -> float:
	return base_radius * build.head_size * size_boost


## Height of the whole figure above the pivot (head plus the tallest hat) and below it (the base).
func extent_above_pivot() -> float:
	# The balloon floats about half a head higher than the bobble.
	if is_marionette():
		return radius() * 2.8 + 70.0  # the control bar above the hats
	return radius() * (3.5 if is_balloon() else 2.8)


func extent_below_pivot() -> float:
	return 232.0 if show_body else radius() * 0.1


func _init() -> void:
	# Variant patterns are small textures tiled across each shape.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func is_balloon() -> bool:
	return build.rig == BALLOON_RIG and not head_only


func is_marionette() -> bool:
	return build.rig == MARIONETTE_RIG and not head_only and show_body


## Still, for Level-Headed (and moving, for Perpetual Motion): on the
## marionette the puppet has to be still too.
func is_resting() -> bool:
	if _puppet != null and not _puppet.is_resting():
		return false
	return bobble.is_resting()


func is_dragging() -> bool:
	return bobble.dragging or (_puppet != null and _puppet.dragging)


## A point in this node's space, in the body's own space (they differ only
## while the marionette moves the body).
func _to_body_space(p: Vector2) -> Vector2:
	return _body_xform.affine_inverse() * p


## True when a point (local space) is on an inflated balloon head.
func hits_balloon(point: Vector2) -> bool:
	return is_balloon() and _balloon == Balloon.INFLATED and point.distance_to(head_center()) <= radius() * 0.95


## Swaps the physics when the build's rig changes.
func _apply_rig() -> void:
	_rig_applied = build.rig
	_balloon = Balloon.INFLATED
	_inflate = 1.0
	_free_snapshot()
	_puppet = null
	_puppet_key = ""
	_body_xform = Transform2D.IDENTITY
	if is_marionette():
		bobble = BobbleState.new()
		_rope = null
		_configure_marionette()
	elif is_balloon():
		var balloon := BalloonState.new()
		bobble = balloon
		_configure_balloon()
		balloon.place(balloon.rest_point())
		_rope = Rope.new(balloon.anchor, balloon.offset, balloon.string_length)
		_rope.floor_y = FLOOR_Y
	else:
		bobble = BobbleState.new()
		_rope = null


## The string is tied to the right hand, or to an animal's back. It's long
## enough to reach the floor, and the head floats half a head above the pivot.
func _configure_balloon() -> void:
	var balloon := bobble as BalloonState
	var r := radius()
	var anchor := Vector2(0, 40)
	if show_body:
		var hands := BodyShapes.hands(build.body_shape)
		anchor = hands[0] if not hands.is_empty() else Vector2(30, 56)
	balloon.anchor = anchor
	balloon.rest_height = -r * 0.5
	balloon.string_length = maxf((anchor.y - balloon.rest_height) / 0.94, FLOOR_Y - anchor.y + r * 0.2)
	_rope_set_length(balloon.string_length)


func _rope_set_length(length: float) -> void:
	if _rope != null:
		_rope.set_length(length)


## Strings to the hands (people) or the four leg tops (animals), from a bar
## that rests above the tallest hat. Rebuilt when the body or head size changes.
func _configure_marionette() -> void:
	var r := radius()
	var shape := build.body_shape
	var key := "%d/%.1f" % [shape, r]
	if key == _puppet_key:
		return
	_puppet_key = key
	_puppet = MarionetteState.new()
	var attach: Array[Vector2] = []
	var bar_points: Array[Vector2] = []
	if BodyShapes.is_animal(shape):
		for leg in BodyShapes.legs(shape):
			var top := Vector2(leg.get_center().x, leg.position.y + 4.0)
			attach.append(top)
			bar_points.append(Vector2(top.x * 2.4, 0))
	else:
		for hand in BodyShapes.hands(shape):
			attach.append(hand)
			bar_points.append(Vector2(signf(hand.x) * maxf(r * 1.15, absf(hand.x)), 0))
	_puppet.configure(attach, bar_points, Vector2(0, -(r * 2.8 + 40.0)))
	# The head hangs from the middle of the bar, tied to the back of the body.
	_puppet.configure_head(Vector2(0, -r * 0.92), r * 0.9, Vector2(0, 40))
	_limb_swing.clear()
	for i in attach.size():
		_limb_swing.append(0.0)


func _marionette_physics(delta: float) -> void:
	_configure_marionette()
	if _bar_held:
		_puppet.drag_target = get_local_mouse_position() - _bar_grab - _puppet.bar_rest
	if bobble.dragging:
		# Dragging the head itself: it follows the cursor, strings permitting.
		var mouse := get_local_mouse_position()
		var instant := (mouse - _last_mouse) / maxf(delta, 0.0001)
		_mouse_velocity = _mouse_velocity.lerp(instant, 0.5)
		_last_mouse = mouse
		_puppet.head_dragging = true
		_puppet.head_drag_target = mouse - _grab_offset
	_puppet.step(delta)
	_body_xform = Transform2D(_puppet.angle, _puppet.body)
	_update_limb_swing(delta)


## Arms swing toward a taut string; legs hang straight down while lifted.
func _update_limb_swing(delta: float) -> void:
	var shape := build.body_shape
	var blend := 1.0 - exp(-10.0 * delta)
	var lifted := clampf(-_puppet.body.y / 20.0, 0.0, 1.0)
	var arms := BodyShapes.arms(shape)
	for i in _limb_swing.size():
		var target := 0.0
		if BodyShapes.is_animal(shape):
			target = (-_puppet.angle + clampf(-_puppet.bar_velocity.x * 0.0008, -0.4, 0.4)) * lifted
		elif i < arms.size():
			var shoulder := (arms[i][0] + arms[i][1]) * 0.5
			var hand := _puppet.attach[i]
			var to_bar := _to_body_space(_puppet.bar_point(i)) - shoulder
			var rest_dir := hand - shoulder
			target = clampf(rest_dir.angle_to(to_bar), -1.3, 1.3) * _puppet.tension(i)
		_limb_swing[i] = lerpf(_limb_swing[i], target, blend)


func _physics_process(delta: float) -> void:
	if head_only or not simulate:
		return
	if build.rig != _rig_applied:
		_apply_rig()
	if is_balloon():
		_balloon_physics(delta)
		return
	if is_marionette():
		_marionette_physics(delta)
		return
	if bobble.dragging:
		var mouse := get_local_mouse_position()
		var instant := (mouse - _last_mouse) / maxf(delta, 0.0001)
		_mouse_velocity = _mouse_velocity.lerp(instant, 0.5)
		_last_mouse = mouse
		bobble.update_drag(mouse - _grab_offset)
	bobble.step(delta)


func _balloon_physics(delta: float) -> void:
	_configure_balloon()
	var balloon := bobble as BalloonState
	var has_head := _balloon == Balloon.INFLATED or _balloon == Balloon.INFLATING or _balloon == Balloon.POP_PENDING
	if has_head:
		if bobble.dragging:
			var mouse := get_local_mouse_position()
			var instant := (mouse - _last_mouse) / maxf(delta, 0.0001)
			_mouse_velocity = _mouse_velocity.lerp(instant, 0.5)
			_last_mouse = mouse
			bobble.update_drag(mouse - _grab_offset)
		bobble.step(delta)
	_rope.end_pinned = has_head or _balloon == Balloon.POPPING
	_rope.step(delta, balloon.anchor, bobble.offset)
	_ground_grace = maxf(_ground_grace - delta, 0.0)
	if _balloon == Balloon.INFLATED and _ground_grace <= 0.0 and head_center().y + radius() * 0.95 >= FLOOR_Y:
		pop_balloon(head_center() + Vector2(0, radius() * 0.95), "ground")


## Pops the balloon head at `at` (local space). Does nothing unless inflated.
func pop_balloon(at: Vector2, cause: String) -> void:
	if not is_balloon() or _balloon != Balloon.INFLATED:
		return
	var dir := (at - head_center()).rotated(-(bobble.angle + _look_tilt))
	_pop_dir = dir.normalized() if dir.length() > 0.001 else Vector2.DOWN
	bobble.dragging = false
	_pressing = false
	_stars_left = 0.0
	_take_snapshot()
	_balloon = Balloon.POP_PENDING
	_balloon_t = 0.0
	_balloon_frames = 0
	_spawn_shreds(at)
	balloon_popped.emit(cause)


func _advance_balloon(delta: float) -> void:
	_balloon_t += delta
	match _balloon:
		Balloon.POP_PENDING:
			# The snapshot renders on the next frame; draw the head until then.
			_balloon_frames += 1
			if _balloon_frames >= 2:
				_balloon = Balloon.POPPING
				_balloon_t = 0.0
		Balloon.POPPING:
			if _balloon_t >= POP_SECONDS:
				_balloon = Balloon.DEFLATED
				_balloon_t = 0.0
				_free_snapshot()
				_make_scrap()
		Balloon.DEFLATED:
			if _balloon_t >= DEFLATED_SECONDS:
				_balloon = Balloon.INFLATING
				_balloon_t = 0.0
				(bobble as BalloonState).place(_rope.end())
		Balloon.INFLATING:
			var t := clampf(_balloon_t / INFLATE_SECONDS, 0.0, 1.0)
			_inflate = lerpf(0.15, 1.0, Tween.interpolate_value(0.0, 1.0, t, 1.0, Tween.TRANS_ELASTIC, Tween.EASE_OUT))
			if t >= 1.0:
				_inflate = 1.0
				_balloon = Balloon.INFLATED
				_ground_grace = 1.0


## Renders the head as it is right now into a texture, for the pop.
func _take_snapshot() -> void:
	_free_snapshot()
	var r := radius()
	var k := clampf(global_scale.x, 0.25, 2.0)
	var side := int(ceil(4.0 * r * k))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(side, side)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var copy := HeadView.new()
	copy.head_only = true
	copy.interactive = false
	copy.look_at_cursor = false
	copy.base_radius = base_radius
	copy.build = build
	copy.steam_texture = steam_texture
	copy.show_steam_face = show_steam_face
	copy.face_hidden = face_hidden
	copy.face_scale = face_scale
	copy._gaze = _gaze
	copy.scale = Vector2(k, k)
	copy.position = Vector2(side, side) * 0.5 + Vector2(0, r * 0.92) * k
	viewport.add_child(copy)
	add_child(viewport)
	_snapshot = viewport


func _free_snapshot() -> void:
	if _snapshot != null:
		_snapshot.queue_free()
		_snapshot = null


## Bits of rubber flying off the hit point.
func _spawn_shreds(at: Vector2) -> void:
	var shreds := CPUParticles2D.new()
	shreds.position = at
	shreds.one_shot = true
	shreds.explosiveness = 1.0
	shreds.amount = 16
	shreds.lifetime = 0.7
	shreds.spread = 180.0
	shreds.initial_velocity_min = 220.0
	shreds.initial_velocity_max = 520.0
	shreds.gravity = Vector2(0, 900)
	shreds.angular_velocity_min = -720.0
	shreds.angular_velocity_max = 720.0
	shreds.scale_amount_min = 4.0
	shreds.scale_amount_max = 8.0
	shreds.color = _face_color()
	add_child(shreds)
	shreds.emitting = true
	get_tree().create_timer(1.2).timeout.connect(shreds.queue_free)


## A small crumpled scrap of skin, hanging below the knot.
func _make_scrap() -> void:
	var r := radius()
	_scrap = PackedVector2Array()
	var n := 11
	for i in n:
		var a := TAU * float(i) / n
		var wobble := 0.55 + 0.45 * absf(sin(float(i) * 2.3 + 0.7))
		_scrap.append(Vector2(cos(a) * r * 0.17, r * 0.2 + sin(a) * r * 0.21) * wobble)


func _process(delta: float) -> void:
	if is_balloon():
		_advance_balloon(delta)
	_update_gaze(delta)
	if _stars_left > 0.0:
		_stars_left = maxf(_stars_left - delta, 0.0)
		_stars_spin += delta * 3.2
	queue_redraw()


## Cartoon "seeing stars": a ring of stars orbits the head for `seconds`.
func show_dizzy_stars(seconds: float) -> void:
	_stars_total = seconds
	_stars_left = seconds
	_stars_spin = 0.0


## True when the current face has no eyes that can move: closed "Happy" eyes,
## or the Steam avatar photo. Those faces tilt the head toward the cursor instead.
func _looks_with_head() -> bool:
	return (show_steam_face and steam_texture != null) or build.eyes == 2


## Eases the gaze toward the cursor and caps how far it goes. The direction comes
## from the cursor; the distance only sets how strongly they look (it saturates),
## so a far-away cursor never pushes the eyes past their limit.
func _update_gaze(delta: float) -> void:
	var target := Vector2.ZERO
	if look_at_cursor:
		var r := radius()
		var c := Vector2(0.0, -r * 0.92)
		var in_head: Vector2
		if _puppet != null:
			in_head = (_cursor_local() - _puppet.head).rotated(-_puppet.head_angle - _look_tilt)
		else:
			in_head = (_to_body_space(_cursor_local()) - bobble.offset).rotated(-bobble.angle - _look_tilt) - c
		var dist := in_head.length()
		if dist > 0.001:
			# Saturates quickly: a cursor one head-radius away already gets ~70% of the range.
			target = in_head / dist * (dist / (dist + r * 0.4))
	var blend := 1.0 - exp(-GAZE_SMOOTHING * delta)
	_gaze = _gaze.lerp(target, blend)
	var tilt_target := clampf(_gaze.x, -1.0, 1.0) * MAX_LOOK_TILT if _looks_with_head() else 0.0
	_look_tilt = lerpf(_look_tilt, tilt_target, blend)


## The cursor in this node's space; with global_cursor, even outside the window.
func _cursor_local() -> Vector2:
	if global_cursor:
		var on_screen := Vector2(DisplayServer.mouse_get_position() - get_window().position)
		return get_global_transform_with_canvas().affine_inverse() * on_screen
	return get_local_mouse_position()


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
			if _puppet != null:
				_grab_offset = _press_position - _puppet.head
				_last_mouse = get_local_mouse_position()
			else:
				_grab_offset = _to_body_space(_press_position) - bobble.offset
				_last_mouse = _to_body_space(get_local_mouse_position())
			_mouse_velocity = Vector2.ZERO
			bobble.begin_drag()


func _begin_press() -> void:
	_pressing = true
	_press_position = get_local_mouse_position()
	if is_marionette() and _on_bar(_press_position):
		# The control bar: dragging it works the puppet.
		_press_on_head = false
		_bar_grab = _press_position - _puppet.bar_center()
		_bar_held = true
		_puppet.begin_drag()
		return
	_press_on_head = _press_position.distance_to(head_center()) <= radius() * 1.15
	if is_balloon() and _balloon != Balloon.INFLATED:
		_press_on_head = false  # nothing to grab while it's popped


func _end_press() -> void:
	_pressing = false
	if _bar_held:
		_bar_held = false
		_puppet.end_drag()
		return
	if bobble.dragging:
		bobble.end_drag(_mouse_velocity)
		if _puppet != null:
			_puppet.release_head(_mouse_velocity)
		var speed := _mouse_velocity.length()
		drag_released.emit(speed)
		if is_balloon() and speed >= AchievementRules.WHIPLASH_SPEED:
			# Flung hard enough to snap: pops on the side it's yanked away from.
			pop_balloon(head_center() - _mouse_velocity.normalized() * radius() * 0.9, "whiplash")
		return
	if is_balloon() and _balloon != Balloon.INFLATED:
		return
	var toward := get_local_mouse_position() - head_center()
	if _puppet != null:
		_puppet.nudge_head(toward, 1.0)
	else:
		bobble.nudge_toward(toward, 1.0)
	clicked.emit(_press_on_head)


## Head centre in this node's local space, including the current bobble (and,
## on the marionette, where the body has been moved).
func head_center() -> Vector2:
	if _puppet != null:
		return _puppet.head
	return _body_xform * (bobble.offset + Vector2(0.0, -radius() * 0.92).rotated(bobble.angle))


## The control bar's half-width: its outermost string plus a handle's worth.
func _bar_half_width() -> float:
	var half := 30.0
	for p in _puppet.bar_points:
		half = maxf(half, absf(p.x) + 16.0)
	return half


func _on_bar(p: Vector2) -> bool:
	var local := p - _puppet.bar_center()
	return absf(local.x) <= _bar_half_width() + 10.0 and absf(local.y) <= 26.0


## The reveal: squash, swap the face for the Steam avatar, spring it out with a
## kick to the whole head.
func pop_to_steam_face(texture: Texture2D) -> void:
	steam_texture = texture
	_swap_face_animated(true, true)


## Later swaps between the Steam face and the built face. Only the face
## squashes and springs; the head itself isn't kicked, so it can stay still.
func swap_face(to_steam: bool) -> void:
	if to_steam == show_steam_face or (to_steam and steam_texture == null):
		return
	_swap_face_animated(to_steam, false)


func _swap_face_animated(to_steam: bool, kick: bool) -> void:
	var tween := create_tween()
	if not face_hidden:
		tween.tween_property(self, "face_scale", Vector2(1.25, 0.7), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "face_scale", Vector2(0.15, 0.15), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		show_steam_face = to_steam
		face_hidden = false
		face_scale = Vector2(0.15, 0.15)
		if kick:
			bobble.pop(1.0)
			popped.emit()
		face_swapped.emit(to_steam))
	tween.tween_property(self, "face_scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	var r := radius()
	var c := Vector2(0.0, -r * 0.92)
	if head_only:
		_draw_head_layers(c, r, false)
		return
	if show_body:
		_draw_base_and_body()
	if is_balloon() and _rope != null:
		_draw_balloon(c, r)
		return
	if is_marionette() and _puppet != null:
		_draw_marionette(c, r)
		return
	_draw_neck()
	draw_set_transform(bobble.offset, bobble.angle + _look_tilt, Vector2.ONE)
	_draw_head_layers(c, r, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_head_layers(c: Vector2, r: float, stars: bool) -> void:
	var hidden_hair := mystery == "hair"
	var hidden_hat := mystery == "accessory" or mystery == "accessory_variant"
	if not hidden_hair:
		_draw_hair_back(c, r)
	if not face_hidden:
		_draw_face(c, r)
	if not hidden_hair:
		_draw_hair_front(c, r)
	if not hidden_hat:
		_draw_accessory(c, r)
	if hidden_hair:
		_draw_mystery_mark(c + Vector2(0, -r * 0.98), r * 0.5)
	if hidden_hat:
		_draw_mystery_mark(c + Vector2(0, -r * 1.35), r * 0.6)
	if mystery == "rig":
		_draw_mystery_mark(c + Vector2(r * 1.25, -r * 0.4), r * 0.5)
	if stars and _stars_left > 0.0:
		_draw_dizzy_stars(c, r)


# --------------------------------------------------------------------------
# Marionette rig
# --------------------------------------------------------------------------

## Body and stand are already drawn (moved by the puppet); this adds the
## strings, the rope tying the head to the body, the hanging head and the
## control bar.
func _draw_marionette(c: Vector2, r: float) -> void:
	for i in _puppet.attach.size():
		var end := _body_xform * _limb_end(i)
		var from := _puppet.bar_point(i)
		_draw_string(from, end)
	_draw_string(_puppet.bar_center(), _puppet.head_string_end())
	_draw_tether()
	# Head space puts the head's centre at c; move that onto the hanging head.
	draw_set_transform_matrix(Transform2D(_puppet.head_angle + _look_tilt, _puppet.head) * Transform2D(0.0, -c))
	_draw_head_layers(c, r, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_control_bar()


func _draw_string(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, OUTLINE, 3.0, true)
	draw_line(from, to, STRING_COLOR, 1.4, true)


## The rope from the back of the body up to the middle of the head (drawn
## behind the head, so it disappears under it). It sags when it's slack.
func _draw_tether() -> void:
	var from := _body_xform * _puppet.tether_attach
	var to := _puppet.head
	var gap := from.distance_to(to)
	var slack := sqrt(maxf(_puppet.tether_length * _puppet.tether_length - gap * gap, 0.0)) * 0.5
	var mid := (from + to) * 0.5 + Vector2(0, slack)
	var pts := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		pts.append(from.lerp(mid, t).lerp(mid.lerp(to, t), t))
	draw_polyline(pts, OUTLINE, 6.0, true)
	draw_polyline(pts, Color("#c9a26b"), 3.5, true)


## Where string i ties on, after its arm or leg has swung.
func _limb_end(i: int) -> Vector2:
	var attach := _puppet.attach[i]
	var arms := BodyShapes.arms(build.body_shape)
	if i < arms.size() and not BodyShapes.is_animal(build.body_shape):
		var shoulder := (arms[i][0] + arms[i][1]) * 0.5
		return shoulder + (attach - shoulder).rotated(_limb_swing[i])
	return attach  # leg tops don't move when the legs swing


## A wooden cross: the long plank the strings hang from, and a short one
## across it as a handle.
func _draw_control_bar() -> void:
	var center := _puppet.bar_center()
	var half := _bar_half_width()
	var plank := Rect2(center + Vector2(-half, -7), Vector2(half * 2.0, 14))
	draw_rect(plank, WOOD)
	draw_rect(plank, OUTLINE, false, 3.0)
	var handle := Rect2(center + Vector2(-7, -28), Vector2(14, 56))
	draw_rect(handle, WOOD.darkened(0.12))
	draw_rect(handle, OUTLINE, false, 3.0)
	for p in _puppet.bar_points:
		draw_circle(center + p, 4.0, OUTLINE)


# --------------------------------------------------------------------------
# Balloon rig
# --------------------------------------------------------------------------

func _draw_balloon(c: Vector2, r: float) -> void:
	draw_polyline(_rope.points, OUTLINE, 3.5, true)
	draw_polyline(_rope.points, STRING_COLOR, 1.8, true)
	match _balloon:
		Balloon.INFLATED, Balloon.POP_PENDING:
			draw_set_transform(bobble.offset, bobble.angle + _look_tilt, Vector2.ONE)
			_draw_knot(r)
			_draw_head_layers(c, r, true)
		Balloon.INFLATING:
			draw_set_transform(bobble.offset, bobble.angle + _look_tilt, Vector2(_inflate, _inflate))
			_draw_knot(r)
			_draw_head_layers(c, r, false)
		Balloon.POPPING:
			draw_set_transform(bobble.offset, bobble.angle + _look_tilt, Vector2.ONE)
			_draw_tearing_skin(c, r)
		Balloon.DEFLATED:
			_draw_scrap(r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The little tied-off neck of the balloon, under the face.
func _draw_knot(r: float) -> void:
	var knot := PackedVector2Array([Vector2(-r * 0.07, r * 0.1), Vector2(0, -r * 0.02), Vector2(r * 0.07, r * 0.1)])
	draw_colored_polygon(knot, _face_color().darkened(0.12))
	draw_polyline(_closed(knot), OUTLINE, 2.5, true)


## The pop: a tear opens where the head was hit and the skin snaps back
## toward the far side, faster and faster, until nothing is left.
func _draw_tearing_skin(c: Vector2, r: float) -> void:
	if _snapshot == null:
		return
	var p := clampf(_balloon_t / POP_SECONDS, 0.0, 1.0)
	var big := r * 2.0  # covers the head and its tallest hat
	var disc := _ellipse(c, big, big, 72)
	var hole_center := c + _pop_dir * big
	var start := big - r * 0.97
	var hole_r := lerpf(start, big * 2.05, p * p)
	var hole := PackedVector2Array()
	for i in 56:
		var a := TAU * float(i) / 56.0
		var jag := 1.0 + 0.05 * sin(float(i) * 2.7) + 0.035 * sin(float(i) * 5.9 + 1.0)
		hole.append(hole_center + Vector2.from_angle(a) * hole_r * jag)
	var texture := _snapshot.get_texture()
	var origin := c - Vector2(big, big)
	for piece in Geometry2D.clip_polygons(disc, hole):
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		var uvs := PackedVector2Array()
		for q in piece:
			uvs.append((q - origin) / (big * 2.0))
		draw_colored_polygon(piece, Color.WHITE, uvs, texture)
	# The rolled-up rubber at the edge of the tear, where it crosses the face.
	var lip_color := _face_color().darkened(0.3)
	for line in Geometry2D.intersect_polyline_with_polygon(_closed(hole), _face_polygon(build.face_shape, c, r)):
		draw_polyline(line, lip_color, 4.0, true)


## What's left: a limp scrap on the end of the string, which shrivels a
## little more as the last of the air goes.
func _draw_scrap(r: float) -> void:
	var n := _rope.points.size()
	var tip := _rope.points[n - 1]
	var along := tip - _rope.points[n - 2]
	var angle := along.angle() - PI / 2.0 if along.length() > 0.01 else 0.0
	var shrink := lerpf(1.7, 1.0, clampf(_balloon_t / 0.3, 0.0, 1.0))
	draw_set_transform(tip, angle, Vector2(shrink, shrink))
	var skin := _face_color()
	draw_colored_polygon(_scrap, skin)
	# Wrinkles where the empty skin folds over itself.
	var fold := skin.darkened(0.28)
	draw_polyline(PackedVector2Array([Vector2(-r * 0.06, r * 0.1), Vector2(r * 0.02, r * 0.2), Vector2(-r * 0.03, r * 0.3)]), fold, 2.5, true)
	draw_polyline(PackedVector2Array([Vector2(r * 0.07, r * 0.12), Vector2(r * 0.04, r * 0.24)]), fold, 2.5, true)
	draw_polyline(_closed(_scrap), OUTLINE, 2.5, true)
	_draw_knot(r)


## Five stars on a tilted ring around the top of the head. They fade in and
## out at the ends, and the ones on the far side of the ring are smaller and
## dimmer, so the ring reads as going around the head.
func _draw_dizzy_stars(c: Vector2, r: float) -> void:
	var elapsed := _stars_total - _stars_left
	var fade := clampf(minf(elapsed / 0.25, _stars_left / 0.5), 0.0, 1.0)
	var center := c + Vector2(0, -r * 1.05)
	var count := 5
	for i in count:
		var a := _stars_spin + TAU * float(i) / count
		var depth := (sin(a) + 1.0) * 0.5   # 0 = far side, 1 = near side
		var p := center + Vector2(cos(a) * r * 1.1, sin(a) * r * 0.3)
		var size := r * lerpf(0.13, 0.2, depth)
		var color := Color("#ffd84a")
		color.a = fade * lerpf(0.55, 1.0, depth)
		var outline := OUTLINE
		outline.a = color.a
		var pts := PackedVector2Array()
		for k in 10:
			var ang := -PI / 2.0 + TAU * float(k) / 10.0 + _stars_spin * 0.8
			pts.append(p + Vector2.from_angle(ang) * (size if k % 2 == 0 else size * 0.45))
		draw_colored_polygon(pts, color)
		draw_polyline(_closed(pts), outline, 3.0, true)


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
	# Body: deliberately tiny next to the head. Arms, legs and the tail go
	# behind the torso so their inner ends tuck under it. The marionette can
	# lift and tilt it off the stand (_body_xform).
	draw_set_transform_matrix(_body_xform)
	var shape := build.body_shape
	var body := BodyShapes.outline(shape)
	var textured := build.use_body_texture and body_texture != null
	var look := Variants.body(Catalog.BASES["body"][shape], build.body_variant)
	var hidden_body := mystery == "body_shape" or mystery == "body_variant"
	if hidden_body:
		look = {"base": MYSTERY_GREY, "pattern": ""}
		textured = false
	if shape == BodyShapes.UNICORN and not hidden_body:
		_draw_rainbow_tail()
	_draw_legs(shape, look, textured)
	_draw_arms(shape, look, textured)
	if textured:
		draw_colored_polygon(body, Color.WHITE, BodyShapes.uvs(body), body_texture)
	else:
		_fill(body, look, 60.0)
		if not hidden_body:
			# Trim coordinates are for the full-width outline; squeeze them to match.
			draw_set_transform_matrix(_body_xform * Transform2D(0.0, Vector2(BodyShapes.width_scale(shape), 1.0), 0.0, Vector2.ZERO))
			_draw_body_details(shape, look)
			draw_set_transform_matrix(_body_xform)
	draw_polyline(_closed(body), OUTLINE, 4.0, true)
	if hidden_body:
		_draw_mystery_mark(Vector2(0, 108), 46.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sleeves take the body's variant (or the uploaded texture); hands, and the
## T-shirt's bare arms, take the skin color.
func _draw_arms(shape: int, look: Dictionary, textured: bool) -> void:
	var arms := BodyShapes.arms(shape)
	var hands := BodyShapes.hands(shape)
	for i in arms.size():
		var swing := _swing(i)
		if swing != 0.0:
			var shoulder := (arms[i][0] + arms[i][1]) * 0.5
			var turned := PackedVector2Array()
			for p in arms[i]:
				turned.append(shoulder + (p - shoulder).rotated(swing))
			arms[i] = turned
			hands[i] = shoulder + (hands[i] - shoulder).rotated(swing)
	for hand in hands:
		draw_circle(hand, BodyShapes.HAND_RADIUS, build.skin_color())
		draw_arc(hand, BodyShapes.HAND_RADIUS, 0, TAU, 20, OUTLINE, 3.0, true)
	for arm in arms:
		if BodyShapes.bare_arms(shape):
			draw_colored_polygon(arm, build.skin_color())
		elif textured:
			draw_colored_polygon(arm, Color.WHITE, BodyShapes.uvs(arm), body_texture)
		else:
			_fill(arm, look, 60.0)
		draw_polyline(_closed(arm), OUTLINE, 3.0, true)


## Four legs for the animals: the body's color (or texture), hooves in the
## trim color when the variant has one.
func _draw_legs(shape: int, look: Dictionary, textured: bool) -> void:
	var hoof_color: Color = look.get("trim", Color("#3a2a20"))
	var legs := BodyShapes.legs(shape)
	for i in legs.size():
		var leg := legs[i]
		var swing := _swing(i)
		if swing != 0.0:
			# A swinging leg: drawn turned about its top, hoof included.
			var top := Vector2(leg.get_center().x, leg.position.y)
			draw_set_transform_matrix(_body_xform * Transform2D(swing, top) * Transform2D(0.0, -top))
		var pts := BodyShapes.rect_points(leg)
		if textured:
			draw_colored_polygon(pts, Color.WHITE, BodyShapes.uvs(pts), body_texture)
		else:
			draw_colored_polygon(pts, (look["base"] as Color).darkened(0.08))
		draw_polyline(_closed(pts), OUTLINE, 3.0, true)
		var hoof := Rect2(leg.position.x - 1, leg.end.y - 9, leg.size.x + 2, 9)
		draw_rect(hoof, hoof_color)
		draw_rect(hoof, OUTLINE, false, 3.0)
		if swing != 0.0:
			draw_set_transform_matrix(_body_xform)


## How far limb i is swung (marionette only; 0 otherwise).
func _swing(i: int) -> float:
	if _puppet == null or i >= _limb_swing.size():
		return 0.0
	return _limb_swing[i]


## The unicorn's tail: six rainbow strands, the same on every style.
func _draw_rainbow_tail() -> void:
	var curve := BodyShapes.tail_curve()
	var strand := 6.0
	draw_polyline(curve, OUTLINE, strand * RAINBOW.size() + 6.0, true)
	for i in RAINBOW.size():
		var offset := (float(i) - (RAINBOW.size() - 1) * 0.5) * strand
		var pts := PackedVector2Array()
		for k in curve.size():
			var dir := (curve[mini(k + 1, curve.size() - 1)] - curve[maxi(k - 1, 0)]).normalized()
			pts.append(curve[k] + dir.orthogonal() * offset)
		draw_polyline(pts, RAINBOW[i], strand + 0.5, true)


## Fills a shape with a variant: its plain color, or its pattern tiled every
## `tile` units.
func _fill(points: PackedVector2Array, look: Dictionary, tile: float) -> void:
	var pattern: String = look.get("pattern", "")
	if pattern == "":
		draw_colored_polygon(points, look["base"])
		return
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append(p / tile)
	draw_colored_polygon(points, Color.WHITE, uvs, Patterns.texture(pattern, look["base"], look.get("accent", look["base"])))


## Trim per body shape, from the variant's colors. Skipped for textured bodies.
func _draw_body_details(shape: int, look: Dictionary) -> void:
	var color: Color = look["base"]
	var trim: Color = look.get("trim", Color.WHITE)
	var light := color.lightened(0.18)
	var dark := color.darkened(0.25)
	match shape:
		0:  # Suit: shirt, tie, lapels
			draw_colored_polygon(PackedVector2Array([Vector2(-16, 36), Vector2(16, 36), Vector2(0, 80)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 44), Vector2(6, 44), Vector2(9, 110), Vector2(0, 122), Vector2(-9, 110)]), trim)
			draw_line(Vector2(-40, 36), Vector2(-8, 100), light, 5.0)
			draw_line(Vector2(40, 36), Vector2(8, 100), light, 5.0)
		1:  # Hoodie: hood rim, pocket, strings
			draw_arc(Vector2(0, 40), 34, 0.1, PI - 0.1, 16, dark, 8.0, true)
			draw_rect(Rect2(-36, 118, 72, 34), dark)
			draw_line(Vector2(-10, 46), Vector2(-12, 90), trim, 3.0, true)
			draw_line(Vector2(10, 46), Vector2(12, 90), trim, 3.0, true)
		2:  # T-shirt: collar
			draw_arc(Vector2(0, 36), 16, 0.0, PI, 12, dark, 5.0, true)
		3:  # Robe: V collar in the trim color
			draw_colored_polygon(PackedVector2Array([Vector2(-20, 36), Vector2(20, 36), Vector2(0, 76)]), trim if look.has("trim") else light)
		4:  # Goat: a few tufts and a bell
			for p in [Vector2(-40, 86), Vector2(30, 76), Vector2(-10, 126), Vector2(42, 124)]:
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


## A big "?" where a part would be (Customize's locked-items entry).
func _draw_mystery_mark(at: Vector2, size: float) -> void:
	var font := ThemeDB.fallback_font
	var font_size := int(size * 1.6)
	var width := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at + Vector2(-width * 0.5, font_size * 0.36)
	draw_string_outline(font, pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(4, font_size / 8), OUTLINE)
	draw_string(font, pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#ffe066"))


func _draw_face(c: Vector2, r: float) -> void:
	if mystery == "face_shape":
		var blank := _ellipse(c, r * 0.9, r * 0.92, 48)
		draw_colored_polygon(blank, MYSTERY_GREY)
		draw_polyline(_closed(blank), OUTLINE, 5.0, true)
		_draw_mystery_mark(c, r * 0.8)
		return
	var outline := _face_polygon(build.face_shape, c, r)
	var scaled := PackedVector2Array()
	for p in outline:
		scaled.append(c + (p - c) * face_scale)
	var animal := _animal()
	match animal:
		"unicorn": _draw_unicorn_ears(c, r)
		"goat": _draw_goat_ears(c, r)

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

	var s := face_scale
	if animal == "":
		draw_colored_polygon(scaled, build.skin_color())
	else:
		_fill(scaled, _animal_look(), 60.0)
	if animal == "goat":
		_draw_goat_beard(c, r, s)
	draw_polyline(_closed(scaled), OUTLINE, 5.0, true)
	match animal:
		"unicorn": _draw_unicorn_muzzle(c, r, s)
		"goat": _draw_goat_muzzle(c, r, s)
	if mystery == "eyes":
		_draw_mystery_mark(c + Vector2(0, -r * 0.12) * s, r * 0.32)
	else:
		_draw_eyes(c, r, s)
	if mystery == "mouth" and animal == "":
		_draw_mystery_mark(c + Vector2(0, r * 0.4) * s, r * 0.3)
	elif animal == "":
		_draw_mouth(c, r, s)  # animal faces have their own mouth on the muzzle


## "unicorn", "goat", or "" for a person's face.
func _animal() -> String:
	var face := Catalog.animal_face(build.face_shape)
	return "" if face.is_empty() else str(face[0])


## An animal face takes the colors and pattern of the matching body style.
func _animal_look() -> Dictionary:
	var face := Catalog.animal_face(build.face_shape)
	return Variants.body(face[0], face[1])


## The face's main color: skin, or the animal's coat.
func _face_color() -> Color:
	return build.skin_color() if _animal() == "" else _animal_look()["base"]


## Dark enough lines to read on the face: dark ink on light faces, light on dark.
func _ink() -> Color:
	return Color("#f4eefc") if _face_color().get_luminance() < 0.3 and not (show_steam_face and steam_texture != null) else OUTLINE


## A lighter shade for muzzles and ear insides, readable on any coat.
func _muzzle_color() -> Color:
	var coat := _face_color()
	return coat.lerp(Color.WHITE, 0.45) if coat.get_luminance() < 0.3 else coat.lerp(Color("#f4a6c6"), 0.3)


## Pointed ears behind the unicorn face, with pink insides. They stay on
## when the Steam face shows.
func _draw_unicorn_ears(c: Vector2, r: float) -> void:
	for a in [PI * 1.31, PI * 1.69]:
		var ear := PackedVector2Array([
			c + Vector2.from_angle(a - 0.16) * r * 0.78,
			c + Vector2.from_angle(a) * r * 1.3,
			c + Vector2.from_angle(a + 0.16) * r * 0.78,
		])
		_fill(ear, _animal_look(), 60.0)
		draw_polyline(_closed(ear), OUTLINE, 4.0, true)
		var inner := PackedVector2Array([
			c + Vector2.from_angle(a - 0.08) * r * 0.86,
			c + Vector2.from_angle(a) * r * 1.18,
			c + Vector2.from_angle(a + 0.08) * r * 0.86,
		])
		draw_colored_polygon(inner, Color("#f4a6c6"))


## Floppy goat ears sticking out sideways and drooping a little.
func _draw_goat_ears(c: Vector2, r: float) -> void:
	for side in [-1.0, 1.0]:
		var center := c + Vector2(side * r * 0.76, -r * 0.16)
		var tilt: float = side * 0.38
		var ear := PackedVector2Array()
		var inner := PackedVector2Array()
		for p in _ellipse(Vector2.ZERO, r * 0.34, r * 0.13, 28):
			ear.append(center + p.rotated(tilt))
			inner.append(center + (p * Vector2(0.7, 0.45) + Vector2(side * r * 0.04, 0)).rotated(tilt))
		_fill(ear, _animal_look(), 60.0)
		draw_polyline(_closed(ear), OUTLINE, 4.0, true)
		draw_colored_polygon(inner, _muzzle_color())


## A tuft of beard under the goat's chin, drawn behind the face outline.
func _draw_goat_beard(c: Vector2, r: float, s: Vector2) -> void:
	var beard := PackedVector2Array()
	for p in [Vector2(-0.14, 0.8), Vector2(0.14, 0.8), Vector2(0.07, 1.06), Vector2(0.02, 1.26), Vector2(-0.04, 1.1)]:
		beard.append(c + p * r * s)
	var coat := _face_color()
	draw_colored_polygon(beard, coat.lightened(0.35) if coat.get_luminance() < 0.3 else coat.darkened(0.22))
	draw_polyline(_closed(beard), OUTLINE, 3.0, true)


## The unicorn's muzzle: lighter, with nostrils and a small smile.
func _draw_unicorn_muzzle(c: Vector2, r: float, s: Vector2) -> void:
	var muzzle := PackedVector2Array()
	for p in _ellipse(Vector2.ZERO, r * 0.44, r * 0.3, 40):
		muzzle.append(c + (Vector2(0, r * 0.5) + p) * s)
	var light := _muzzle_color()
	draw_colored_polygon(muzzle, light)
	draw_polyline(_closed(muzzle), light.darkened(0.3), 2.0, true)
	var dark := light.darkened(0.55)
	for side in [-1.0, 1.0]:
		var n := PackedVector2Array()
		for p in _ellipse(Vector2.ZERO, r * 0.045, r * 0.03, 12):
			n.append(c + (Vector2(side * r * 0.2, r * 0.36) + p) * s)
		draw_colored_polygon(n, dark)
	draw_arc(c + Vector2(0, r * 0.47) * s, r * 0.16 * s.x, PI * 0.22, PI * 0.78, 16, dark, 4.0, true)


## The goat's muzzle: a soft snout with slanted nostrils and a little "w" mouth.
func _draw_goat_muzzle(c: Vector2, r: float, s: Vector2) -> void:
	var muzzle := PackedVector2Array()
	for p in _ellipse(Vector2.ZERO, r * 0.34, r * 0.28, 40):
		muzzle.append(c + (Vector2(0, r * 0.54) + p) * s)
	var light := _muzzle_color()
	draw_colored_polygon(muzzle, light)
	draw_polyline(_closed(muzzle), light.darkened(0.3), 2.0, true)
	var dark := light.darkened(0.55)
	for side in [-1.0, 1.0]:
		draw_line(c + Vector2(side * r * 0.08, r * 0.42) * s, c + Vector2(side * r * 0.15, r * 0.48) * s, dark, 4.0, true)
		draw_arc(c + Vector2(side * r * 0.07, r * 0.6) * s, r * 0.07 * s.x, PI * 0.1, PI * 0.9, 10, dark, 3.5, true)
	draw_line(c + Vector2(0, r * 0.5) * s, c + Vector2(0, r * 0.62) * s, dark, 3.5, true)


## Each eye style looks at the cursor its own way (gaze is smoothed and capped
## in _update_gaze):
##   Googly : the pupil slides inside the white
##   Dots   : the whole dot shifts a little
##   Angry  : the dot shifts; the brow stays put
##   Happy  : closed eyes don't move; the head tilts instead (_looks_with_head)
func _draw_eyes(c: Vector2, r: float, s: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.32, -r * 0.12) * s
		match build.eyes:
			0:  # Dots
				draw_circle(e + _gaze * r * 0.1 * s, r * 0.075 * s.y, _ink())
			1:  # Googly: pupils look at the cursor and lag behind the bobble
				draw_circle(e, r * 0.19 * s.y, Color.WHITE)
				draw_arc(e, r * 0.19 * s.y, 0, TAU, 32, OUTLINE, 3.0, true)
				var lag := Vector2(-bobble.angle * 28.0, 6.0 - bobble.offset_velocity.y * 0.01) * 0.4
				var pupil := (_gaze * r * 0.12 + lag).limit_length(r * 0.115)
				draw_circle(e + pupil * s, r * 0.07 * s.y, OUTLINE)
			2:  # Happy (closed, curved)
				draw_arc(e + Vector2(0, r * 0.05) * s, r * 0.1 * s.y, PI, TAU, 16, _ink(), 5.0, true)
			3:  # Angry
				draw_circle(e + (Vector2(0, r * 0.03) + _gaze * r * 0.08) * s, r * 0.07 * s.y, _ink())
				var inner := Vector2(-side * r * 0.04, -r * 0.08) * s
				var outer := Vector2(side * r * 0.16, -r * 0.17) * s
				draw_line(e + inner, e + outer, _ink(), 6.0, true)


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
	if build.hair == 3:  # Mop: a big mass behind the face, following its shape
		var mass := PackedVector2Array()
		for i in 48:
			var a := TAU * float(i) / 48.0
			mass.append(c + Vector2(0, -r * 0.08) + Vector2.from_angle(a) * _hair_r(a, r, 1.06))
		draw_colored_polygon(mass, build.hair_color)
		draw_polyline(_closed(mass), OUTLINE, 4.0, true)
	elif build.hair == RAINBOW_HAIR:  # Rainbow mane: flows down the right side
		_draw_rainbow_band(c, r, 0.96, r * 0.055, -PI * 0.62, PI * 0.32)


## Six rainbow stripes following the face outline, starting `inner_k` out
## (as on the round face) and each `width` thick. Ignores the hair color: the
## rainbow is the point.
func _draw_rainbow_band(c: Vector2, r: float, inner_k: float, width: float, a0: float, a1: float) -> void:
	var n := RAINBOW.size()
	var steps := 40
	var stripes: Array[PackedVector2Array] = []
	for i in n:
		stripes.append(PackedVector2Array())
	var middle := PackedVector2Array()
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		var dir := Vector2.from_angle(a)
		var base := _hair_r(a, r, inner_k)
		middle.append(c + dir * (base + width * n * 0.5))
		for i in n:
			stripes[i].append(c + dir * (base + width * (n - 1 - i + 0.5)))
	draw_polyline(middle, OUTLINE, width * n + 6.0, true)
	for i in n:
		draw_polyline(stripes[i], RAINBOW[i], width + 0.8, true)


# --------------------------------------------------------------------------
# Hair follows the face's own outline
# --------------------------------------------------------------------------

const EDGE_STEPS := 90
## Distance from the head centre to the face's edge, every 4 degrees, for the
## current face shape and size (rebuilt when either changes).
var _edges := PackedFloat32Array()
var _edges_key := ""


## How far hair goes out at angle `a`: `k` is that distance as a fraction of r
## on the Round face (radius 0.92 r), scaled to wherever this face's edge is.
## So a cap drawn for the Round face hugs an Oval, Egg or animal face too.
func _hair_r(a: float, r: float, k: float) -> float:
	return _face_edge(a, r) * k / 0.92


func _face_edge(a: float, r: float) -> float:
	var key := "%d/%.2f" % [build.face_shape, r]
	if key != _edges_key:
		_edges_key = key
		_edges.resize(EDGE_STEPS)
		var outline := _face_polygon(build.face_shape, Vector2.ZERO, r)
		for k in EDGE_STEPS:
			var ray := Vector2.from_angle(TAU * float(k) / EDGE_STEPS) * r * 3.0
			var best := r * 0.92
			for i in outline.size():
				var hit: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO, ray, outline[i], outline[(i + 1) % outline.size()])
				if hit != null:
					best = (hit as Vector2).length()
					break
			_edges[k] = best
	var f := fposmod(a, TAU) / TAU * EDGE_STEPS
	var i0 := int(f) % EDGE_STEPS
	return lerpf(_edges[i0], _edges[(i0 + 1) % EDGE_STEPS], f - floorf(f))


## Hats sit on top of the head, so hair that would stick up through them is
## tucked under instead ("hat hair"). Otherwise a tall hairstyle pokes out
## behind the hat and reads as a second hat.
func _wearing_hat() -> bool:
	return build.accessory in [2, 3, 5, UNICORN_HORN]  # party hat, crown, wizard hat, unicorn horn


func _draw_hair_front(c: Vector2, r: float) -> void:
	var hat := _wearing_hat()
	match build.hair:
		1:  # Buzz
			_draw_cap(c, r, 0.99, 0.84, PI * 1.08, PI * 1.92)
		2:  # Spiky
			_draw_cap(c, r, 0.99, 0.82, PI * 1.05, PI * 1.95)
			for i in range(7):
				var a := lerpf(PI * 1.12, PI * 1.88, float(i) / 6.0)
				if hat and a > PI * 1.3 and a < PI * 1.7:
					continue  # the hat covers the top spikes
				var dir := Vector2.from_angle(a)
				var tangent := dir.orthogonal()
				var root := c + dir * _hair_r(a, r, 0.9)
				var spike := PackedVector2Array([root + tangent * r * 0.12, root + dir * r * 0.42, root - tangent * r * 0.12])
				draw_colored_polygon(spike, build.hair_color)
				draw_polyline(spike, OUTLINE, 3.0, true)
		3:  # Mop fringe with a wavy edge
			var pts := PackedVector2Array()
			for i in range(25):
				var a := lerpf(PI * 1.0, PI * 2.0, float(i) / 24.0)
				pts.append(c + Vector2.from_angle(a) * _hair_r(a, r, 1.0))
			for i in range(24, -1, -1):
				var a := lerpf(PI * 1.0, PI * 2.0, float(i) / 24.0)
				var wave := 0.62 + 0.08 * sin(float(i) * 1.6)
				pts.append(c + Vector2.from_angle(a) * _hair_r(a, r, wave) + Vector2(0, r * 0.12))
			draw_colored_polygon(pts, build.hair_color)
			draw_polyline(_closed(pts), OUTLINE, 3.0, true)
		4:  # Mohawk
			if hat:
				# Tucked under the hat: only a stripe of crest shows below the brim.
				_draw_cap(c, r, 0.99, 0.86, PI * 1.38, PI * 1.62)
				return
			var pts := PackedVector2Array()
			for i in range(7):
				var a := lerpf(PI * 1.4, PI * 1.6, float(i) / 6.0)
				var reach := 1.55 if i % 2 == 1 else 1.2
				pts.append(c + Vector2.from_angle(a) * _hair_r(a, r, reach))
			pts.append(c + Vector2.from_angle(PI * 1.6) * _hair_r(PI * 1.6, r, 0.8))
			pts.append(c + Vector2.from_angle(PI * 1.4) * _hair_r(PI * 1.4, r, 0.8))
			draw_colored_polygon(pts, build.hair_color)
			draw_polyline(_closed(pts), OUTLINE, 3.0, true)
		RAINBOW_HAIR:  # Rainbow fringe across the top of the head
			_draw_rainbow_band(c, r, 0.8, r * 0.033, PI * 1.06, PI * 1.94)


func _draw_accessory(c: Vector2, r: float) -> void:
	if build.accessory == 0:
		return
	var look := Variants.accessory(Catalog.BASES["accessory"][build.accessory - 1], build.accessory_variant)
	match build.accessory:
		1:  # Glasses: frame color and lens tint
			var frame: Color = look["base"]
			for side in [-1.0, 1.0]:
				var e := c + Vector2(side * r * 0.32, -r * 0.12)
				draw_circle(e, r * 0.2, look["accent"])
				draw_arc(e, r * 0.2, 0, TAU, 32, frame, 6.0, true)
			draw_line(c + Vector2(-r * 0.12, -r * 0.14), c + Vector2(r * 0.12, -r * 0.14), frame, 6.0, true)
			draw_line(c + Vector2(-r * 0.52, -r * 0.14), c + Vector2(-r * 0.8, -r * 0.2), frame, 6.0, true)
			draw_line(c + Vector2(r * 0.52, -r * 0.14), c + Vector2(r * 0.8, -r * 0.2), frame, 6.0, true)
		2:  # Party hat: patterned cone, pom-pom in the trim color
			var apex := c + Vector2(r * 0.12, -r * 1.75)
			var hat := PackedVector2Array([c + Vector2(-r * 0.38, -r * 0.8), apex, c + Vector2(r * 0.42, -r * 0.84)])
			_fill(hat, look, r * 0.55)
			draw_polyline(_closed(hat), OUTLINE, 4.0, true)
			draw_circle(apex, r * 0.09, look["trim"])
			draw_arc(apex, r * 0.09, 0, TAU, 20, OUTLINE, 3.0, true)
		3:  # Crown: metal color and three gems
			var y0 := c.y - r * 0.82
			var w := r * 0.55
			var crown := PackedVector2Array([
				Vector2(c.x - w, y0), Vector2(c.x - w, y0 - r * 0.42), Vector2(c.x - w * 0.5, y0 - r * 0.22),
				Vector2(c.x, y0 - r * 0.5), Vector2(c.x + w * 0.5, y0 - r * 0.22), Vector2(c.x + w, y0 - r * 0.42),
				Vector2(c.x + w, y0),
			])
			draw_colored_polygon(crown, look["base"])
			draw_polyline(_closed(crown), OUTLINE, 4.0, true)
			var gems: Array = look["gems"]
			draw_circle(Vector2(c.x, y0 - r * 0.12), r * 0.06, gems[0])
			draw_circle(Vector2(c.x - w * 0.6, y0 - r * 0.1), r * 0.045, gems[1])
			draw_circle(Vector2(c.x + w * 0.6, y0 - r * 0.1), r * 0.045, gems[2])
		4:  # Goat horns (a Scapegoat nod); the candy variant is striped
			var thickness := r * 0.14
			for side in [-1.0, 1.0]:
				var hc := c + Vector2(side * r * 0.62, -r * 0.78)
				var a0 := PI * 0.3 if side < 0 else PI * 0.7
				var a1 := -PI * 1.0 if side < 0 else PI * 2.0
				draw_arc(hc, r * 0.3, a0, a1, 24, OUTLINE, thickness + 6.0, true)
				if look.get("pattern", "") == "candy":
					var bands := 8
					for i in bands:
						var b0 := lerpf(a0, a1, float(i) / bands)
						var b1 := lerpf(a0, a1, float(i + 1) / bands)
						draw_arc(hc, r * 0.3, b0, b1, 4, look["base"] if i % 2 == 0 else look["accent"], thickness, true)
				else:
					draw_arc(hc, r * 0.3, a0, a1, 24, look["base"], thickness, true)
		5:  # Wizard hat
			_draw_wizard_hat(c, r, look)
		UNICORN_HORN:
			_draw_unicorn_horn(c, r, look)


## A spiral horn on the forehead: the base color with slanted bands in the
## accent color.
func _draw_unicorn_horn(c: Vector2, r: float, look: Dictionary) -> void:
	var left := c + Vector2(-r * 0.19, -r * 0.82)
	var right := c + Vector2(r * 0.19, -r * 0.82)
	var apex := c + Vector2(r * 0.08, -r * 1.9)
	var cone := PackedVector2Array([left, apex, right])
	draw_colored_polygon(cone, look["base"])
	var bands := 7
	var slant := 0.07
	for k in range(0, bands, 2):
		var t0 := float(k) / bands
		var t1 := float(k + 1) / bands
		var band := PackedVector2Array([
			left.lerp(apex, t0), left.lerp(apex, t1),
			right.lerp(apex, minf(t1 + slant, 1.0)), right.lerp(apex, minf(t0 + slant, 1.0)),
		])
		draw_colored_polygon(band, look["accent"])
	draw_polyline(_closed(cone), OUTLINE, 4.0, true)


## A wizard hat whose tip bends over; the cone takes the variant's pattern,
## the band its trim color.
func _draw_wizard_hat(c: Vector2, r: float, look: Dictionary) -> void:
	var cone := PackedVector2Array([
		c + Vector2(-r * 0.62, -r * 0.84), c + Vector2(-r * 0.42, -r * 1.3), c + Vector2(-r * 0.16, -r * 1.78),
		c + Vector2(r * 0.12, -r * 2.08), c + Vector2(r * 0.46, -r * 2.06), c + Vector2(r * 0.26, -r * 1.86),
		c + Vector2(r * 0.22, -r * 1.5), c + Vector2(r * 0.4, -r * 1.12), c + Vector2(r * 0.62, -r * 0.84),
	])
	var brim := _ellipse(c + Vector2(0, -r * 0.84), r * 1.0, r * 0.17, 40)
	draw_colored_polygon(brim, (look["base"] as Color).darkened(0.15))
	draw_polyline(_closed(brim), OUTLINE, 4.0, true)
	_fill(cone, look, r * 0.75)
	var band := PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.88), c + Vector2(-r * 0.53, -r * 1.04), c + Vector2(r * 0.53, -r * 1.04), c + Vector2(r * 0.6, -r * 0.88)])
	draw_colored_polygon(band, look["trim"])
	draw_polyline(_closed(band), OUTLINE, 3.0, true)
	draw_polyline(_closed(cone), OUTLINE, 4.0, true)


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
			_:
				match str(Catalog.animal_face(shape)[0]) if not Catalog.animal_face(shape).is_empty() else "":
					"unicorn":  # long, a little wider at the muzzle (ears and muzzle drawn separately)
						p = Vector2(cos(t) * r * 0.72 * (1.0 + 0.1 * sin(t)), sin(t) * r * 0.98)
					"goat":  # long, narrowing to the chin
						p = Vector2(cos(t) * r * 0.72 * (1.0 - 0.14 * sin(t)), sin(t) * r * 0.98)
					_:
						p = Vector2(cos(t), sin(t)) * r * 0.92
		pts.append(c + p)
	return pts


## A band of hair between two distances from the centre (given as on the
## Round face; see _hair_r), from angle a0 to a1.
func _draw_cap(c: Vector2, r: float, outer_k: float, inner_k: float, a0: float, a1: float) -> void:
	var pts := PackedVector2Array()
	var n := 24
	for i in range(n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2.from_angle(a) * _hair_r(a, r, outer_k))
	for i in range(n, -1, -1):
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2.from_angle(a) * _hair_r(a, r, inner_k))
	draw_colored_polygon(pts, build.hair_color)
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
