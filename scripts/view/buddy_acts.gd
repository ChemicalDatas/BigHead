class_name BuddyActs
extends Node2D
## Little idle acts the bobblehead puts on by itself after it's been left
## alone for a while: yawning, nodding off, feeding chickens, a shooting-star
## storm, playing a handheld game, typing on a laptop, a snack, stepping out
## a door and back, a rainstorm (umbrella or raincoat), blowing bubbles,
## reading, and, for goats, splitting in two (the twin hops off screen).
##
## The desktop buddy gets all of them. The full-game playground only gets the
## goat split (goat body only).
##
## Everything is drawn in the head's own space: this node copies the
## HeadView's position and scale every frame (the door act holds still while
## the figure walks off). Props in front of the figure draw here; props
## behind it (the doorway) draw on a second node placed just under the head.
## Any click, drag or firework interrupts an act (see interrupt()).

signal act_started(act: String)
signal act_finished(act: String)

## Seconds between acts: a random wait in this range, counted while the
## figure is left alone (any interaction starts the wait again).
const BUDDY_WAIT := Vector2(90.0, 240.0)
const PLAYGROUND_WAIT := Vector2(60.0, 150.0)

## Act name -> how long it lasts (seconds).
const LENGTH := {
	"yawn": 4.5, "sleep": 22.0, "chickens": 17.0, "star_storm": 9.0,
	"video_game": 14.0, "laptop": 14.0, "eating": 10.0, "door": 11.0,
	"rain": 16.0, "bubbles": 12.0, "reading": 14.0, "goat_split": 7.5,
}
const BUDDY_ACTS: Array[String] = [
	"yawn", "sleep", "chickens", "star_storm", "video_game", "laptop",
	"eating", "door", "rain", "bubbles", "reading",
]

const OUTLINE := Color("#2a1d17")
const FLOOR_Y := 231.0  ## the bottom of the stand, in head space

var head: HeadView
var buddy := true

var _back: Node2D
var _act := ""
var _t := 0.0
var _wait := 0.0
var _last := ""
var _rng := RandomNumberGenerator.new()
## Per-act state (cleared at the start of each act).
var _s := {}
## The door act: where the figure stands normally, and how far it has walked.
var _home := Vector2.ZERO
var _twin: HeadView = null


## Call once, after the HeadView is in the scene: puts this node just above
## the head and the back layer just under it.
func setup(view: HeadView, is_buddy: bool) -> void:
	head = view
	buddy = is_buddy
	_rng.randomize()
	var parent := head.get_parent()
	parent.add_child(self)
	parent.move_child(self, head.get_index() + 1)
	_back = Node2D.new()
	_back.name = "BuddyActsBack"
	parent.add_child(_back)
	parent.move_child(_back, head.get_index())
	_back.draw.connect(_draw_back)
	_restart_wait()


func busy() -> bool:
	return _act != ""


## Acts this figure can do here.
func available() -> Array[String]:
	var acts: Array[String] = []
	if buddy:
		acts.append_array(BUDDY_ACTS)
	if _is_goat() and not head.is_marionette() and not head.is_balloon():
		acts.append("goat_split")
	return acts


## Starts an act now (the "act" cheat, tests). Unknown names pick at random.
func start(act := "") -> void:
	var acts := available()
	if acts.is_empty():
		return
	if not acts.has(act):
		var choices: Array[String] = []
		for a in acts:
			if a != _last or acts.size() == 1:
				choices.append(a)
				if a == "goat_split":
					choices.append_array([a, a])  # goats love doing this
		act = choices[_rng.randi_range(0, choices.size() - 1)]
	if busy():
		_finish()
	_act = act
	_last = act
	_t = 0.0
	_s = {}
	_home = head.position
	_begin()
	print("[acts] %s" % act)
	act_started.emit(act)


## The player touched the figure (or launched fireworks): stop the act and
## start the wait over.
func interrupt() -> void:
	if busy():
		if _act == "sleep":
			head.bobble.pop(0.35)  # startled awake
		_finish()
	_restart_wait()


func _restart_wait() -> void:
	var range := BUDDY_WAIT if buddy else PLAYGROUND_WAIT
	_wait = _rng.randf_range(range.x, range.y) * Game.act_time_scale


func _is_goat() -> bool:
	return head.build.body_shape == BodyShapes.GOAT


func _process(delta: float) -> void:
	if head == null or not is_instance_valid(head):
		return
	if _act != "door":
		position = head.position
		scale = head.scale
	_back.position = position
	_back.scale = scale
	if not busy():
		if head.is_dragging():
			_restart_wait()
		else:
			_wait -= delta
			if _wait <= 0.0 and not available().is_empty():
				start()
		return
	_t += delta
	_update(delta)
	if _t >= float(LENGTH[_act]):
		_finish()
		_restart_wait()
	queue_redraw()
	_back.queue_redraw()


## 0 before t0, 1 after t1, eased in between.
func _k(t0: float, t1: float) -> float:
	return smoothstep(t0, t1, _t)


# --------------------------------------------------------------------------
# Start, run, finish
# --------------------------------------------------------------------------

func _begin() -> void:
	match _act:
		"chickens":
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var chickens: Array = []
			for i in 3:
				chickens.append({
					"x": _edge(side) + side * (40.0 + 70.0 * i),
					"spot": side * (150.0 + 55.0 * i) + _rng.randf_range(-15.0, 15.0),
					"y": FLOOR_Y + 6.0 + 8.0 * i,
					"face": -side, "phase": _rng.randf() * TAU, "peck": 0.0,
				})
			_s["chickens"] = chickens
			_s["side"] = side
			_s["seeds"] = []
			_s["next_toss"] = 2.5
		"star_storm":
			var stars: Array = []
			for i in 16:
				stars.append({"a": _rng.randf() * TAU, "speed": _rng.randf_range(2.2, 4.0) * (1.0 if i % 2 == 0 else -1.0),
					"rx": _rng.randf_range(190.0, 270.0), "ry": _rng.randf_range(120.0, 200.0), "size": _rng.randf_range(7.0, 13.0)})
			_s["stars"] = stars
		"rain":
			_s["umbrella"] = _has_hands() and _rng.randf() < 0.5
			var drops: Array = []
			for i in 70:
				drops.append({"x": _rng.randf_range(-260.0, 260.0), "y": _rng.randf_range(-420.0, FLOOR_Y), "v": _rng.randf_range(700.0, 900.0)})
			_s["drops"] = drops
			_s["splashes"] = []
		"bubbles":
			_s["bubbles"] = []
			_s["next_bubble"] = 1.2
		"door":
			# The door goes on the side with more room in the window.
			_s["side"] = 1.0 if _edge(1.0) >= -_edge(-1.0) else -1.0
		"eating":
			_s["crumbs"] = []
		"sleep":
			_s["z"] = []
			_s["next_z"] = 1.5
		"goat_split":
			var dir := 1.0 if _edge(1.0) <= -_edge(-1.0) else -1.0  # toward the nearer edge
			_s["dir"] = dir


func _update(delta: float) -> void:
	match _act:
		"yawn":
			head.expression = "yawn" if _t > 0.5 and _t < 3.4 else ""
			head.bobble.rest_angle = 0.0
			head.bobble.rest_offset = Vector2(0, -10.0) * (_k(0.3, 1.0) - _k(3.2, 4.0))
			if _t > 0.4 and _t < 3.3:
				head.reach_hands_to([Vector2(120, -30), Vector2(-120, -30)])
			else:
				head.reach_hands_to([])
		"sleep":
			var droop := _k(0.5, 3.0) * (1.0 - _k(LENGTH["sleep"] - 1.5, LENGTH["sleep"] - 0.5))
			head.expression = "sleep" if droop > 0.3 else ""
			head.bobble.rest_angle = 0.22 * droop
			head.bobble.rest_offset = Vector2(4.0, 10.0 + 3.0 * sin(_t * 1.6)) * droop
			if droop > 0.5:
				_s["next_z"] -= delta
				if _s["next_z"] <= 0.0:
					_s["next_z"] = 1.1
					(_s["z"] as Array).append({"t": _t, "size": _rng.randf_range(20.0, 30.0)})
		"chickens":
			_update_chickens(delta)
		"star_storm":
			head.use_gaze_override = true
			head.gaze_override = Vector2.from_angle(_t * 3.0)
			if _t > LENGTH["star_storm"] - 2.2 and not _s.has("dizzy"):
				_s["dizzy"] = true
				head.show_dizzy_stars(2.0)
		"video_game", "laptop", "reading":
			head.use_gaze_override = true
			head.gaze_override = Vector2(0.1 * sin(_t * 0.7), 0.85)
			var y := 128.0 if _act == "laptop" else 112.0
			var jiggle := 0.0
			if _act != "reading":
				jiggle = 4.0 * sin(_t * (22.0 if _act == "laptop" else 9.0))
			if _t < float(LENGTH[_act]) - 0.8:
				head.reach_hands_to([Vector2(30, y + jiggle), Vector2(-30, y - jiggle)])
			else:
				head.reach_hands_to([])
		"eating":
			var bite_time := fmod(_t - 1.0, 2.0)
			head.expression = "chomp" if _t > 1.0 and _t < 8.5 and bite_time < 0.9 else ""
			if _t < 8.6:
				head.reach_hands_to([head.head_point(Vector2(head.radius() * 0.35, head.radius() * 0.75)), Vector2(-40, 150)])
			else:
				head.reach_hands_to([])
			if head.expression == "chomp" and _rng.randf() < delta * 6.0:
				(_s["crumbs"] as Array).append({"p": _food_point() + Vector2(_rng.randf_range(-12, 12), 6), "v": Vector2(_rng.randf_range(-40, 40), -30)})
			for c in _s["crumbs"]:
				c["v"].y += 900.0 * delta
				c["p"] += c["v"] * delta
				c["p"].y = minf(c["p"].y, FLOOR_Y)
		"door":
			_update_door()
		"rain":
			_update_rain(delta)
		"bubbles":
			_update_bubbles(delta)
		"goat_split":
			_update_goat_split(delta)


## Puts the figure back exactly as it was.
func _finish() -> void:
	var act := _act
	_act = ""
	head.expression = ""
	head.use_gaze_override = false
	head.reach_hands_to([])
	head.bobble.rest_angle = 0.0
	head.bobble.rest_offset = Vector2.ZERO
	head.modulate = Color.WHITE
	if act == "door":
		head.position = _home
	if is_instance_valid(_twin):
		_twin.queue_free()
	_twin = null
	_s = {}
	queue_redraw()
	_back.queue_redraw()
	act_finished.emit(act)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

## The window's left (side -1) or right (side 1) edge, in head space.
func _edge(side: float) -> float:
	var view := get_viewport_rect().size
	var global_x := view.x if side > 0.0 else 0.0
	return (global_x - head.position.x) / maxf(head.scale.x, 0.01)


func _has_hands() -> bool:
	return not BodyShapes.is_animal(head.build.body_shape) and not head.is_marionette()


## Where the snack is: in the right hand, or under an animal's muzzle.
func _food_point() -> Vector2:
	if _has_hands():
		return head.hand_positions()[0] + Vector2(-6, -10)
	return head.head_point(Vector2(0, head.radius() * 0.85))


func _hands() -> Array[Vector2]:
	return head.hand_positions()


func _draw_hands() -> void:
	if not _has_hands():
		return
	for h in _hands():
		draw_circle(h, BodyShapes.HAND_RADIUS, head.build.skin_color())
		draw_arc(h, BodyShapes.HAND_RADIUS, 0, TAU, 20, OUTLINE, 3.0, true)


func _text(at: Vector2, text: String, size: int, color: Color, canvas: CanvasItem = self) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-width * 0.5, size * 0.35)
	var outline := OUTLINE
	outline.a = color.a
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(3, size / 7), outline)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _star(at: Vector2, size: float, color: Color, spin := 0.0) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(at + Vector2.from_angle(-PI / 2.0 + TAU * k / 10.0 + spin) * (size if k % 2 == 0 else size * 0.45))
	draw_colored_polygon(pts, color)
	var outline := OUTLINE
	outline.a = color.a
	pts.append(pts[0])
	draw_polyline(pts, outline, 2.0, true)


func _rounded_box(rect: Rect2, fill: Color, line := 3.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.22))
	box.border_color = OUTLINE
	box.set_border_width_all(int(line))
	box.anti_aliasing = true
	draw_style_box(box, rect)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	match _act:
		"yawn": _draw_yawn()
		"sleep": _draw_sleep()
		"chickens": _draw_chickens()
		"star_storm": _draw_star_storm()
		"video_game": _draw_video_game()
		"laptop": _draw_laptop()
		"eating": _draw_eating()
		"rain": _draw_rain()
		"bubbles": _draw_bubbles()
		"reading": _draw_reading()
		"goat_split": _draw_goat_split()


func _draw_back() -> void:
	if _act == "door":
		_draw_door()


func _draw_yawn() -> void:
	var a := _k(0.6, 1.2) * (1.0 - _k(3.0, 3.6))
	if a > 0.0:
		var top := head.head_point(Vector2(head.radius() * 0.9, -head.radius() * 0.9))
		_text(top + Vector2(0, -10.0 * _t), "yaaawn", 28, Color(1, 1, 1, a))


func _draw_sleep() -> void:
	for z in _s.get("z", []):
		var age := _t - float(z["t"])
		if age > 4.0:
			continue
		var start := head.head_point(Vector2(head.radius() * 0.7, -head.radius() * 0.7))
		var p := start + Vector2(30.0 * age + 10.0 * sin(age * 3.0), -45.0 * age)
		var a := clampf(minf(age / 0.4, (4.0 - age) / 1.0), 0.0, 1.0)
		_text(p, "Z", int(float(z["size"]) * (0.8 + age * 0.25)), Color(0.85, 0.9, 1.0, a))


# Chickens ----------------------------------------------------------------

func _update_chickens(delta: float) -> void:
	var leaving := _t > LENGTH["chickens"] - 4.0
	var side: float = _s["side"]
	for c in _s["chickens"]:
		var target: float = c["spot"] if not leaving else _edge(-side) - side * 80.0
		var dx := target - float(c["x"])
		if absf(dx) > 3.0:
			c["face"] = signf(dx)
			c["x"] = float(c["x"]) + signf(dx) * minf(absf(dx), 120.0 * delta)
			c["phase"] = float(c["phase"]) + delta * 14.0
			c["peck"] = 0.0
		else:
			# Peck, peck: the head dips now and then.
			c["peck"] = maxf(0.0, sin(_t * 7.0 + float(c["phase"])))
	if not leaving and _t > 2.0:
		_s["next_toss"] = float(_s["next_toss"]) - delta
		if _s["next_toss"] <= 0.0:
			_s["next_toss"] = 1.6
			var hand := 0 if side > 0.0 else 1
			_s["hand"] = hand
			_s["toss_at"] = _t
			for i in 5:
				(_s["seeds"] as Array).append({"t": _t, "to": side * _rng.randf_range(120.0, 300.0), "dy": _rng.randf_range(0.0, 20.0)})
	# The tossing arm swings out and back.
	var swing := 0.0
	if _s.has("toss_at"):
		swing = maxf(0.0, 1.0 - (_t - float(_s["toss_at"])) / 0.6)
	if _has_hands() and not leaving:
		var targets := [Vector2(70, 150), Vector2(-70, 150)]
		if swing > 0.0:
			targets[int(_s.get("hand", 0))] = Vector2(side * 150.0, 60.0)
		head.reach_hands_to(targets)
	else:
		head.reach_hands_to([])
	head.use_gaze_override = true
	head.gaze_override = Vector2(side * 0.8, 0.6)


func _draw_chickens() -> void:
	for seed in _s.get("seeds", []):
		var age := _t - float(seed["t"])
		if age > 3.0:
			continue
		var from := _hands()[int(_s.get("hand", 0))] if _has_hands() else Vector2(0, 100)
		var to := Vector2(float(seed["to"]), FLOOR_Y + float(seed["dy"]))
		var k := clampf(age / 0.7, 0.0, 1.0)
		var p := from.lerp(to, k) + Vector2(0, -90.0 * sin(k * PI))
		draw_circle(p, 3.0, Color("#e8c25a"))
	for c in _s.get("chickens", []):
		_chicken(Vector2(c["x"], c["y"]), c["face"], c["peck"], c["phase"])


func _chicken(at: Vector2, face: float, peck: float, phase: float) -> void:
	var body_c := at + Vector2(0, -24)
	# Legs
	for i in 2:
		var swing := sin(phase + PI * i) * 5.0
		draw_line(body_c + Vector2(-4 + 8 * i, 10), at + Vector2(-4 + 8 * i + swing, 0), Color("#e39b2d"), 3.0, true)
	# Tail
	var tail := PackedVector2Array([body_c + Vector2(-face * 14, -2), body_c + Vector2(-face * 30, -16), body_c + Vector2(-face * 24, 4)])
	draw_colored_polygon(tail, Color.WHITE)
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2], tail[0]]), OUTLINE, 2.5, true)
	var body := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		body.append(body_c + Vector2(cos(a) * 21.0, sin(a) * 15.0))
	draw_colored_polygon(body, Color.WHITE)
	body.append(body[0])
	draw_polyline(body, OUTLINE, 2.5, true)
	draw_arc(body_c + Vector2(-face * 3, 0), 9, 0.2, PI - 0.2, 8, Color("#d8d2c4"), 3.0, true)  # wing
	var head_c := body_c + Vector2(face * 17, -15 + peck * 18)
	var comb := head_c + Vector2(0, -9)
	draw_circle(comb + Vector2(-3, 0), 4, Color("#e0453a"))
	draw_circle(comb + Vector2(3, -1), 4, Color("#e0453a"))
	draw_circle(head_c, 9, Color.WHITE)
	draw_arc(head_c, 9, 0, TAU, 16, OUTLINE, 2.5, true)
	var beak := PackedVector2Array([head_c + Vector2(face * 7, -2), head_c + Vector2(face * 16, 1), head_c + Vector2(face * 7, 4)])
	draw_colored_polygon(beak, Color("#f2a531"))
	draw_circle(head_c + Vector2(face * 3, -2), 1.8, OUTLINE)


# Shooting-star storm ---------------------------------------------------------

func _draw_star_storm() -> void:
	var fade := _k(0.0, 0.8) * (1.0 - _k(LENGTH["star_storm"] - 1.0, LENGTH["star_storm"]))
	var center := Vector2(0, -60)
	for st in _s.get("stars", []):
		var a: float = float(st["a"]) + _t * float(st["speed"])
		var rx: float = st["rx"]
		var ry: float = st["ry"]
		# A comet: the star and a fading tail along its orbit.
		var trail := PackedVector2Array()
		for k in 8:
			var back := a - float(st["speed"]) * 0.035 * k
			trail.append(center + Vector2(cos(back) * rx, sin(back) * ry))
		for k in 7:
			var c := Color(1.0, 0.92, 0.6, fade * (1.0 - k / 7.0) * 0.8)
			draw_line(trail[k], trail[k + 1], c, float(st["size"]) * (1.0 - k / 8.0), true)
		var near := sin(a) > 0.0  # the near half of the ring is brighter
		_star(trail[0], float(st["size"]) * (1.2 if near else 0.85), Color(1.0, 0.9, 0.35, fade), _t * 4.0)


# Handheld game, laptop, book -----------------------------------------------------

func _draw_video_game() -> void:
	var c := Vector2(0, 116)
	var body := Rect2(c - Vector2(46, 26), Vector2(92, 52))
	_rounded_box(body, Color("#7b5cd6"))
	var screen := Rect2(c - Vector2(24, 18), Vector2(48, 34))
	draw_rect(screen, Color("#a8e6a1"))
	# A tiny game: a ball bouncing over a paddle.
	var bx := screen.position.x + 6 + absf(fmod(_t * 40.0, 72.0) - 36.0)
	var by := screen.position.y + 4 + absf(fmod(_t * 31.0, 44.0) - 22.0)
	draw_rect(Rect2(bx, by, 4, 4), Color("#1e3d1a"))
	draw_rect(Rect2(clampf(bx - 6.0, screen.position.x, screen.end.x - 14.0), screen.end.y - 4, 14, 3), Color("#1e3d1a"))
	draw_rect(screen, OUTLINE, false, 2.0)
	draw_circle(c + Vector2(-34, 0), 6, Color("#3a2d6b"))  # d-pad
	draw_circle(c + Vector2(34, -6), 4, Color("#e0453a"))
	draw_circle(c + Vector2(38, 4), 4, Color("#f2c037"))
	_draw_hands()
	if fmod(_t, 3.0) < 0.6 and _t > 1.0:
		_text(c + Vector2(60, -60 - fmod(_t, 3.0) * 40.0), "♪", 30, Color(1, 1, 0.7, 1.0 - fmod(_t, 3.0) / 0.6))


func _draw_laptop() -> void:
	var c := Vector2(0, 136)
	# The lid faces the bobblehead: we see its back, and the screen's glow.
	var glow := Color(0.6, 0.85, 1.0, 0.18 + 0.05 * sin(_t * 9.0))
	draw_circle(c + Vector2(0, -60), 90, glow)
	var lid := PackedVector2Array([c + Vector2(-62, -6), c + Vector2(62, -6), c + Vector2(56, -78), c + Vector2(-56, -78)])
	draw_colored_polygon(lid, Color("#b7bcc6"))
	lid.append(lid[0])
	draw_polyline(lid, OUTLINE, 3.0, true)
	draw_circle(c + Vector2(0, -42), 9, Color("#e6e9ee"))  # logo
	draw_arc(c + Vector2(0, -42), 9, 0, TAU, 16, OUTLINE, 2.0, true)
	_rounded_box(Rect2(c + Vector2(-70, -8), Vector2(140, 14)), Color("#9aa0ab"), 3.0)
	_draw_hands()
	# Clicky keys.
	if fmod(_t * 5.0, 1.0) < 0.5:
		_text(c + Vector2(80 * (1.0 if fmod(_t, 2.0) < 1.0 else -1.0), -24), "tap", 16, Color(1, 1, 1, 0.8))


func _draw_reading() -> void:
	var c := Vector2(0, 108)
	var cover := Color("#c0392b")
	var book := PackedVector2Array([c + Vector2(-64, -30), c + Vector2(0, -24), c + Vector2(64, -30), c + Vector2(64, 24), c + Vector2(0, 30), c + Vector2(-64, 24)])
	draw_colored_polygon(book, cover)
	for side in [-1.0, 1.0]:
		var page := PackedVector2Array([c + Vector2(0, -20), c + Vector2(side * 58, -26), c + Vector2(side * 58, 18), c + Vector2(0, 24)])
		draw_colored_polygon(page, Color("#fbf6e9"))
		for line in 4:
			var y := -14.0 + line * 9.0
			draw_line(c + Vector2(side * 10, y), c + Vector2(side * 48, y - 4), Color("#c8bfae"), 2.0)
	# A page turning every few seconds.
	var turn := fmod(_t, 3.5) / 0.7
	if turn < 1.0:
		var x := lerpf(58.0, -58.0, turn)
		var page := PackedVector2Array([c + Vector2(0, -20), c + Vector2(x, -26 - 14.0 * sin(turn * PI)), c + Vector2(x, 18 - 14.0 * sin(turn * PI)), c + Vector2(0, 24)])
		draw_colored_polygon(page, Color("#fffdf5"))
		page.append(page[0])
		draw_polyline(page, Color("#c8bfae"), 1.5, true)
	book.append(book[0])
	draw_polyline(book, OUTLINE, 3.0, true)
	draw_line(c + Vector2(0, -24), c + Vector2(0, 30), OUTLINE, 2.0)
	_draw_hands()


# Eating ----------------------------------------------------------------

func _draw_eating() -> void:
	if _t > 8.8:
		return
	var bites := clampi(int((_t - 1.0) / 2.0), 0, 4)
	var at := _food_point()
	var width := 56.0 * (1.0 - bites * 0.2)
	if width > 4.0:
		# A sandwich, smaller after every bite.
		var r := Rect2(at - Vector2(width * 0.5, 14), Vector2(width, 28))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color("#e8b96a"))
		draw_rect(Rect2(r.position + Vector2(0, 8), Vector2(r.size.x, 5)), Color("#6fbf4b"))
		draw_rect(Rect2(r.position + Vector2(0, 13), Vector2(r.size.x, 5)), Color("#d9534f"))
		draw_rect(Rect2(r.position + Vector2(0, 18), Vector2(r.size.x, 10)), Color("#e8b96a"))
		draw_rect(r, OUTLINE, false, 2.5)
	for crumb in _s.get("crumbs", []):
		draw_circle(crumb["p"], 2.5, Color("#d7a85a"))
	if _has_hands():
		var h := _hands()[0]
		draw_circle(h, BodyShapes.HAND_RADIUS, head.build.skin_color())
		draw_arc(h, BodyShapes.HAND_RADIUS, 0, TAU, 20, OUTLINE, 3.0, true)
	if bites >= 4 and _t < 8.6:
		_text(head.head_point(Vector2(head.radius() * 0.9, -head.radius() * 0.6)), "yum!", 28, Color("#ffe066"))


# Door ----------------------------------------------------------------

func _door_x() -> float:
	return float(_s.get("side", 1.0)) * 280.0


## 0 = closed, 1 = wide open.
func _door_open() -> float:
	return _k(1.0, 1.6) * (1.0 - _k(4.3, 4.9)) + _k(6.8, 7.3) * (1.0 - _k(9.6, 10.1))


func _update_door() -> void:
	position = _home
	var side: float = _s["side"]
	# Out: hop to the door (1.6-3.6 s), through it (3.6-4.3). Back: 7.3-9.6 s.
	var out := _k(1.6, 3.6)
	var back := _k(7.3, 9.3)
	var along := out * (1.0 - back)
	var hop := absf(sin(clampf((_t - 1.6) / 2.0, 0.0, 1.0) * PI * 4.0)) if _t < 3.6 else absf(sin(clampf((_t - 7.3) / 2.0, 0.0, 1.0) * PI * 4.0))
	if _t > 9.3 or (_t > 3.6 and _t < 7.3):
		hop = 0.0
	head.position = _home + Vector2(_door_x() * 0.9 * along, -30.0 * hop) * head.scale
	var gone := _k(3.6, 4.3) * (1.0 - _k(6.9, 7.4))
	head.modulate = Color(1, 1, 1, 1.0 - gone)
	if hop > 0.95 and not _s.get("hopped", false):
		head.bobble.nudge_toward(Vector2(side, -1.0), 0.5)
		_s["hopped"] = true
	elif hop < 0.5:
		_s["hopped"] = false


func _draw_door() -> void:
	var grow := _k(0.0, 0.8) * (1.0 - _k(10.2, 11.0))
	if grow <= 0.0:
		return
	var x := _door_x()
	var w := 130.0
	var h := 270.0 * grow
	var frame := Rect2(x - w * 0.5, FLOOR_Y - h, w, h)
	var canvas := _back
	canvas.draw_rect(frame.grow(10.0), Color("#8a5a32"))
	canvas.draw_rect(frame.grow(10.0), OUTLINE, false, 3.0)
	canvas.draw_rect(frame, Color("#1d1530"))  # the dark room behind
	# The door swings open toward us: its outer edge moves across.
	var open := _door_open()
	var hinge := frame.position.x if _s["side"] > 0.0 else frame.end.x
	var dir := 1.0 if _s["side"] > 0.0 else -1.0
	var edge := hinge + dir * w * cos(open * PI * 0.45)
	var bulge := 18.0 * sin(open * PI * 0.45)
	var panel := PackedVector2Array([Vector2(hinge, frame.position.y), Vector2(edge, frame.position.y - bulge), Vector2(edge, frame.end.y + bulge * 0.3), Vector2(hinge, frame.end.y)])
	canvas.draw_colored_polygon(panel, Color("#c98b4b"))
	panel.append(panel[0])
	canvas.draw_polyline(panel, OUTLINE, 3.0, true)
	if absf(edge - hinge) > 20.0:
		canvas.draw_circle(Vector2(lerpf(hinge, edge, 0.85), frame.position.y + h * 0.55), 6.0, Color("#f2c037"))
	if _t > 4.9 and _t < 6.8:
		_text(Vector2(x, FLOOR_Y - h - 40.0), ". " .repeat(1 + int(_t * 2.0) % 3).strip_edges(), 34, Color.WHITE, canvas)


# Rain ----------------------------------------------------------------

func _cloud_y() -> float:
	return -head.radius() * 2.9 - 30.0


func _update_rain(delta: float) -> void:
	var raining := _t > 1.5 and _t < LENGTH["rain"] - 2.0
	for d in _s["drops"]:
		d["y"] = float(d["y"]) + float(d["v"]) * delta
		var stop := FLOOR_Y + 10.0
		if _s["umbrella"] and absf(float(d["x"]) - _umbrella_top().x) < _umbrella_radius():
			stop = _umbrella_top().y
		if float(d["y"]) > stop:
			if raining:
				(_s["splashes"] as Array).append({"p": Vector2(d["x"], stop), "t": _t})
			d["y"] = _cloud_y() + _rng.randf_range(0.0, 40.0)
			d["x"] = _rng.randf_range(-260.0, 260.0)
	var splashes: Array = _s["splashes"]
	while not splashes.is_empty() and _t - float(splashes[0]["t"]) > 0.3:
		splashes.pop_front()
	if _s["umbrella"]:
		head.reach_hands_to([Vector2(170, -10) if _t < LENGTH["rain"] - 1.5 else Vector2(65, 151), Vector2(-65, 151)])
	head.use_gaze_override = true
	head.gaze_override = Vector2(0.2 * sin(_t), -0.8)


func _draw_rain() -> void:
	var fade := _k(0.0, 1.5) * (1.0 - _k(LENGTH["rain"] - 2.0, LENGTH["rain"]))
	var raining := _t > 1.5 and _t < LENGTH["rain"] - 2.0
	if raining:
		for d in _s["drops"]:
			var p := Vector2(d["x"], d["y"])
			if p.y > _cloud_y() + 20.0:
				draw_line(p, p + Vector2(-3, 16), Color(0.7, 0.82, 1.0, 0.75), 2.5, true)
		for sp in _s["splashes"]:
			var age := (_t - float(sp["t"])) / 0.3
			draw_arc(sp["p"], 4.0 + 8.0 * age, PI, TAU, 8, Color(0.75, 0.85, 1.0, 1.0 - age), 2.0, true)
	# The storm cloud
	var cy := _cloud_y()
	var gray := Color(0.42, 0.45, 0.52, 0.95 * fade)
	for puff in [Vector2(-120, 10), Vector2(-60, -20), Vector2(10, -32), Vector2(80, -14), Vector2(135, 12), Vector2(0, 18)]:
		draw_circle(Vector2(puff.x, cy + puff.y), 58.0 * fade, gray)
	if raining and fmod(_t, 4.0) < 0.12:
		var bolt := PackedVector2Array([Vector2(60, cy + 50), Vector2(40, cy + 110), Vector2(70, cy + 110), Vector2(45, cy + 180)])
		draw_polyline(bolt, Color(1.0, 0.95, 0.5), 6.0, true)
	# Puddle
	if fade > 0.05:
		draw_colored_polygon(_ellipse(Vector2(0, FLOOR_Y + 8), 210.0 * fade, 16.0 * fade), Color(0.45, 0.6, 0.85, 0.45 * fade))
	if _s["umbrella"]:
		_draw_umbrella(fade)
	else:
		_draw_raincoat(fade)



## The umbrella is held out to the side, its canopy over the head.
func _umbrella_top() -> Vector2:
	return Vector2(_hands()[0].x * 0.45, _cloud_y() + 110.0)


func _umbrella_radius() -> float:
	return head.radius() * 1.55


func _draw_umbrella(fade: float) -> void:
	if fade < 0.05:
		return
	var hand := _hands()[0]
	var top := _umbrella_top()
	var r := _umbrella_radius() * fade
	var shaft_top := Vector2(hand.x, top.y - r * 0.3)
	draw_line(hand, shaft_top, OUTLINE, 5.0, true)
	draw_line(hand, shaft_top, Color("#5a4a3a"), 3.0, true)
	draw_arc(hand + Vector2(-8, 4), 8, 0, PI, 8, OUTLINE, 4.0, true)
	var canopy := PackedVector2Array()
	for k in 25:
		var a := PI + PI * k / 24.0
		canopy.append(top + Vector2(cos(a) * r, sin(a) * r * 0.55))
	# Scalloped bottom edge
	for k in 6:
		var x0 := r - 2.0 * r * k / 6.0
		var x1 := r - 2.0 * r * (k + 1) / 6.0
		canopy.append(top + Vector2((x0 + x1) * 0.5, -r * 0.08))
		if k < 5:  # the last point is where the arc started
			canopy.append(top + Vector2(x1, 0))
	draw_colored_polygon(canopy, Color(0.9, 0.25, 0.35, fade))
	canopy.append(canopy[0])
	draw_polyline(canopy, Color(OUTLINE, fade), 3.0, true)
	for k in 3:
		var x := -r * 0.5 + r * 0.5 * k
		draw_line(top + Vector2(0, -r * 0.55), top + Vector2(x, 0), Color(0.7, 0.15, 0.25, fade), 2.0, true)
	draw_circle(hand, BodyShapes.HAND_RADIUS, head.build.skin_color())
	draw_arc(hand, BodyShapes.HAND_RADIUS, 0, TAU, 20, OUTLINE, 3.0, true)


func _draw_raincoat(fade: float) -> void:
	if fade < 0.05:
		return
	var yellow := Color(1.0, 0.82, 0.15, fade)
	var coat := PackedVector2Array()
	for p in BodyShapes.outline(head.build.body_shape):
		coat.append(Vector2(p.x * 1.04, p.y))
	draw_colored_polygon(coat, yellow)
	coat.append(coat[0])
	draw_polyline(coat, Color(OUTLINE, fade), 3.0, true)
	for y in [70.0, 100.0, 130.0]:
		draw_circle(Vector2(6, y), 4.0, Color(0.55, 0.4, 0.1, fade))
	# The hood: a thick band over the top of the head, following it.
	var r := head.radius()
	var hood := PackedVector2Array()
	for k in 21:
		var a := PI * 1.05 + PI * 0.9 * k / 20.0
		hood.append(head.head_point(Vector2(cos(a), sin(a)) * r * 1.12))
	for k in 21:
		var a := PI * 1.95 - PI * 0.9 * k / 20.0
		hood.append(head.head_point(Vector2(cos(a), sin(a)) * r * 0.86))
	draw_colored_polygon(hood, yellow)
	hood.append(hood[0])
	draw_polyline(hood, Color(OUTLINE, fade), 3.0, true)


# Bubbles ----------------------------------------------------------------

func _update_bubbles(delta: float) -> void:
	var blowing := _t > 1.0 and _t < LENGTH["bubbles"] - 3.0
	if _has_hands():
		head.reach_hands_to([head.head_point(Vector2(head.radius() * 0.5, head.radius() * 0.6)) if _t < LENGTH["bubbles"] - 2.5 else Vector2(65, 151), Vector2(-65, 151)])
	head.expression = "chomp" if blowing and fmod(_t, 1.4) < 0.3 else ""
	if blowing:
		_s["next_bubble"] = float(_s["next_bubble"]) - delta
		if _s["next_bubble"] <= 0.0:
			_s["next_bubble"] = _rng.randf_range(0.15, 0.4)
			(_s["bubbles"] as Array).append({"p": _wand_tip(), "v": Vector2(_rng.randf_range(50, 140), _rng.randf_range(-90, -30)),
				"r": _rng.randf_range(8, 22), "life": _rng.randf_range(2.0, 4.0), "age": 0.0, "hue": _rng.randf()})
	for b in _s["bubbles"]:
		b["age"] = float(b["age"]) + delta
		b["p"] += b["v"] * delta + Vector2(sin(float(b["age"]) * 3.0 + float(b["hue"]) * 9.0) * 20.0 * delta, 0)
		b["v"] *= 1.0 - 0.4 * delta


func _wand_tip() -> Vector2:
	if _has_hands():
		return _hands()[0] + Vector2(18, -26)
	return head.head_point(Vector2(head.radius() * 0.6, head.radius() * 0.6))


func _draw_bubbles() -> void:
	for b in _s.get("bubbles", []):
		var age: float = b["age"]
		if age > float(b["life"]):
			if age < float(b["life"]) + 0.15:
				for k in 6:  # pop!
					var d := Vector2.from_angle(TAU * k / 6.0)
					draw_line(b["p"] + d * float(b["r"]), b["p"] + d * float(b["r"]) * 1.5, Color(1, 1, 1, 0.8), 2.0, true)
			continue
		var tint := Color.from_hsv(fmod(float(b["hue"]) + age * 0.2, 1.0), 0.35, 1.0, 0.85)
		draw_circle(b["p"], float(b["r"]), Color(tint, 0.12))
		draw_arc(b["p"], float(b["r"]), 0, TAU, 24, tint, 2.0, true)
		draw_arc(b["p"], float(b["r"]) * 0.7, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.9), 2.5, true)
	if _t < LENGTH["bubbles"] - 2.5:
		var tip := _wand_tip()
		var hold := _hands()[0] if _has_hands() else tip + Vector2(-10, 30)
		draw_line(hold, tip, Color("#3d8bd9"), 4.0, true)
		draw_arc(tip, 9, 0, TAU, 16, Color("#3d8bd9"), 3.5, true)
		_draw_hands()


# Goat split ----------------------------------------------------------------

func _update_goat_split(delta: float) -> void:
	var dir: float = _s["dir"]
	if _t < 0.8:
		# A shiver before the split.
		head.bobble.offset_velocity.x += sin(_t * 60.0) * 900.0 * delta
		return
	if _twin == null:
		_twin = HeadView.new()
		_twin.base_radius = head.base_radius
		_twin.build = head.build
		_twin.body_texture = head.body_texture
		_twin.show_stand = false
		_twin.interactive = false
		_twin.look_at_cursor = false
		_twin.use_gaze_override = true
		_twin.gaze_override = Vector2(-dir, 0.0)
		_twin.size_boost = head.size_boost
		var parent := head.get_parent()
		parent.add_child(_twin)
		parent.move_child(_twin, head.get_index())  # just behind the original
		_s["x"] = 0.0
		_s["y"] = 0.0
		_s["vy"] = 0.0
		_s["air"] = false
		_s["hops"] = 0
	var x: float = _s["x"]
	var y: float = _s["y"]
	if _t < 1.6:
		# Sliding out of the original, sideways.
		x = 150.0 * smoothstep(0.8, 1.6, _t) * dir
	elif _t < 2.1:
		# A look back ("bye!"), then off it goes.
		_twin.gaze_override = Vector2(-dir, -0.2)
		head.use_gaze_override = true
		head.gaze_override = Vector2(dir, 0.0)
	else:
		_twin.gaze_override = Vector2(dir, -0.3)
		var floor := 52.0  # off the stand, down to the floor
		if not bool(_s["air"]):
			_s["vy"] = -620.0
			_s["air"] = true
			_s["hops"] = int(_s["hops"]) + 1
		_s["vy"] = float(_s["vy"]) + 1800.0 * delta
		y += float(_s["vy"]) * delta
		x += dir * 330.0 * delta
		var ground := floor if absf(x) > 150.0 else 0.0
		if y >= ground and float(_s["vy"]) > 0.0:
			y = ground
			_s["air"] = false
			_twin.bobble.nudge_toward(Vector2(0, 1), 0.8)
	_s["x"] = x
	_s["y"] = y
	_twin.position = head.position + Vector2(x, y) * head.scale
	_twin.scale = head.scale
	if absf(x) * head.scale.x > get_viewport_rect().size.x:
		_twin.visible = false


func _draw_goat_split() -> void:
	if _t > 1.6 and _t < 2.3 and is_instance_valid(_twin):
		var p := Vector2(float(_s["x"]), 0) + head.head_point(Vector2(0, -head.radius() * 1.3))
		_text(p, "bye!", 30, Color("#ffe066"))


static func _ellipse(center: Vector2, rx: float, ry: float, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
