extends Control
## The reveal. Choreography depends on which avatars exist:
##   built + Steam : built head bobbles, the face pops, the Steam face appears
##   Steam only    : the Steam face pops in from blank
##   built only    : built head only (non-Steam fallback)
## Then the banner drops in and "Big Head" unlocks for Steam players.

const BUILT_HEAD_BEAT := 1.6     ## seconds the built head bobbles before the pop
const AVATAR_TIMEOUT := 6.0      ## give up waiting for the Steam avatar after this

var _head: HeadView
var _confetti: Confetti
var _banner: PanelContainer
var _banner_label: Label
var _buttons: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color("#221a33")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_head = HeadView.new()
	_head.head_radius = 125.0
	if Game.profile.has_build():
		_head.build = Game.profile.build
	else:
		# Steam face only: no hair or accessory, face appears at the pop.
		_head.build = HeadBuild.new()
		_head.build.hair = 0
		_head.build.accessory = 0
		_head.face_hidden = true
	add_child(_head)

	_confetti = Confetti.new()
	add_child(_confetti)

	_build_banner()
	_build_buttons()

	var hint := Label.new()
	hint.text = "Click to bobble"
	hint.add_theme_color_override("font_color", Color("#8c8496"))
	hint.add_theme_font_size_override("font_size", 18)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position += Vector2(24, -40)
	add_child(hint)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_run_reveal()


func _layout() -> void:
	var view := get_viewport_rect().size
	_head.position = Vector2(view.x * 0.5, view.y * 0.66)
	_confetti.position = _head.position + Vector2(0, -_head.head_radius * 0.92)
	_banner.position.x = (view.x - _banner.size.x) * 0.5


func _build_banner() -> void:
	_banner = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#c0392b")
	style.border_color = Color("#2a1d17")
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_banner.add_theme_stylebox_override("panel", style)
	_banner_label = Label.new()
	_banner_label.text = "%s is a Big Head." % Game.banner_name()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 48)
	_banner_label.add_theme_color_override("font_color", Color.WHITE)
	_banner_label.add_theme_color_override("font_outline_color", Color("#2a1d17"))
	_banner_label.add_theme_constant_override("outline_size", 8)
	_banner.add_child(_banner_label)
	_banner.position.y = -200
	_banner.visible = false
	add_child(_banner)


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
	edit.text = "Edit my head"
	edit.add_theme_font_size_override("font_size", 20)
	edit.pressed.connect(func() -> void: Game.go_to(Game.BUILDER_SCENE))
	_buttons.add_child(edit)

	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size", 20)
	quit.pressed.connect(func() -> void: get_tree().quit())
	_buttons.add_child(quit)


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
			_confetti.burst()
			await get_tree().create_timer(0.6).timeout
		else:
			push_warning("Steam avatar did not arrive; keeping the built head.")
	else:
		await get_tree().create_timer(1.0).timeout

	await _drop_banner()
	Game.report("reveal_finished")


func _wait_for_avatar() -> void:
	var waited := 0.0
	while not Game.profile.has_steam_avatar() and waited < AVATAR_TIMEOUT:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _drop_banner() -> void:
	_banner.visible = true
	_banner.reset_size()
	_layout()
	_banner.pivot_offset = _banner.size * 0.5
	var target_y := 40.0
	var tween := create_tween()
	tween.tween_property(_banner, "position:y", target_y, 0.7) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_buttons, "modulate:a", 1.0, 0.5).set_delay(0.4)
	await tween.finished
	_head.bobble.nudge_toward(Vector2(0, -1), 0.5)
