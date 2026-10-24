class_name Confetti
extends Node2D
## Paper confetti: strips, dots, stars, hearts and curly spirals that burst
## out, then flutter down slowly, swaying and flipping over (the back of each
## piece is a lighter shade). Fireworks sparks are fast, round and glowing, so
## the slow, flat, flipping paper reads as something else even in a busy sky.
##
## Drawn by hand rather than with particles so each piece can have its own
## shape and flip. Drawn above the fireworks (z_index).

signal finished

const LIFETIME := 4.2
const FADE_SECONDS := 0.8
const GRAVITY := 900.0
const COLORS: Array[Color] = [
	Color("#e74c3c"), Color("#f1c40f"), Color("#2ecc71"),
	Color("#3498db"), Color("#9b59b6"), Color("#ff7eb6"), Color("#ff9f43"),
]

enum Shape { STRIP, DOT, STAR, HEART, SPIRAL }
## How often each shape turns up (strips are the classic, so most common).
const SHAPE_WEIGHTS := {Shape.STRIP: 40, Shape.DOT: 12, Shape.STAR: 16, Shape.HEART: 16, Shape.SPIRAL: 16}

## Pieces per burst.
var amount := 160
## Pieces start anywhere within this radius of the node.
var spread_radius := 50.0

var _pieces: Array[Dictionary] = []
var _time := 0.0

static var _star := PackedVector2Array()
static var _heart := PackedVector2Array()
static var _spiral := PackedVector2Array()


func _init() -> void:
	z_index = 10  # in front of the fireworks
	set_process(false)
	if _star.is_empty():
		_build_shapes()


func burst() -> void:
	_pieces.clear()
	_time = 0.0
	for i in amount:
		# Mostly upward, fanning out; a few go sideways or down.
		var angle := randf_range(-PI * 0.97, -PI * 0.03) if randf() < 0.85 else randf_range(0.0, PI)
		_pieces.append({
			"pos": Vector2.from_angle(randf() * TAU) * randf() * spread_radius,
			"vel": Vector2.from_angle(angle) * randf_range(320.0, 820.0),
			"rot": randf() * TAU,
			"spin": randf_range(-5.0, 5.0),
			"flip": randf() * TAU,
			"flip_speed": randf_range(5.0, 11.0),
			"sway": randf() * TAU,
			"sway_speed": randf_range(2.0, 3.6),
			"sway_amp": randf_range(35.0, 80.0),
			"fall": randf_range(70.0, 130.0),
			"size": randf_range(1.25, 1.9),  # bigger than any spark
			"shape": _pick_shape(),
			"color": COLORS[randi() % COLORS.size()],
		})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# Air takes over after the first moment: paper slows fast and drifts.
	var settle := clampf(_time / 0.5, 0.0, 1.0)
	for p in _pieces:
		var v: Vector2 = p["vel"]
		v.y += GRAVITY * delta
		v.x -= v.x * 2.4 * delta
		if v.y < 0.0:
			v.y -= v.y * 1.4 * delta
		var fall: float = p["fall"]
		if v.y > fall:
			v.y = lerpf(v.y, fall, 1.0 - exp(-7.0 * delta))
		p["vel"] = v
		var sway: float = sin(_time * float(p["sway_speed"]) + float(p["sway"])) * float(p["sway_amp"]) * settle
		p["pos"] = (p["pos"] as Vector2) + v * delta + Vector2(sway * delta, 0)
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		p["flip"] = float(p["flip"]) + float(p["flip_speed"]) * delta
	queue_redraw()
	if _time >= LIFETIME:
		_pieces.clear()
		set_process(false)
		queue_redraw()
		finished.emit()


func _draw() -> void:
	var fade := clampf((LIFETIME - _time) / FADE_SECONDS, 0.0, 1.0)
	for p in _pieces:
		# Flipping: the piece squashes through edge-on, then shows its back.
		var facing := cos(float(p["flip"]))
		var color: Color = p["color"]
		if facing < 0.0:
			color = color.lerp(Color.WHITE, 0.45)
		color.a = fade
		var size: float = p["size"]
		draw_set_transform(p["pos"], p["rot"], Vector2(size, size * maxf(absf(facing), 0.12)))
		match p["shape"]:
			Shape.STRIP:
				draw_rect(Rect2(-8, -3, 16, 6), color)
			Shape.DOT:
				draw_circle(Vector2.ZERO, 4.5, color)
			Shape.STAR:
				draw_colored_polygon(_star, color)
			Shape.HEART:
				draw_colored_polygon(_heart, color)
			Shape.SPIRAL:
				draw_polyline(_spiral, color, 2.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pick_shape() -> Shape:
	var total := 0
	for w in SHAPE_WEIGHTS.values():
		total += int(w)
	var roll := randi() % total
	for shape in SHAPE_WEIGHTS:
		roll -= int(SHAPE_WEIGHTS[shape])
		if roll < 0:
			return shape
	return Shape.STRIP


static func _build_shapes() -> void:
	for k in 10:
		var a := -PI / 2.0 + TAU * float(k) / 10.0
		_star.append(Vector2.from_angle(a) * (8.0 if k % 2 == 0 else 3.4))
	for k in 24:
		var t := TAU * float(k) / 24.0
		# The classic heart curve, scaled to about 14 pixels across.
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		_heart.append(Vector2(x, y) * 0.45)
	for k in 22:
		var t := float(k) / 21.0
		_spiral.append(Vector2.from_angle(t * TAU * 1.8) * lerpf(1.0, 8.0, t))
