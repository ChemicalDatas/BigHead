class_name Rope
extends RefCounted
## A string as a chain of points (Verlet integration with distance constraints).
## The first point is always pinned; the last is pinned only when `end_pinned`.
## When the ends are closer than the rope's length it sags; when they're as far
## apart as it is long it pulls straight.

var points := PackedVector2Array()
var _previous := PackedVector2Array()
var segment_length := 10.0
var gravity := Vector2(0, 2200)
var end_pinned := true
## Points can't go below this (the floor); INF for none.
var floor_y := INF
const ITERATIONS := 12


func _init(start: Vector2, end: Vector2, length: float, count := 14) -> void:
	segment_length = length / float(count - 1)
	for i in count:
		var p := start.lerp(end, float(i) / float(count - 1))
		points.append(p)
		_previous.append(p)


func set_length(length: float) -> void:
	segment_length = length / float(points.size() - 1)


func end() -> Vector2:
	return points[points.size() - 1]


func step(delta: float, start: Vector2, end_target: Vector2) -> void:
	var n := points.size()
	var last := n - 1
	for i in range(1, n):
		if i == last and end_pinned:
			continue
		var p := points[i]
		var velocity := (p - _previous[i]) * 0.985
		_previous[i] = p
		points[i] = p + velocity + gravity * delta * delta
	points[0] = start
	_previous[0] = start
	if end_pinned:
		points[last] = end_target
		_previous[last] = end_target
	for _k in ITERATIONS:
		for i in range(1, n):
			if points[i].y > floor_y:
				points[i].y = floor_y
		for i in range(last):
			var a := points[i]
			var b := points[i + 1]
			var d := b - a
			var dist := d.length()
			if dist < 0.0001:
				continue
			var fix := d * ((dist - segment_length) / dist)
			var a_free := i != 0
			var b_free := not (i + 1 == last and end_pinned)
			if a_free and b_free:
				points[i] = a + fix * 0.5
				points[i + 1] = b - fix * 0.5
			elif a_free:
				points[i] = a + fix
			elif b_free:
				points[i + 1] = b - fix
