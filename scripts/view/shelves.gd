class_name Shelves
extends Node2D
## Friends' bobbleheads on shelves, drawn over whichever background is chosen.
##
## Filling order: a shelf high on the left wall, one on the right wall, then
## a five-shelf bookcase under the right one, then one under the left. Six
## friends per shelf, so 72 at most; friends beyond that aren't added.
##
## Each friend is a small HeadView: their Steam avatar as the face, on a look
## picked from their Steam ID (FriendLooks). Clicking one makes it wobble;
## hovering shows the friend's name. The main bobblehead's clicks aren't
## affected: a click only counts here if it lands on a friend's head.

const PER_SHELF := 6
const BOOKCASE_SHELVES := 5
const CAPACITY := PER_SHELF * 2 + PER_SHELF * BOOKCASE_SHELVES * 2
const FIGURE_SCALE := 0.13
const FIGURE_RADIUS := 125.0
const SHELF_WIDTH := 252.0
const MARGIN := 22.0
const WALL_SHELF_Y := 205.0     ## top of the wall shelves' planks
const BOOKCASE_TOP := 224.0
const ROW := 78.0               ## height of one bookcase shelf
const PLANK := 9.0
const WOOD := Color("#8a5a33")
const WOOD_LIGHT := Color("#a8743f")
const WOOD_DARK := Color("#5e3b1f")
const OUTLINE := Color("#2a1d17")

var _view := Vector2(1280, 720)
var _minis: Array[HeadView] = []
var _friend_ids: Array[int] = []
var _name_label: Label
var _hover := -1


func _ready() -> void:
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", OUTLINE)
	_name_label.add_theme_constant_override("outline_size", 6)
	_name_label.visible = false
	_name_label.z_index = 20
	add_child(_name_label)
	Game.shelf_friends_changed.connect(refresh)
	refresh()


## Lays the shelves out for a view of this size.
func layout(view_size: Vector2) -> void:
	_view = view_size
	for i in _minis.size():
		_minis[i].position = slot_position(i)
	queue_redraw()


## Fades the shelves in (with the banner, so they don't spoil the pop).
func appear(instantly := false) -> void:
	visible = true
	if instantly:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


## Adds new friends and updates avatars that have arrived.
func refresh() -> void:
	for friend in Game.shelf_friends:
		var index := _friend_ids.find(friend.steam_id)
		if index < 0:
			if _minis.size() >= CAPACITY:
				continue  # the shelves are full; later friends aren't added
			_add_mini(friend)
			index = _minis.size() - 1
		var mini := _minis[index]
		if friend.avatar != null and mini.steam_texture != friend.avatar:
			mini.steam_texture = friend.avatar
			mini.show_steam_face = true
	queue_redraw()


func friend_count() -> int:
	return _minis.size()


func _add_mini(friend: Friend) -> void:
	var mini := HeadView.new()
	mini.interactive = false
	mini.base_radius = FIGURE_RADIUS
	mini.scale = Vector2(FIGURE_SCALE, FIGURE_SCALE)
	mini.build = FriendLooks.build_for(friend.steam_id, friend.name)
	mini.position = slot_position(_minis.size())
	add_child(mini)
	_minis.append(mini)
	_friend_ids.append(friend.steam_id)


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

## Where the i-th friend stands (its neck pivot).
func slot_position(i: int) -> Vector2:
	var shelf := i / PER_SHELF
	var spot := i % PER_SHELF
	var plank_y: float
	var left: float
	if shelf == 0:
		left = MARGIN
		plank_y = WALL_SHELF_Y
	elif shelf == 1:
		left = _view.x - MARGIN - SHELF_WIDTH
		plank_y = WALL_SHELF_Y
	else:
		var case := (shelf - 2) / BOOKCASE_SHELVES       # 0 = right bookcase, 1 = left
		var row := (shelf - 2) % BOOKCASE_SHELVES
		left = _view.x - MARGIN - SHELF_WIDTH if case == 0 else MARGIN
		plank_y = BOOKCASE_TOP + ROW * float(row + 1)
	var step := SHELF_WIDTH / PER_SHELF
	# The stand's base (bottom at local y 231) rests on the plank.
	return Vector2(left + step * (spot + 0.5), plank_y - 224.0 * FIGURE_SCALE)


func _bookcases_needed() -> int:
	if _minis.size() > PER_SHELF * (2 + BOOKCASE_SHELVES):
		return 2
	if _minis.size() > PER_SHELF * 2:
		return 1
	return 0


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	var cases := _bookcases_needed()
	if cases >= 1:
		_draw_bookcase(_view.x - MARGIN - SHELF_WIDTH)
	if cases >= 2:
		_draw_bookcase(MARGIN)
	# A bookcase under a wall shelf holds it up, so no brackets there.
	_draw_wall_shelf(MARGIN, cases < 2)
	_draw_wall_shelf(_view.x - MARGIN - SHELF_WIDTH, cases < 1)


## A plank, on two brackets unless a bookcase stands under it.
func _draw_wall_shelf(left: float, brackets: bool) -> void:
	for x in ([left + 34.0, left + SHELF_WIDTH - 34.0] if brackets else []):
		var bracket := PackedVector2Array([
			Vector2(x - 5, WALL_SHELF_Y + PLANK), Vector2(x + 5, WALL_SHELF_Y + PLANK),
			Vector2(x + 5, WALL_SHELF_Y + PLANK + 26), Vector2(x - 5, WALL_SHELF_Y + PLANK + 8),
		])
		draw_colored_polygon(bracket, WOOD_DARK)
		draw_polyline(_closed(bracket), OUTLINE, 2.0, true)
	_draw_plank(Rect2(left - 6, WALL_SHELF_Y, SHELF_WIDTH + 12, PLANK))


## A bookcase: dark back, two sides, a top, and five shelves.
func _draw_bookcase(left: float) -> void:
	var outer := Rect2(left - 10, BOOKCASE_TOP - 6, SHELF_WIDTH + 20, ROW * BOOKCASE_SHELVES + PLANK + 14)
	draw_rect(outer.grow(-6), WOOD_DARK.darkened(0.35))
	for row in BOOKCASE_SHELVES:
		_draw_plank(Rect2(left - 4, BOOKCASE_TOP + ROW * float(row + 1), SHELF_WIDTH + 8, PLANK))
	draw_rect(Rect2(outer.position, Vector2(10, outer.size.y)), WOOD)
	draw_rect(Rect2(outer.end.x - 10, outer.position.y, 10, outer.size.y), WOOD)
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, 10)), WOOD_LIGHT)
	draw_rect(outer, OUTLINE, false, 3.0)


func _draw_plank(rect: Rect2) -> void:
	draw_rect(rect, WOOD_LIGHT)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), WOOD)
	draw_rect(rect, OUTLINE, false, 2.0)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


# --------------------------------------------------------------------------
# Boop and hover
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or modulate.a < 0.5:
		return
	if event is InputEventMouseMotion:
		_set_hover(_mini_at(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _mini_at(get_global_mouse_position())
		if index >= 0:
			var mini := _minis[index]
			var toward := mini.to_local(get_global_mouse_position()) - mini.head_center()
			mini.bobble.nudge_toward(-toward if toward.length() > 0.1 else Vector2.UP, 1.4)
			get_viewport().set_input_as_handled()


func _mini_at(global_point: Vector2) -> int:
	for i in _minis.size():
		var mini := _minis[i]
		if mini.to_local(global_point).distance_to(mini.head_center()) <= mini.radius() * 1.05:
			return i
	return -1


func _set_hover(index: int) -> void:
	if index == _hover:
		return
	_hover = index
	_name_label.visible = index >= 0
	if index < 0:
		return
	var mini := _minis[index]
	_name_label.text = mini.build.player_name
	_name_label.reset_size()
	var head_top := mini.to_global(mini.head_center()) - Vector2(0, mini.radius() * FIGURE_SCALE + 6.0)
	var x := clampf(head_top.x - _name_label.size.x * 0.5, 4.0, _view.x - _name_label.size.x - 4.0)
	_name_label.global_position = Vector2(x, head_top.y - _name_label.size.y)
