class_name BackgroundView
extends Control
## Full-screen background: one of the drawn presets, or the player's uploaded
## image scaled to cover the screen.

var style: SceneStyle = SceneStyle.new()
var image: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if style.use_background_image and image != null:
		_draw_cover(rect)
		return
	match style.background:
		0: _draw_night(rect)
		1: _draw_sunset(rect)
		2: _draw_spotlight(rect)
		3: _draw_office(rect)
		4: _draw_party(rect)


## Scale the image to cover the whole screen, cropping the overflow evenly.
func _draw_cover(rect: Rect2) -> void:
	var tex_size := image.get_size()
	var factor := maxf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var shown := rect.size / factor
	var src := Rect2((tex_size - shown) * 0.5, shown)
	draw_texture_rect_region(image, rect, src)


func _vertical_gradient(rect: Rect2, top_color: Color, bottom_color: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))


func _draw_night(rect: Rect2) -> void:
	_vertical_gradient(rect, Color("#140f22"), Color("#2b2142"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(90):
		var p := Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y * 0.7)
		draw_circle(p, rng.randf_range(0.8, 2.2), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	draw_circle(Vector2(rect.size.x * 0.85, rect.size.y * 0.16), 38, Color("#f4ecd0"))
	draw_circle(Vector2(rect.size.x * 0.85 + 14, rect.size.y * 0.16 - 8), 34, Color("#140f22"))


func _draw_sunset(rect: Rect2) -> void:
	var mid := rect.size.y * 0.62
	_vertical_gradient(Rect2(0, 0, rect.size.x, mid), Color("#3d2c6b"), Color("#ff8a5c"))
	draw_circle(Vector2(rect.size.x * 0.5, mid), 110, Color("#ffd27a"))
	_vertical_gradient(Rect2(0, mid, rect.size.x, rect.size.y - mid), Color("#5e3a6e"), Color("#2a1b3d"))


func _draw_spotlight(rect: Rect2) -> void:
	draw_rect(rect, Color("#121016"))
	var center := Vector2(rect.size.x * 0.5, rect.size.y * 0.55)
	for i in range(12, 0, -1):
		var t := float(i) / 12.0
		draw_circle(center, rect.size.y * 0.55 * t, Color(1, 0.95, 0.8, 0.035))
	draw_rect(Rect2(0, rect.size.y * 0.86, rect.size.x, rect.size.y * 0.14), Color("#1d1820"))


func _draw_office(rect: Rect2) -> void:
	draw_rect(rect, Color("#cfd8d4"))
	var floor_y := rect.size.y * 0.8
	draw_rect(Rect2(0, floor_y, rect.size.x, rect.size.y - floor_y), Color("#8a6d52"))
	draw_rect(Rect2(0, floor_y - 10, rect.size.x, 10), Color("#efe9e1"))
	var win := Rect2(rect.size.x * 0.08, rect.size.y * 0.12, rect.size.x * 0.22, rect.size.y * 0.36)
	draw_rect(win, Color("#9fd3f0"))
	draw_rect(win, Color("#f7f4ee"), false, 10.0)
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("#f7f4ee"), 6.0)
	draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color("#f7f4ee"), 6.0)
	# A motivational poster, naturally.
	var poster := Rect2(rect.size.x * 0.76, rect.size.y * 0.16, rect.size.x * 0.13, rect.size.y * 0.26)
	draw_rect(poster, Color("#2c3e50"))
	draw_circle(poster.get_center() + Vector2(0, -10), poster.size.x * 0.22, Color("#f1c40f"))


func _draw_party(rect: Rect2) -> void:
	_vertical_gradient(rect, Color("#4a1f6b"), Color("#22113a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var colors := [Color("#e74c3c"), Color("#f1c40f"), Color("#2ecc71"), Color("#3498db"), Color("#ff7eb6")]
	for i in range(140):
		var p := Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
		c.a = 0.55
		draw_rect(Rect2(p, Vector2(8, 8)), c)
	# Bunting across the top
	var flags := 14
	for i in range(flags):
		var x0 := rect.size.x * float(i) / flags
		var x1 := rect.size.x * float(i + 1) / flags
		var c: Color = colors[i % colors.size()]
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2((x0 + x1) * 0.5, 46)]), c)
