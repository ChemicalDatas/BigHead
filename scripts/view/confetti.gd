class_name Confetti
extends CPUParticles2D
## One-shot confetti burst for the pop. CPU particles work on every renderer.


func _init() -> void:
	emitting = false
	one_shot = true
	amount = 160
	lifetime = 1.8
	explosiveness = 1.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 50.0
	direction = Vector2.UP
	spread = 180.0
	initial_velocity_min = 300.0
	initial_velocity_max = 700.0
	gravity = Vector2(0, 900)
	damping_min = 20.0
	damping_max = 60.0
	angle_min = -180.0
	angle_max = 180.0
	angular_velocity_min = -540.0
	angular_velocity_max = 540.0
	scale_amount_min = 6.0
	scale_amount_max = 12.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Color("#e74c3c"), Color("#f1c40f"), Color("#2ecc71"),
		Color("#3498db"), Color("#9b59b6"), Color("#ff7eb6"),
	])
	color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.75, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	color_ramp = fade


func burst() -> void:
	restart()
	emitting = true
