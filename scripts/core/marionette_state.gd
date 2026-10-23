class_name MarionetteState
extends RefCounted
## The Marionette rig: the body hangs from a control bar by strings.
##
## The bar rests above the head. Dragging it pulls the strings; once a string
## is taut it lifts or swings the body, which otherwise sits on its stand.
## The body is one rigid piece (position `body` from its resting spot, and a
## tilt `angle`); strings are inextensible but can go slack. Solved with
## position-based dynamics: move freely, then pull each taut string back to
## length, then derive velocities from how far things actually moved.
##
## The head isn't simulated here: HeadView feeds `body_acceleration` into the
## head's spring neck so it flops with the motion.
##
## All points are in HeadView's local space (origin = neck pivot at rest).

const GRAVITY := 1400.0
const ITERATIONS := 6

## Where each string is tied on the body (hands, or leg tops), body space.
var attach: Array[Vector2] = []
## Where each string meets the bar, relative to the bar's centre.
var bar_points: Array[Vector2] = []
var string_lengths: Array[float] = []
## Where the bar's centre rests.
var bar_rest := Vector2(0, -400)
var max_bar_offset := 240.0

var bar := Vector2.ZERO           ## bar centre's offset from bar_rest
var bar_velocity := Vector2.ZERO
var dragging := false
var drag_target := Vector2.ZERO   ## wanted bar offset while dragging

var body := Vector2.ZERO          ## body offset from its resting spot (y <= 0: it can't sink into the stand)
var angle := 0.0
var _body_velocity := Vector2.ZERO
var _angular_velocity := 0.0
## How the body's velocity changed this step (pixels/s²), for the head.
var body_acceleration := Vector2.ZERO
var angular_acceleration := 0.0


## Sets up the strings; lengths are the resting distances plus a little slack
## (so at rest the arms hang and the body sits on its stand).
func configure(attach_points: Array[Vector2], bar_attach: Array[Vector2], rest: Vector2) -> void:
	attach = attach_points
	bar_points = bar_attach
	bar_rest = rest
	string_lengths.clear()
	for i in attach.size():
		string_lengths.append((rest + bar_points[i]).distance_to(attach[i]) * 1.04)


func bar_center() -> Vector2:
	return bar_rest + bar


func bar_point(i: int) -> Vector2:
	return bar_center() + bar_points[i]


## A body-space point after the body's move and tilt.
func to_world(p: Vector2) -> Vector2:
	return body + p.rotated(angle)


func step(delta: float) -> void:
	if delta <= 0.0:
		return
	_step_bar(delta)
	var old_body := body
	var old_angle := angle
	var old_velocity := _body_velocity
	var old_spin := _angular_velocity

	_body_velocity += Vector2(0, GRAVITY) * delta
	_body_velocity *= 0.995
	_angular_velocity *= 0.96
	body += _body_velocity * delta
	angle += _angular_velocity * delta

	for _k in ITERATIONS:
		for i in attach.size():
			_pull_string(i)
		_rest_on_stand()

	_body_velocity = (body - old_body) / delta
	_angular_velocity = (angle - old_angle) / delta
	if body.y >= -0.01:
		# Sitting on the stand: friction, and it rights itself.
		_body_velocity.x *= 0.85
		angle = lerpf(angle, 0.0, 0.2)
		_angular_velocity *= 0.6
	body_acceleration = (_body_velocity - old_velocity) / delta
	angular_acceleration = (_angular_velocity - old_spin) / delta


func _step_bar(delta: float) -> void:
	var target := drag_target if dragging else Vector2.ZERO
	var hz := 6.0 if dragging else 1.6
	var damping := 0.8 if dragging else 0.45
	var w := TAU * hz
	bar_velocity += (-w * w * (bar - target) - 2.0 * damping * w * bar_velocity) * delta
	bar += bar_velocity * delta
	if bar.length() > max_bar_offset:
		bar = bar.limit_length(max_bar_offset)


## A taut string pulls its end of the body back toward the bar: part of the
## correction moves the body, part turns it about its centre.
func _pull_string(i: int) -> void:
	var arm := attach[i].rotated(angle)
	var end := body + arm
	var from_bar := end - bar_point(i)
	var dist := from_bar.length()
	var length := string_lengths[i]
	if dist <= length or dist < 0.001:
		return
	var correction := from_bar / dist * (dist - length)
	body -= correction * 0.75
	var lever := arm.length_squared()
	if lever > 1.0:
		angle -= arm.cross(correction) / lever * 0.5
	angle = clampf(angle, -0.9, 0.9)


func _rest_on_stand() -> void:
	if body.y > 0.0:
		body.y = 0.0


## Tension of string i, 0 (slack) to 1 (taut), for drawing the arms and legs.
func tension(i: int) -> float:
	var dist := bar_point(i).distance_to(to_world(attach[i]))
	return clampf((dist / string_lengths[i] - 0.97) / 0.03, 0.0, 1.0)


func is_resting() -> bool:
	return not dragging and bar.length() < 1.0 and bar_velocity.length() < 3.0 \
		and body.length() < 0.5 and _body_velocity.length() < 3.0


func begin_drag() -> void:
	dragging = true
	drag_target = bar


func end_drag() -> void:
	dragging = false
