extends Control
## The reveal, then the playground.
##
## Choreography depends on which avatars exist:
##   built + Steam : built head bobbles, the face pops, the Steam face appears
##   Steam only    : the Steam face pops in from blank
##   built only    : built head only (non-Steam fallback)
## Then the banner drops in and "Big Head" unlocks for Steam players.
## After that: left-click/drag the head, right-click for fireworks.

const BUILT_HEAD_BEAT := 1.6     ## seconds the built head bobbles before the pop
const AVATAR_TIMEOUT := 6.0      ## give up waiting for the Steam avatar after this
const BANNER_TOP := 24.0
const BANNER_CLEARANCE := 120.0  ## space reserved under the top edge for the banner
const BASE_RADIUS := 125.0
## Dizzy stars after a whiplash-speed fling: how long they circle, and how
## long before another fling can bring them back.
const STARS_SECONDS := 3.0
const STARS_COOLDOWN := 30.0

var _background: BackgroundView
var _head: HeadView
var _confetti: Confetti
## Gift boxes and drop confetti live on their own layer above the head.
var _drops: Node2D
var _toast: Label
var _fireworks: Fireworks
var _banner: Banner
var _buttons: HBoxContainer
var _hint: Label
var _playground := false
var _last_stars_at := -1000.0
var _moving_for := 0.0
var _still_for := 0.0
var _reported_bobbling := false
var _reported_still := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var profile := Game.profile

	_background = BackgroundView.new()
	_background.style = profile.style
	_background.image = Game.uploads.texture(UploadStore.BACKGROUND)
	add_child(_background)

	_head = HeadView.new()
	_head.base_radius = BASE_RADIUS
	if profile.has_build():
		_head.build = profile.build
		_head.body_texture = Game.uploads.texture(UploadStore.BODY)
	else:
		# Steam face only: no hair or accessory, face appears at the pop.
		_head.build = HeadBuild.new()
		_head.build.hair = 0
		_head.build.accessory = 0
		_head.face_hidden = true
	add_child(_head)
	_head.clicked.connect(_on_head_clicked)
	_head.drag_released.connect(_on_drag_released)
	_head.balloon_popped.connect(_on_balloon_popped)

	_confetti = Confetti.new()
	add_child(_confetti)
	_fireworks = Fireworks.new()
	add_child(_fireworks)
	_drops = Node2D.new()
	add_child(_drops)

	_banner = Banner.new(48)
	_banner.apply_style(profile.style)
	_banner.set_text("%s is a Big Head." % Game.banner_name())
	_banner.position.y = -220
	_banner.visible = false
	add_child(_banner)

	_build_buttons()

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Color.WHITE)
	_hint.add_theme_color_override("font_outline_color", Color("#000000aa"))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.position = Vector2(24, 0)
	add_child(_hint)
	_update_hint()
	Game.friends_with_big_head_changed.connect(func(_c: int) -> void: _update_hint())

	get_viewport().size_changed.connect(_layout)
	_layout()
	_restore_waiting_gifts()
	_run_reveal()


func _layout() -> void:
	var view := get_viewport_rect().size
	# Fit the figure between the banner and the bottom edge; a swelled head
	# shrinks the whole figure instead of running into the banner.
	var bottom := view.y - 12.0
	var available := bottom - BANNER_CLEARANCE
	var needed := _head.extent_above_pivot() + _head.extent_below_pivot()
	var fit := minf(1.0, available / needed)
	_head.scale = Vector2(fit, fit)
	_head.position = Vector2(view.x * 0.5, bottom - _head.extent_below_pivot() * fit)
	_confetti.position = _head.position + Vector2(0, -_head.radius() * 0.92 * fit)
	_banner.position.x = (view.x - _banner.size.x) * 0.5
	_hint.position.y = view.y - 40.0


func _build_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_buttons.position += Vector2(-24, -24)
	_buttons.modulate.a = 0.0
	add_child(_buttons)

	var edit := Button.new()
	edit.text = "Customize"
	edit.add_theme_font_size_override("font_size", 20)
	edit.pressed.connect(func() -> void: Game.go_to(Game.BUILDER_SCENE))
	_buttons.add_child(edit)

	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size", 20)
	quit.pressed.connect(func() -> void: get_tree().quit())
	_buttons.add_child(quit)


func _update_hint() -> void:
	var rockets := Game.rockets_per_click()
	var fireworks := "Right-click: fireworks"
	if rockets > 1:
		fireworks += " (x%d, thanks to %d Big Head friend%s)" % [rockets, rockets - 1, "" if rockets == 2 else "s"]
	var drag := "Drag the bar or the head" if _head.is_marionette() else "Click or drag the head"
	_hint.text = "%s  ·  %s" % [drag, fireworks]


func _run_reveal() -> void:
	var has_build := Game.profile.has_build()

	if Game.skip_reveal_once:
		Game.skip_reveal_once = false
		_enter_playground_directly()
		return

	if has_build:
		_head.bobble.nudge_toward(Vector2(1, -0.5), 1.1)

	if Game.steam_available:
		if has_build:
			await get_tree().create_timer(BUILT_HEAD_BEAT).timeout
		await _wait_for_avatar()
		if Game.profile.has_steam_avatar():
			_head.pop_to_steam_face(Game.profile.steam_avatar)
			await _head.popped
			# The punchline lands all at once: new face, confetti and banner together.
			_confetti.burst()
			await _slam_banner()
			if has_build:
				_run_face_cycle()
		else:
			push_warning("Steam avatar did not arrive; keeping the built head.")
			await _slam_banner()
	else:
		await get_tree().create_timer(1.0).timeout
		await _slam_banner()

	Game.report("reveal_finished")
	_playground = true


## Back from Customize: no pop, no wait. The head, banner and buttons are
## already in place, and the face cycle starts again from the Steam face
## (or stays on the player's own face if that's locked in).
func _enter_playground_directly() -> void:
	var profile := Game.profile
	var steam_face := Game.steam_available and profile.has_steam_avatar()
	if steam_face:
		_head.steam_texture = profile.steam_avatar
		_head.face_hidden = false
		_head.show_steam_face = profile.style.face_mode != SceneStyle.FaceMode.KEEP_MINE or not profile.has_build()
	_banner.visible = true
	_banner.reset_size()
	_layout()
	_banner.position.y = BANNER_TOP
	_buttons.modulate.a = 1.0
	_playground = true
	if steam_face and profile.has_build() and profile.style.face_mode == SceneStyle.FaceMode.ALTERNATE:
		_run_face_cycle()


## Steam players with a built head: the Steam face stays 15 s, the built face
## 45 s, repeating, unless the face is locked in Customize. Swaps only change
## the face (no kick), wait until a drag ends, and bring confetti back once
## every 10 cycles. Runs on a Timer child so it stops when the scene closes.
func _run_face_cycle() -> void:
	var mode := Game.profile.style.face_mode
	if mode == SceneStyle.FaceMode.KEEP_STEAM:
		return
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	var cycle := 0
	while true:
		timer.start(Game.STEAM_FACE_SECONDS * Game.face_time_scale)
		await timer.timeout
		await _wait_until_not_dragging()
		_head.swap_face(false)
		if mode == SceneStyle.FaceMode.KEEP_MINE:
			return
		timer.start(Game.OWN_FACE_SECONDS * Game.face_time_scale)
		await timer.timeout
		await _wait_until_not_dragging()
		cycle += 1
		_head.swap_face(true)
		if cycle % Game.CONFETTI_EVERY_CYCLES == 0:
			await _head.face_swapped
			_confetti.burst()


func _wait_until_not_dragging() -> void:
	while _head.is_dragging():
		await get_tree().process_frame


func _wait_for_avatar() -> void:
	var waited := 0.0
	while not Game.profile.has_steam_avatar() and waited < AVATAR_TIMEOUT:
		await get_tree().process_frame
		waited += get_process_delta_time()


## The banner appears in place, oversized, and punches down to full size in a
## quarter second, so it lands on the same beat as the pop.
func _slam_banner() -> void:
	_banner.visible = true
	_banner.reset_size()
	_layout()
	_banner.position.y = BANNER_TOP
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.6, 1.6)
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_banner, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(_buttons, "modulate:a", 1.0, 0.5).set_delay(0.6)
	await tween.finished


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		launch_fireworks(get_global_mouse_position())


## Right-click: one rocket of yours plus one per friend with Big Head.
func launch_fireworks(at: Vector2) -> void:
	var count := Game.rockets_per_click()
	_fireworks.launch(at, count)
	if _playground:
		Game.report("fireworks_launched", {"count": count})
		_roll_drop(at)


# --------------------------------------------------------------------------
# Drops
# --------------------------------------------------------------------------

## One roll per right-click, whatever the rocket count. The result shows up
## when the first rocket bursts: a gift box for a new item, confetti for an
## item the player already owns.
func _roll_drop(at: Vector2) -> void:
	var result := Game.roll_drop()
	if result.kind == DropRules.Kind.NOTHING:
		return
	get_tree().create_timer(0.85).timeout.connect(_show_drop.bind(result.kind, result.item_id, result.super_rare, at))


func _show_drop(kind: DropRules.Kind, item_id: String, super_rare: bool, at: Vector2) -> void:
	if kind == DropRules.Kind.DUPLICATE:
		_burst_confetti(at, 70)
		return
	_spawn_gift(item_id, super_rare, at, false)


func _spawn_gift(item_id: String, super_rare: bool, at: Vector2, landed: bool) -> void:
	var view := get_viewport_rect().size
	var box := GiftBox.new()
	box.item_id = item_id
	box.super_rare = super_rare
	box.floor_y = view.y - 64.0
	box.target_x = _free_floor_x(at.x)
	box.position = Vector2(box.target_x if landed else clampf(at.x, 70.0, view.x - 70.0), box.floor_y if landed else at.y)
	box.opened.connect(_on_gift_opened.bind(box))
	_drops.add_child(box)


## A floor spot near `x` that keeps clear of the bobblehead's stand, the
## corner hint and buttons, and other boxes.
func _free_floor_x(x: float) -> float:
	const SPACING := 76.0
	var view := get_viewport_rect().size
	var stand_half := 150.0 * _head.scale.x
	var lo := 300.0
	var hi := view.x - 300.0
	var taken: Array[float] = []
	for child in _drops.get_children():
		if child is GiftBox:
			taken.append((child as GiftBox).target_x)
	var side := -1.0 if x < _head.position.x else 1.0
	var spot := clampf(x, lo, hi)
	if absf(spot - _head.position.x) < stand_half + SPACING * 0.5:
		spot = _head.position.x + side * (stand_half + SPACING * 0.5)
	for attempt in 40:
		var clear := true
		for other in taken:
			if absf(other - spot) < SPACING:
				clear = false
				break
		if clear and spot >= lo and spot <= hi:
			return spot
		spot += side * SPACING
		if spot > hi or spot < lo:
			side = -side
			spot = _head.position.x + side * (stand_half + SPACING * 0.5)
	return clampf(x, lo, hi)


## Boxes still waiting from earlier (e.g. before a trip to Customize) are
## already on the floor.
func _restore_waiting_gifts() -> void:
	var view := get_viewport_rect().size
	var gifts := Game.waiting_gifts()
	var i := 0
	for item_id in gifts:
		var x := view.x * (0.2 + 0.6 * fmod(0.37 * float(i) + 0.13, 1.0))
		_spawn_gift(item_id, gifts[item_id], Vector2(x, 0.0), true)
		i += 1


func _on_gift_opened(item_id: String, box: GiftBox) -> void:
	var is_new := Game.open_gift(item_id)
	_burst_confetti(box.global_position + Vector2(0, -30), 50)
	_show_toast(("New: %s!" if is_new else "Already yours: %s") % Catalog.display_name(item_id))


func _burst_confetti(at: Vector2, amount: int) -> void:
	var burst := Confetti.new()
	burst.amount = amount
	burst.position = at
	_drops.add_child(burst)
	burst.burst()
	get_tree().create_timer(2.5).timeout.connect(burst.queue_free)


func _show_toast(text: String) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	_toast = Label.new()
	_toast.text = text
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_color", Color("#ffe066"))
	_toast.add_theme_color_override("font_outline_color", Color("#2a1d17"))
	_toast.add_theme_constant_override("outline_size", 8)
	add_child(_toast)
	_toast.reset_size()
	var view := get_viewport_rect().size
	# Just under the banner, clear of the head.
	_toast.position = Vector2((view.x - _toast.size.x) * 0.5, _banner.position.y + _banner.size.y + 14.0)
	var label := _toast
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 12.0, 2.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(1.4)
	tween.tween_callback(label.queue_free)


func _on_head_clicked(on_head: bool) -> void:
	if on_head and _playground:
		Game.report("head_clicked")


func _on_drag_released(speed: float) -> void:
	if not _playground:
		return
	Game.report("drag_released", {"speed": speed})
	# A whiplash-speed fling leaves the head seeing stars, at most once per cooldown.
	if speed >= AchievementRules.WHIPLASH_SPEED:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_stars_at >= STARS_COOLDOWN:
			_last_stars_at = now
			_head.show_dizzy_stars(STARS_SECONDS)


func _on_balloon_popped(cause: String) -> void:
	print("[rig] Balloon popped (%s)." % cause)
	if _playground:
		Game.report("balloon_popped", {"cause": cause})


func _process(delta: float) -> void:
	if not _playground:
		return
	# A climbing rocket that flies into the balloon head pops it.
	if _head.is_balloon():
		for at in _fireworks.rocket_positions():
			var local := _head.to_local(at)
			if _head.hits_balloon(local):
				_head.pop_balloon(local, "firework")
				break
	# Perpetual Motion: keep it moving for 60 s. Level-Headed: leave it still for 5 min.
	if _head.is_resting():
		_still_for += delta
		_moving_for = 0.0
		_reported_bobbling = false
		if not _reported_still and _still_for >= AchievementRules.LEVEL_HEADED_SECONDS:
			_reported_still = true
			Game.report("still_for", {"seconds": _still_for})
	else:
		_moving_for += delta
		_still_for = 0.0
		_reported_still = false
		if not _reported_bobbling and _moving_for >= AchievementRules.PERPETUAL_SECONDS:
			_reported_bobbling = true
			Game.report("bobbling_for", {"seconds": _moving_for})
