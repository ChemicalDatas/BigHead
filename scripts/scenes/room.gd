extends Control
## A shared room: everyone's bobbleheads together (see NetSession for how
## players connect). Each player walks their own bobblehead with A/D or the
## arrow keys, can boop or fling anyone's head, and right-clicks for
## fireworks everyone sees. The room widens as players join (the view zooms
## out). Everyone sees the host's background; the friends' shelves are left
## out so the room is about who's here.
##
## Each player's own head runs its physics locally and sends where it is
## about 20 times a second; other players' heads just show what arrives.
## Booping or flinging someone else's head asks their game to do it, so every
## head is moved by exactly one player.

const FLOOR_Y := 700.0          ## where the stands rest, in room units
const VIEW_HEIGHT := 720.0
const BASE_WIDTH := 1280.0      ## room width for up to two players
const WIDTH_PER_PLAYER := 320.0 ## and this much more for each one after that
const FIGURE_SCALE := 0.62
const WALK_SPEED := 360.0
const SEND_INTERVAL := 0.05
const NAME_COLOR := Color("#ffe066")

var _background: BackgroundView
var _world: Node2D
var _fireworks: Fireworks
var _status: Label
var _count: Label
var _hint: Label
var _toast: Label
var _invite: Button
## peer id -> {"view": HeadView, "label": Label, "x": float, "name": String,
##             "target_x": float, "offset": Vector2, "angle": float}
var _players := {}
var _room_width := BASE_WIDTH
var _send_left := 0.0
var _walk_velocity := 0.0
var _walk_time := 0.0
## A press on someone else's head: whose, where, and when.
var _remote_press := -1
var _remote_press_at := Vector2.ZERO
var _remote_press_time := 0.0
var _last_stars_at := -1000.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = BackgroundView.new()
	_background.style = Game.profile.style
	_background.image = Game.uploads.texture(UploadStore.BACKGROUND) if Game.net.is_host else null
	add_child(_background)
	_world = Node2D.new()
	add_child(_world)
	_fireworks = Fireworks.new()
	add_child(_fireworks)
	_build_hud()

	multiplayer.peer_disconnected.connect(_on_peer_left)
	var me := multiplayer.get_unique_id()
	_add_player(me, _my_info(), true)
	_layout()
	# Say hello; everyone already here answers with a welcome.
	_hello.rpc(_my_info())
	get_viewport().size_changed.connect(_layout)


func _my_info() -> Dictionary:
	var info := {
		"name": Game.banner_name(),
		"build": Game.profile.build.to_dict() if Game.profile.has_build() else HeadBuild.new().to_dict(),
		"steam_id": Game.profile.steam_id,
		"x": _players[multiplayer.get_unique_id()]["x"] if _players.has(multiplayer.get_unique_id()) else -1.0,
	}
	if Game.net.is_host:
		info["style"] = Game.profile.style.to_dict()
	return info


# --------------------------------------------------------------------------
# Players coming and going
# --------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(info: Dictionary) -> void:
	var from := multiplayer.get_remote_sender_id()
	_add_player(from, info, false)
	_welcome.rpc_id(from, _my_info())
	_show_toast("%s joined" % str(info.get("name", "Someone")))


@rpc("any_peer", "reliable")
func _welcome(info: Dictionary) -> void:
	_add_player(multiplayer.get_remote_sender_id(), info, false)


func _add_player(id: int, info: Dictionary, local: bool) -> void:
	if info.has("style"):
		_background.style = SceneStyle.from_dict(info["style"])
		_background.queue_redraw()
	if _players.has(id):
		return
	var view := HeadView.new()
	view.base_radius = 125.0
	view.scale = Vector2(FIGURE_SCALE, FIGURE_SCALE)
	view.build = HeadBuild.from_dict(info.get("build", {}))
	view.interactive = local
	view.simulate = local
	view.look_at_cursor = local
	if local:
		view.body_texture = Game.uploads.texture(UploadStore.BODY)
		if Game.profile.has_steam_avatar() and Game.profile.style.face_mode != SceneStyle.FaceMode.KEEP_MINE:
			view.steam_texture = Game.profile.steam_avatar
			view.show_steam_face = true
		view.clicked.connect(func(on_head: bool) -> void:
			if on_head:
				Game.report("head_clicked"))
		view.drag_released.connect(_on_own_drag_released)
	else:
		view.build.use_body_texture = false
		var steam_id := int(info.get("steam_id", 0))
		if steam_id != 0 and Game.steam_available:
			Game.identity.request_friend_avatar(steam_id)
	_world.add_child(view)
	var label := Label.new()
	label.text = str(info.get("name", "Player"))
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", NAME_COLOR if local else Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("#2a1d17"))
	label.add_theme_constant_override("outline_size", 7)
	_world.add_child(label)
	var x := float(info.get("x", -1.0))
	if x < 0.0:
		x = randf_range(220.0, _width_for(_players.size() + 1) - 220.0)
	_players[id] = {"view": view, "label": label, "x": x, "target_x": x, "name": label.text,
		"steam_id": int(info.get("steam_id", 0)), "offset": Vector2.ZERO, "angle": 0.0}
	view.position = Vector2(x, _stand_pivot_y())
	_layout()
	_update_count()


func _on_peer_left(id: int) -> void:
	if not _players.has(id):
		return
	var p: Dictionary = _players[id]
	_show_toast("%s left" % p["name"])
	(p["view"] as Node).queue_free()
	(p["label"] as Node).queue_free()
	_players.erase(id)
	_layout()
	_update_count()


## Steam avatars for other players arrive later.
func _on_avatar(steam_id: int, texture: Texture2D) -> void:
	for id in _players:
		var p: Dictionary = _players[id]
		if p["steam_id"] == steam_id and id != multiplayer.get_unique_id():
			var view: HeadView = p["view"]
			view.steam_texture = texture
			view.show_steam_face = true


func _enter_tree() -> void:
	if Game.steam_available:
		Game.identity.friend_avatar_ready.connect(_on_avatar)


func _exit_tree() -> void:
	if Game.steam_available and Game.identity.friend_avatar_ready.is_connected(_on_avatar):
		Game.identity.friend_avatar_ready.disconnect(_on_avatar)


# --------------------------------------------------------------------------
# Layout: the room widens with each player
# --------------------------------------------------------------------------

func _width_for(players: int) -> float:
	return BASE_WIDTH + maxf(0.0, players - 2) * WIDTH_PER_PLAYER


func _stand_pivot_y() -> float:
	return FLOOR_Y - 231.0 * FIGURE_SCALE


func _layout() -> void:
	var view := get_viewport_rect().size
	_room_width = _width_for(_players.size())
	var fit := minf(view.x / _room_width, view.y / VIEW_HEIGHT)
	_world.scale = Vector2(fit, fit)
	_world.position = Vector2((view.x - _room_width * fit) * 0.5, view.y - VIEW_HEIGHT * fit)
	for id in _players:
		var p: Dictionary = _players[id]
		p["x"] = clampf(p["x"], 120.0, _room_width - 120.0)


# --------------------------------------------------------------------------
# Every frame: walk, send, and follow everyone else
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var me := multiplayer.get_unique_id()
	if not _players.has(me):
		return
	_walk(_players[me], delta)
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left = SEND_INTERVAL
		var view: HeadView = _players[me]["view"]
		_state.rpc(_players[me]["x"], view.bobble.offset, view.bobble.angle)
	for id in _players:
		var p: Dictionary = _players[id]
		var view: HeadView = p["view"]
		if id != me:
			# Glide toward the latest news from that player.
			var k := 1.0 - exp(-12.0 * delta)
			p["x"] = lerpf(p["x"], p["target_x"], k)
			view.bobble.offset = view.bobble.offset.lerp(p["offset"], k)
			view.bobble.angle = lerpf(view.bobble.angle, p["angle"], k)
		view.position = Vector2(p["x"], _stand_pivot_y())
		var label: Label = p["label"]
		label.reset_size()
		var top := view.position + Vector2(0, -view.extent_above_pivot() * FIGURE_SCALE - 8.0)
		label.position = Vector2(top.x - label.size.x * 0.5, top.y - label.size.y)


func _walk(p: Dictionary, delta: float) -> void:
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	var view: HeadView = p["view"]
	var target := dir * WALK_SPEED
	var before := _walk_velocity
	_walk_velocity = move_toward(_walk_velocity, target, 2400.0 * delta)
	# Starting and stopping throw the head back and forward; walking bounces it.
	view.bobble.offset_velocity.x -= (_walk_velocity - before) * 0.35
	view.bobble.angular_velocity -= (_walk_velocity - before) * 0.004
	if absf(_walk_velocity) > 10.0:
		_walk_time += delta
		if fmod(_walk_time, 0.32) < delta:
			view.bobble.offset_velocity.y -= 120.0
	p["x"] = clampf(p["x"] + _walk_velocity * delta, 120.0, _room_width - 120.0)


@rpc("any_peer", "unreliable_ordered")
func _state(x: float, offset: Vector2, angle: float) -> void:
	var from := multiplayer.get_remote_sender_id()
	if _players.has(from):
		var p: Dictionary = _players[from]
		p["target_x"] = x
		p["offset"] = offset
		p["angle"] = angle


# --------------------------------------------------------------------------
# Booping, flinging and fireworks
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var mouse := get_global_mouse_position()
	if event.pressed:
		var id := _remote_head_at(mouse)
		if id != 0:
			_remote_press = id
			_remote_press_at = mouse
			_remote_press_time = Time.get_ticks_msec() / 1000.0
			get_viewport().set_input_as_handled()
	elif _remote_press > 0:
		var id := _remote_press
		_remote_press = -1
		get_viewport().set_input_as_handled()
		if not _players.has(id):
			return
		var view: HeadView = _players[id]["view"]
		var moved := (mouse - _remote_press_at) / _world.scale.x / FIGURE_SCALE
		if moved.length() > 12.0:
			# A fling: throw their head the way the mouse went.
			var seconds := maxf(Time.get_ticks_msec() / 1000.0 - _remote_press_time, 0.05)
			_fling.rpc_id(id, (moved / seconds).limit_length(3000.0))
		else:
			_boop.rpc_id(id, view.to_local(mouse) - view.head_center())


func _remote_head_at(global_point: Vector2) -> int:
	var me := multiplayer.get_unique_id()
	for id in _players:
		if id == me:
			continue
		var view: HeadView = _players[id]["view"]
		if view.to_local(global_point).distance_to(view.head_center()) <= view.radius() * 1.1:
			return id
	return 0


## Someone booped my head.
@rpc("any_peer", "reliable")
func _boop(direction: Vector2) -> void:
	var view: HeadView = _players[multiplayer.get_unique_id()]["view"]
	view.bobble.nudge_toward(direction, 1.2)


## Someone flung my head.
@rpc("any_peer", "reliable")
func _fling(velocity: Vector2) -> void:
	var view: HeadView = _players[multiplayer.get_unique_id()]["view"]
	view.bobble.end_drag(velocity)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# One rocket per player in the room, launched on everyone's screen.
		var count := _players.size()
		_fireworks_at.rpc(_world.to_local(get_global_mouse_position()), count)
		Game.report("fireworks_launched", {"count": count})


@rpc("any_peer", "call_local", "reliable")
func _fireworks_at(room_point: Vector2, count: int) -> void:
	_fireworks.launch(_world.to_global(room_point), count)


func _on_own_drag_released(speed: float) -> void:
	Game.report("drag_released", {"speed": speed})
	if speed >= AchievementRules.WHIPLASH_SPEED:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_stars_at >= 30.0:
			_last_stars_at = now
			(_players[multiplayer.get_unique_id()]["view"] as HeadView).show_dizzy_stars(3.0)


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

func _build_hud() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 20)
	box.add_child(_count)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color("#cfc6e0"))
	_status.text = Game.net.status
	box.add_child(_status)
	Game.net.status_changed.connect(func(t: String) -> void:
		if is_instance_valid(_status):
			_status.text = t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_invite = Button.new()
	_invite.text = "Invite a Steam friend"
	_invite.visible = Game.net.mode == NetSession.Mode.STEAM and Game.net.is_host
	_invite.pressed.connect(Game.net.invite_friends)
	row.add_child(_invite)
	var leave := Button.new()
	leave.text = "Leave room"
	leave.pressed.connect(Game.leave_room)
	row.add_child(leave)

	_hint = Label.new()
	_hint.text = "A / D or arrow keys: walk  ·  click a head: boop  ·  drag a head: fling  ·  right-click: fireworks"
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_outline_color", Color("#000000aa"))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, get_viewport_rect().size.y - 34)
	add_child(_hint)


func _update_count() -> void:
	if _count != null:
		_count.text = "Room: %d of %d players" % [_players.size(), NetSession.MAX_PLAYERS]


func _show_toast(text: String) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Label.new()
	_toast.text = text
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", NAME_COLOR)
	_toast.add_theme_color_override("font_outline_color", Color("#2a1d17"))
	_toast.add_theme_constant_override("outline_size", 8)
	add_child(_toast)
	_toast.reset_size()
	_toast.position = Vector2((get_viewport_rect().size.x - _toast.size.x) * 0.5, 24)
	var label := _toast
	var tween := label.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
