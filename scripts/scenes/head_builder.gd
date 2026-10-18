extends Control
## Head Builder: first launch for everyone, optional later ("Customize"),
## required without Steam. Name entry only appears when Steam is unavailable;
## Steam players get their Steam name.
##
## Tabs: Head (layers + size), Body (shape, color, texture), Scene (background, banner).
## The whole screen is a live preview: background, bobblehead and banner.

const BODY_TEMPLATE := "res://assets/body_template.png"
const PREVIEW_BASE_RADIUS := 115.0

var _build: HeadBuild
var _style: SceneStyle
var _background: BackgroundView
var _head: HeadView
var _banner: Banner
var _value_labels := {}
var _name_edit: LineEdit = null
var _size_slider: HSlider
var _size_label: Label
var _body_color: ColorPickerButton
var _banner_color: ColorPickerButton
var _banner_text_color: ColorPickerButton
var _status: Label
var _file_dialog: FileDialog
var _pending_upload := ""      ## which upload the open dialog is for, or "template"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var profile := Game.profile
	_build = HeadBuild.from_dict(profile.build.to_dict()) if profile.has_build() else _fresh_build()
	_style = SceneStyle.from_dict(profile.style.to_dict())

	_background = BackgroundView.new()
	_background.style = _style
	_background.image = Game.uploads.texture(UploadStore.BACKGROUND)
	add_child(_background)

	_head = HeadView.new()
	_head.build = _build
	_head.base_radius = PREVIEW_BASE_RADIUS
	_head.body_texture = Game.uploads.texture(UploadStore.BODY)
	add_child(_head)

	_banner = Banner.new(30)
	_banner.set_text("%s is a Big Head." % _preview_name())
	_banner.apply_style(_style)
	add_child(_banner)

	var panel := PanelContainer.new()
	panel.position = Vector2(32, 24)
	panel.custom_minimum_size = Vector2(520, 0)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Build your Big Head"
	title.add_theme_font_size_override("font_size", 32)
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
		_name_edit.add_theme_font_size_override("font_size", 20)
		_name_edit.text_changed.connect(func(_t: String) -> void: _banner.set_text("%s is a Big Head." % _preview_name()); _layout())
		column.add_child(_name_edit)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 430)
	tabs.add_theme_font_size_override("font_size", 18)
	column.add_child(tabs)
	tabs.add_child(_make_head_tab())
	tabs.add_child(_make_body_tab())
	tabs.add_child(_make_scene_tab())

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("#ffb3a7"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var random_button := _make_button("Randomize")
	random_button.pressed.connect(_on_randomize)
	buttons.add_child(random_button)
	var done_button := _make_button("Become a Big Head")
	done_button.pressed.connect(_on_done)
	buttons.add_child(done_button)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_head.bobble.nudge_toward(Vector2(1, -0.4), 0.8)


func _fresh_build() -> HeadBuild:
	var build := HeadBuild.new()
	build.randomize_all(_rng)
	return build


func _preview_name() -> String:
	if _name_edit != null and _name_edit.text.strip_edges() != "":
		return _name_edit.text.strip_edges()
	return Game.banner_name() if Game.steam_available else "Your name"


## The preview figure lives in the right part of the screen, under its banner.
func _layout() -> void:
	var view := get_viewport_rect().size
	var area_left := 580.0
	var area := Rect2(area_left, 0, maxf(view.x - area_left, 300.0), view.y)
	_banner.reset_size()
	_banner.position = Vector2(area.get_center().x - _banner.size.x * 0.5, 20)
	var top := _banner.position.y + _banner.size.y + 12.0
	var bottom := view.y - 16.0
	var needed := _head.extent_above_pivot() + _head.extent_below_pivot()
	var fit := minf(1.0, (bottom - top) / needed)
	_head.scale = Vector2(fit, fit)
	_head.position = Vector2(area.get_center().x, bottom - _head.extent_below_pivot() * fit)


# --------------------------------------------------------------------------
# Tabs
# --------------------------------------------------------------------------

func _make_head_tab() -> Control:
	var tab := _tab_box("Head")
	for category in HeadBuild.CATEGORIES:
		tab.add_child(_make_picker(category, func() -> String: return HeadBuild.option_label(category, _build.get_choice(category)),
			func(step: int) -> void: _build.cycle(category, step)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _row_label("Head size")
	row.add_child(label)
	_size_slider = HSlider.new()
	_size_slider.min_value = HeadBuild.MIN_HEAD_SIZE
	_size_slider.max_value = HeadBuild.MAX_HEAD_SIZE
	_size_slider.step = 0.05
	_size_slider.value = _build.head_size
	_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size_slider.value_changed.connect(_on_head_size_changed)
	row.add_child(_size_slider)
	_size_label = Label.new()
	_size_label.custom_minimum_size = Vector2(64, 0)
	_size_label.add_theme_font_size_override("font_size", 18)
	row.add_child(_size_label)
	tab.add_child(row)
	_refresh_size_label()
	return tab


func _make_body_tab() -> Control:
	var tab := _tab_box("Body")
	tab.add_child(_make_picker("body_shape", func() -> String: return HeadBuild.option_label("body_shape", _build.body_shape),
		func(step: int) -> void:
			_build.cycle("body_shape", step)
			_build.body_color = HeadBuild.BODY_DEFAULT_COLORS[_build.body_shape]
			_body_color.color = _build.body_color))
	_body_color = _color_row(tab, "Body color", _build.body_color, func(c: Color) -> void: _build.body_color = c)

	tab.add_child(_section_label("Your own texture"))
	var upload_row := HBoxContainer.new()
	upload_row.add_theme_constant_override("separation", 8)
	var upload := _make_button("Upload texture…")
	upload.pressed.connect(_open_upload.bind(UploadStore.BODY))
	upload_row.add_child(upload)
	var remove := _make_button("Remove")
	remove.pressed.connect(_remove_upload.bind(UploadStore.BODY))
	upload_row.add_child(remove)
	tab.add_child(upload_row)
	var template := _make_button("Save body template…")
	template.pressed.connect(_open_template_save)
	tab.add_child(template)
	tab.add_child(_hint_label("Paint over the template in Krita or GIMP, then upload it. The whole image covers the body; each body shape shows the part inside its outline."))
	return tab


func _make_scene_tab() -> Control:
	var tab := _tab_box("Scene")
	tab.add_child(_make_picker("background", func() -> String:
			return "Your image" if _style.use_background_image else SceneStyle.BACKGROUNDS[_style.background],
		func(step: int) -> void:
			_style.use_background_image = false
			_style.cycle_background(step)))
	var upload_row := HBoxContainer.new()
	upload_row.add_theme_constant_override("separation", 8)
	var upload := _make_button("Upload background…")
	upload.pressed.connect(_open_upload.bind(UploadStore.BACKGROUND))
	upload_row.add_child(upload)
	var remove := _make_button("Remove")
	remove.pressed.connect(_remove_upload.bind(UploadStore.BACKGROUND))
	upload_row.add_child(remove)
	tab.add_child(upload_row)

	tab.add_child(_section_label("Banner"))
	_banner_color = _color_row(tab, "Banner color", _style.banner_color, func(c: Color) -> void: _style.banner_color = c)
	_banner_text_color = _color_row(tab, "Text color", _style.banner_text_color, func(c: Color) -> void: _style.banner_text_color = c)
	tab.add_child(_make_picker("banner_font", func() -> String: return SceneStyle.FONT_NAMES[_style.banner_font],
		func(step: int) -> void: _style.cycle_font(step)))
	return tab


# --------------------------------------------------------------------------
# Widgets
# --------------------------------------------------------------------------

func _tab_box(tab_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = tab_name
	box.add_theme_constant_override("separation", 8)
	return box


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 18)
	return label


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#e8d9ff"))
	return label


func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(440, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#a79fb8"))
	return label


## A "<  value  >" row. `read` returns the value text; `step` changes it.
func _make_picker(key: String, read: Callable, step: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label_text: String = HeadBuild.CATEGORY_LABELS.get(key, {"background": "Background", "banner_font": "Font"}.get(key, key))
	row.add_child(_row_label(label_text))
	var value := Label.new()
	value.custom_minimum_size = Vector2(170, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	var prev := _make_button("<")
	prev.custom_minimum_size = Vector2(40, 36)
	var next := _make_button(">")
	next.custom_minimum_size = Vector2(40, 36)
	var refresh := func() -> void: value.text = read.call()
	prev.pressed.connect(func() -> void: step.call(-1); refresh.call(); _changed(-1.0))
	next.pressed.connect(func() -> void: step.call(1); refresh.call(); _changed(1.0))
	row.add_child(prev)
	row.add_child(value)
	row.add_child(next)
	_value_labels[key] = refresh
	refresh.call()
	return row


func _color_row(parent: Control, text: String, color: Color, on_change: Callable) -> ColorPickerButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_row_label(text))
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(170, 34)
	picker.color_changed.connect(func(c: Color) -> void: on_change.call(c); _changed(0.0))
	row.add_child(picker)
	parent.add_child(row)
	return picker


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(0, 38)
	return button


# --------------------------------------------------------------------------
# Changes
# --------------------------------------------------------------------------

## Something changed: refresh the preview and give the head a little nudge.
func _changed(direction: float) -> void:
	_background.refresh()
	_banner.apply_style(_style)
	_layout()
	if direction != 0.0:
		_head.bobble.nudge_toward(Vector2(direction, -0.3), 0.6)


func _refresh_all() -> void:
	for key in _value_labels:
		(_value_labels[key] as Callable).call()
	_size_slider.set_value_no_signal(_build.head_size)
	_refresh_size_label()
	_body_color.color = _build.body_color
	_banner_color.color = _style.banner_color
	_banner_text_color.color = _style.banner_text_color
	_changed(0.0)


func _refresh_size_label() -> void:
	_size_label.text = "%d%%" % roundi(_build.head_size * 100.0)


func _on_head_size_changed(value: float) -> void:
	_build.set_head_size(value)
	_refresh_size_label()
	_layout()
	_head.bobble.nudge_toward(Vector2(0, -1), 0.3)
	if _build.is_head_maxed():
		Game.report("head_size_maxed")


func _on_randomize() -> void:
	var keep_texture := _build.use_body_texture
	_build.randomize_all(_rng)
	_build.use_body_texture = keep_texture
	_refresh_all()
	_head.bobble.nudge_toward(Vector2(_rng.randf_range(-1.0, 1.0), -1.0), 1.0)


func _on_done() -> void:
	if _name_edit != null:
		_build.player_name = _name_edit.text.strip_edges().left(HeadBuild.MAX_NAME_LENGTH)
	Game.save_build(_build, _style)
	Game.go_to(Game.REVEAL_SCENE)


# --------------------------------------------------------------------------
# Uploads
# --------------------------------------------------------------------------

func _open_upload(kind: String) -> void:
	_pending_upload = kind
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = "Choose an image"
	_file_dialog.filters = PackedStringArray(UploadStore.FILTERS)
	_file_dialog.popup_centered_ratio(0.6)


func _open_template_save() -> void:
	_pending_upload = "template"
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.title = "Save the body template"
	_file_dialog.filters = PackedStringArray(["*.png ; PNG image"])
	_file_dialog.current_file = "big_head_body_template.png"
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	if _pending_upload == "template":
		save_template(path)
	else:
		import_upload(_pending_upload, path)


## Copies a picked image into the game's storage and switches to it.
func import_upload(kind: String, path: String) -> void:
	var error := Game.uploads.import_image(path, kind)
	if error != "":
		_status.text = error
		return
	_status.text = ""
	var texture := Game.uploads.texture(kind)
	if kind == UploadStore.BODY:
		_head.body_texture = texture
		_build.use_body_texture = true
	else:
		_background.image = texture
		_style.use_background_image = true
	_refresh_all()


func _remove_upload(kind: String) -> void:
	Game.uploads.erase(kind)
	if kind == UploadStore.BODY:
		_head.body_texture = null
		_build.use_body_texture = false
	else:
		_background.image = null
		_style.use_background_image = false
	_refresh_all()


func save_template(path: String) -> void:
	var texture := load(BODY_TEMPLATE) as Texture2D
	if texture == null:
		_status.text = "The body template is missing from this build."
		return
	var err := texture.get_image().save_png(path)
	_status.text = "" if err == OK else "Couldn't save the template (error %d)." % err
