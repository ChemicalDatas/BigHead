class_name Fireworks
extends Node2D
## Rockets that rise from the bottom of the screen and burst near a target.
## CPU particles: they behave the same on every renderer and GPU.

const MAX_ROCKETS := 80
const COLORS: Array[Color] = [
	Color("#ff5e5e"), Color("#ffd166"), Color("#06d6a0"), Color("#4cc9f0"),
	Color("#c77dff"), Color("#ff7eb6"), Color("#ffffff"),
]

var _active := 0


## Launches `count` rockets aimed around `target`, slightly staggered.
## Returns how many actually launched (capped so the screen stays readable).
func launch(target: Vector2, count: int) -> int:
	var launched := 0
	for i in range(count):
		if _active >= MAX_ROCKETS:
			break
		var spread := 0.0 if i == 0 else 40.0 + 22.0 * sqrt(float(i))
		var aim := target + Vector2.from_angle(randf() * TAU) * spread * randf_range(0.5, 1.0)
		var delay := minf(float(i) * 0.05, 1.2)
		_launch_one(aim, delay)
		launched += 1
	if count > 1:
		_show_multiplier(target, count)
	return launched


func _launch_one(aim: Vector2, delay: float) -> void:
	_active += 1
	var view := get_viewport_rect().size
	var rocket := Node2D.new()
	rocket.position = Vector2(clampf(aim.x + randf_range(-120.0, 120.0), 0.0, view.x), view.y + 10.0)
	rocket.set_meta("flying", true)
	add_child(rocket)
	var color: Color = COLORS[randi() % COLORS.size()]

	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 40
	trail.lifetime = 0.5
	trail.direction = Vector2.DOWN
	trail.spread = 20.0
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 60.0
	trail.gravity = Vector2(0, 200)
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 3.5
	trail.color_ramp = _fade(Color("#ffe8a3"))
	trail.emitting = delay <= 0.0
	rocket.add_child(trail)

	var tween := rocket.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: trail.emitting = true)
	tween.tween_property(rocket, "position", aim, randf_range(0.65, 0.95)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		rocket.set_meta("flying", false)
		trail.emitting = false
		_burst(aim, color))
	tween.tween_interval(1.8)
	tween.tween_callback(func() -> void:
		_active -= 1
		rocket.queue_free())


## Where rockets still climbing are, in global coordinates (for popping balloons).
func rocket_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for rocket in get_children():
		if rocket is Node2D and rocket.get_meta("flying", false):
			out.append((rocket as Node2D).global_position)
	return out


func _burst(at: Vector2, color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 90
	burst.lifetime = 1.5
	burst.spread = 180.0
	burst.direction = Vector2.UP
	burst.initial_velocity_min = 140.0
	burst.initial_velocity_max = 330.0
	burst.gravity = Vector2(0, 140)
	burst.damping_min = 30.0
	burst.damping_max = 60.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 5.5
	burst.color_ramp = _fade(color)
	burst.emitting = true
	add_child(burst)
	burst.finished.connect(burst.queue_free)


func _fade(color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	var clear := color
	clear.a = 0.0
	g.colors = PackedColorArray([color.lightened(0.3), color, clear])
	return g


func _show_multiplier(at: Vector2, count: int) -> void:
	var label := Label.new()
	label.text = "x%d" % count
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("#2a1d17"))
	label.add_theme_constant_override("outline_size", 8)
	label.position = at + Vector2(16, -60)
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.tween_callback(label.queue_free)
