class_name BobbleState
extends RefCounted
## Two underdamped harmonic oscillators:
##   - the head's angle around the neck pivot (the bobble)
##   - a small positional offset of the head (the "boing")
## Integrated with semi-implicit Euler: velocity first, then position.
##
## While dragged, the offset is pulled toward the cursor by a stiff,
## near-critically-damped spring (stretched, not teleported). On release the
## cursor's velocity is handed to both springs for the snap-back.

## Angle spring: frequency in Hz and damping ratio (0 = never stops, 1 = no wobble).
var angle_frequency_hz := 1.4
var angle_damping_ratio := 0.12
## Offset spring: a bit stiffer and more damped than the angle.
var offset_frequency_hz := 2.2
var offset_damping_ratio := 0.22
## Drag spring: pulls the head toward the cursor while held.
var drag_frequency_hz := 5.0
var drag_damping_ratio := 0.8

var max_angle := 0.9          ## radians
var max_offset := 70.0        ## pixels, when free
var max_drag_offset := 220.0  ## pixels, while dragged

var angle := 0.0
var angular_velocity := 0.0
var offset := Vector2.ZERO
var offset_velocity := Vector2.ZERO

var dragging := false
var drag_target := Vector2.ZERO


func step(delta: float) -> void:
	var wa := TAU * angle_frequency_hz
	var angle_rest := 0.0
	if dragging:
		# Lean the head toward the side it's being pulled to.
		angle_rest = clampf(offset.x * 0.004, -max_angle * 0.6, max_angle * 0.6)
	var angular_accel := -wa * wa * (angle - angle_rest) - 2.0 * angle_damping_ratio * wa * angular_velocity
	angular_velocity += angular_accel * delta
	angle += angular_velocity * delta
	if absf(angle) > max_angle:
		angle = signf(angle) * max_angle
		angular_velocity *= -0.4

	if dragging:
		var wd := TAU * drag_frequency_hz
		var target := drag_target.limit_length(max_drag_offset)
		var drag_accel := -wd * wd * (offset - target) - 2.0 * drag_damping_ratio * wd * offset_velocity
		offset_velocity += drag_accel * delta
		offset += offset_velocity * delta
		offset = offset.limit_length(max_drag_offset)
		return

	var wo := TAU * offset_frequency_hz
	var offset_accel := -wo * wo * offset - 2.0 * offset_damping_ratio * wo * offset_velocity
	offset_velocity += offset_accel * delta
	offset += offset_velocity * delta
	if offset.length() > max_offset:
		# Coming back from a drag: let it overshoot a little, then clamp.
		var limit := maxf(max_offset, offset.length() - 400.0 * delta)
		offset = offset.limit_length(limit)


## A click: push the head toward `direction` (measured from the head's centre).
func nudge_toward(direction: Vector2, strength := 1.0) -> void:
	var d := direction.normalized() if direction.length() > 0.001 else Vector2.UP
	angular_velocity += d.x * 4.5 * strength
	offset_velocity += d * 380.0 * strength


func begin_drag() -> void:
	dragging = true
	drag_target = offset


func update_drag(target_offset: Vector2) -> void:
	drag_target = target_offset


## Ends the drag, throwing the head with the cursor's velocity (pixels per second).
func end_drag(release_velocity: Vector2) -> void:
	dragging = false
	offset_velocity = release_velocity.limit_length(3000.0) * 0.6
	angular_velocity += clampf(release_velocity.x * 0.004, -8.0, 8.0)


## The big kick when the Steam face springs out.
func pop(strength := 1.0) -> void:
	offset_velocity += Vector2(0.0, -900.0) * strength
	angular_velocity += randf_range(-1.0, 1.0) * 6.0 * strength


func is_resting() -> bool:
	return not dragging and absf(angle) < 0.005 and absf(angular_velocity) < 0.02 \
		and offset.length() < 0.5 and offset_velocity.length() < 2.0
