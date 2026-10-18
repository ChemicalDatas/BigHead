extends Control
## Head Builder: first launch for everyone, optional later, required without Steam.
## Name entry only appears when Steam is unavailable; Steam players get their Steam name.

var _build: HeadBuild
var _head: HeadView
var _value_labels := {}
var _name_edit: LineEdit = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build = HeadBuild.from_dict(Game.profile.build.to_dict()) if Game.profile.has_build() else _fresh_build()

	var bg := ColorRect.new()
	bg.color = Color("#1b1626")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_head = HeadView.new()
	_head.build = _build
	_head.head_radius = 120.0
	add_child(_head)

	var panel := PanelContainer.new()
	panel.position = Vector2(48, 40)
	panel.custom_minimum_size = Vector2(460, 0)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Build your Big Head"
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)

	if Game.steam_available:
		var who := Label.new()
		who.text = "Playing as %s" % Game.banner_name()
		who.add_theme_color_override("font_color", Color("#b8b0c8"))
		column.add_child(who)
	else:
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Your name"
		_name_edit.max_length = HeadBuild.MAX_NAME_LENGTH
		_name_edit.text = _build.player_name
		_name_edit.custom_minimum_size = Vector2(0, 40)
		_name_edit.add_theme_font_size_override("font_size", 22)
		column.add_child(_name_edit)

	for category in HeadBuild.CATEGORIES:
		column.add_child(_make_picker(category))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)

	var random_button := _make_button("Randomize", 20)
	random_button.pressed.connect(_on_randomize)
	buttons.add_child(random_button)

	var done_button := _make_button("Become a Big Head", 20)
	done_button.pressed.connect(_on_done)
	buttons.add_child(done_button)

	var hint := Label.new()
	hint.text = "Click the head to bobble it."
	hint.add_theme_color_override("font_color", Color("#8c8496"))
	column.add_child(hint)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_head.bobble.nudge_toward(Vector2(1, -0.4), 0.8)


func _fresh_build() -> HeadBuild:
	var build := HeadBuild.new()
	build.randomize_all(_rng)
	return build


func _layout() -> void:
	var view := get_viewport_rect().size
	_head.position = Vector2(view.x * 0.72, view.y * 0.58)


func _make_picker(category: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = HeadBuild.CATEGORY_LABELS[category]
	label.custom_minimum_size = Vector2(140, 0)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var prev := _make_button("<", 20)
	prev.custom_minimum_size = Vector2(44, 40)
	prev.pressed.connect(_on_cycle.bind(category, -1))
	row.add_child(prev)

	var value := Label.new()
	value.custom_minimum_size = Vector2(150, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 20)
	row.add_child(value)
	_value_labels[category] = value

	var next := _make_button(">", 20)
	next.custom_minimum_size = Vector2(44, 40)
	next.pressed.connect(_on_cycle.bind(category, 1))
	row.add_child(next)

	_refresh_label(category)
	return row


func _make_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = Vector2(0, 44)
	return button


func _refresh_label(category: String) -> void:
	(_value_labels[category] as Label).text = HeadBuild.option_label(category, _build.get_choice(category))


func _on_cycle(category: String, step: int) -> void:
	_build.cycle(category, step)
	_refresh_label(category)
	_head.bobble.nudge_toward(Vector2(float(step), -0.3), 0.6)


func _on_randomize() -> void:
	_build.randomize_all(_rng)
	for category in HeadBuild.CATEGORIES:
		_refresh_label(category)
	_head.bobble.nudge_toward(Vector2(_rng.randf_range(-1.0, 1.0), -1.0), 1.0)


func _on_done() -> void:
	if _name_edit != null:
		_build.player_name = _name_edit.text.strip_edges().left(HeadBuild.MAX_NAME_LENGTH)
	Game.save_build(_build)
	Game.go_to(Game.REVEAL_SCENE)
