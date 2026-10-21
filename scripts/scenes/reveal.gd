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

	_confetti = Confetti.new()
	add_child(_confetti)
	_fireworks = Fireworks.new()
	add_child(_fireworks)

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
	_hint.text = "Click or drag the head  ·  %s" % fireworks


func _run_reveal() -> void:
	var has_build := Game.profile.has_build()

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
	while _head.bobble.dragging:
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


func _on_head_clicked(on_head: bool) -> void:
	if on_head and _playground:
		Game.report("head_clicked")


func _on_drag_released(speed: float) -> void:
	# Every fling is logged, so it's clear what speed it reached and why the
	# stars did or didn't appear.
	var fling := "[fx] Fling at %s px/s: " % _thousands(roundi(speed))
	if not _playground:
		print(fling + "ignored (the reveal hasn't finished)")
		return
	Game.report("drag_released", {"speed": speed})
	# A whiplash-speed fling leaves the head seeing stars, at most once per cooldown.
	if speed < AchievementRules.WHIPLASH_SPEED:
		print(fling + "no stars (needs %s px/s)" % _thousands(roundi(AchievementRules.WHIPLASH_SPEED)))
		return
	var now := Time.get_ticks_msec() / 1000.0
	var wait := STARS_COOLDOWN - (now - _last_stars_at)
	if wait > 0.0:
		print(fling + "no stars (cooldown, %d s left)" % ceili(wait))
		return
	_last_stars_at = now
	_head.show_dizzy_stars(STARS_SECONDS)
	print(fling + "dizzy stars for %d s" % roundi(STARS_SECONDS))


## 2640 -> "2,640"
func _thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


func _process(delta: float) -> void:
	if not _playground:
		return
	# Perpetual Motion: keep it moving for 60 s. Level-Headed: leave it still for 5 min.
	if _head.bobble.is_resting():
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
