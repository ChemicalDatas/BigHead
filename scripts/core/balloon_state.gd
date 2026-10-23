class_name BalloonState
extends BobbleState
## The Balloon rig: the head floats on a string instead of a spring neck.
##
## `offset` is where the string is knotted to the head (the bottom of the
## face). Buoyancy pulls it toward a rest point above the anchor, which drifts
## in a slow sway; the string's length is a hard limit, so a drag can pull the
## head around but never further than the string reaches. The head tilts so
## its knot leans toward the string.
##
## HeadView sets `anchor`, `string_length` and `rest_height` from the body and
## head size, and handles popping (BalloonState only moves an inflated head).

## Where the string is tied, in the same space as `offset`.
var anchor := Vector2(0, 40)
var string_length := 200.0
## How high above the pivot the knot floats when left alone (negative = up).
var rest_height := -60.0

## Floaty: a slow, fairly damped spring toward the rest point.
var float_frequency_hz := 0.55
var float_damping_ratio := 0.3
## The head leans toward the string with a soft spring.
var lean_frequency_hz := 0.9
var lean_damping_ratio := 0.35

var _time := 0.0


func _init() -> void:
	max_drag_offset = 10000.0  # the string is the limit, not a radius
	offset = rest_point()


## The point the knot drifts around when nobody's touching it.
func rest_point() -> Vector2:
	var sway := sin(_time * 0.7) * 16.0 + sin(_time * 1.9 + 1.3) * 6.0
	return Vector2(anchor.x * 0.4 + sway, rest_height)


func step(delta: float) -> void:
	_time += delta
	if dragging:
		var wd := TAU * drag_frequency_hz
		var accel := -wd * wd * (offset - drag_target) - 2.0 * drag_damping_ratio * wd * offset_velocity
		offset_velocity += accel * delta
	else:
		var wf := TAU * float_frequency_hz
		var accel := -wf * wf * (offset - rest_point()) - 2.0 * float_damping_ratio * wf * offset_velocity
		offset_velocity += accel * delta
	offset += offset_velocity * delta
	_keep_on_string()

	# Lean so the knot points along the string.
	var to_anchor := anchor - offset
	var lean := clampf(-atan2(to_anchor.x, to_anchor.y) * 0.6, -max_angle, max_angle)
	var wl := TAU * lean_frequency_hz
	var angular_accel := -wl * wl * (angle - lean) - 2.0 * lean_damping_ratio * wl * angular_velocity
	angular_velocity += angular_accel * delta
	angle = clampf(angle + angular_velocity * delta, -max_angle, max_angle)


## The string can't stretch: past its length the knot is pulled back and loses
## the outward part of its speed (with a small bounce).
func _keep_on_string() -> void:
	var from_anchor := offset - anchor
	var length := from_anchor.length()
	if length <= string_length or length < 0.001:
		return
	var out := from_anchor / length
	offset = anchor + out * string_length
	var outward := offset_velocity.dot(out)
	if outward > 0.0:
		offset_velocity -= out * outward * 1.3


func end_drag(release_velocity: Vector2) -> void:
	dragging = false
	offset_velocity = release_velocity.limit_length(3000.0) * 0.5
	angular_velocity += clampf(release_velocity.x * 0.003, -6.0, 6.0)


## A balloon is "resting" when it's only swaying, not when it's perfectly still.
func is_resting() -> bool:
	return not dragging and offset.distance_to(rest_point()) < 10.0 \
		and offset_velocity.length() < 40.0 and absf(angular_velocity) < 0.2


## Puts the knot somewhere (the scrap's position when it reinflates) and
## starts it there.
func place(at: Vector2) -> void:
	offset = at
	offset_velocity = Vector2.ZERO
	angular_velocity = 0.0
