class_name Sparkles
extends Node2D
## Twinkling four-point stars scattered over an area for a few seconds: the
## gold glint of a rare item (or every colour, for an ultra rare).

var area := Rect2(-60, -40, 120, 80)
var seconds := 1.8
var rainbow := false
var count := 14

var _stars: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	z_index = 20
	for i in count:
		_stars.append({
			"pos": area.position + Vector2(randf() * area.size.x, randf() * area.size.y),
			"size": randf_range(7.0, 15.0),
			"delay": randf() * seconds * 0.6,
			"hue": randf(),
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= seconds:
		queue_free()


func _draw() -> void:
	for s in _stars:
		var t: float = (_time - float(s["delay"])) / 0.55
		if t < 0.0 or t > 1.0:
			continue
		var grow := sin(t * PI)
		var size: float = float(s["size"]) * grow
		var color := Color.from_hsv(fmod(float(s["hue"]) + _time * 0.6, 1.0), 0.75, 1.0) if rainbow else Color("#ffd84a")
		var p: Vector2 = s["pos"]
		var star := PackedVector2Array([
			p + Vector2(0, -size), p + Vector2(size * 0.22, -size * 0.22), p + Vector2(size, 0), p + Vector2(size * 0.22, size * 0.22),
			p + Vector2(0, size), p + Vector2(-size * 0.22, size * 0.22), p + Vector2(-size, 0), p + Vector2(-size * 0.22, -size * 0.22),
		])
		draw_colored_polygon(star, color)
		draw_circle(p, size * 0.18, Color.WHITE)
