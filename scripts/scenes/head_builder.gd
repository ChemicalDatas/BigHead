extends Control
## Head Builder: first launch for everyone, optional later ("Customize"),
## required without Steam. Name entry only appears when Steam is unavailable;
## Steam players get their Steam name.
##
## Tabs: Head (layers, colors, size), Body (shape, texture), Scene (background, banner).
## The screen is a live preview of the background and bobblehead. The banner
## itself only appears after the reveal; the Scene tab shows a small sample
## of its colors and font.
##
## Items the player doesn't own yet stay visible, marked "(locked)": they show
## on the preview, but Play/Save is disabled until every choice is owned.
##
## From the playground (a head already exists) the buttons are Save and Cancel,
## and Esc cancels. On first launch there's nothing to go back to: just Play.
## Uploads are staged and only replace the saved images on Save.

## Guide template (colored outlines, labels) and blank template (plain outlines).
const BODY_TEMPLATE := "res://assets/body_template.png"
const BLANK_TEMPLATE := "res://assets/body_template_blank.png"
const PREVIEW_BASE_RADIUS := 115.0

var _build: HeadBuild
var _style: SceneStyle
var _background: BackgroundView
var _head: HeadView
var _banner_sample: Banner
var _value_labels := {}
var _name_edit: LineEdit = null
var _size_slider: HSlider
var _size_label: Label
var _hair_color: ColorPickerButton
var _skin_color: ColorPickerButton
var _banner_color: ColorPickerButton
var _banner_text_color: ColorPickerButton
var _status: Label
var _lock_note: Label
var _done_button: Button
## True when Customize was opened from the playground (a saved head exists).
var _from_playground := false
var _file_dialog: FileDialog
var _pending_upload := ""      ## which upload the open dialog is for, or "template"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var profile := Game.profile
	_from_playground = profile.has_build()
	Game.uploads.discard()  # nothing staged from an earlier visit
	_build = HeadBuild.from_dict(profile.build.to_dict()) if profile.has_build() else _fresh_build()
	_style = SceneStyle.from_dict(profile.style.to_dict())

	_background = BackgroundView.new()
	_background.style = _style
	_background.image = Game.uploads.preview_texture(UploadStore.BACKGROUND)
	add_child(_background)

	_head = HeadView.new()
	_head.build = _build
	_head.base_radius = PREVIEW_BASE_RADIUS
	_head.body_texture = Game.uploads.preview_texture(UploadStore.BODY)
	add_child(_head)

	var panel := PanelContainer.new()
	panel.position = Vector2(32, 16)
	panel.custom_minimum_size = Vector2(520, 0)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Build your bobblehead"
	title.add_theme_font_size_override("font_size", 28)
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
		_name_edit.custom_minimum_size = Vector2(0, 34)
		_name_edit.add_theme_font_size_override("font_size", 20)
		_name_edit.text_changed.connect(func(_t: String) -> void: _banner_sample.set_text(_sample_name()))
		column.add_child(_name_edit)

	var tabs := TabContainer.new()
	tabs.add_theme_font_size_override("font_size", 18)
	column.add_child(tabs)
	tabs.add_child(_make_head_tab())
	tabs.add_child(_make_body_tab())
	tabs.add_child(_make_scene_tab())

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("#ffb3a7"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	_lock_note = Label.new()
	_lock_note.add_theme_color_override("font_color", Color("#ffd27a"))
	_lock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lock_note.custom_minimum_size = Vector2(440, 0)
	column.add_child(_lock_note)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var random_button := _make_button("Randomize")
	random_button.pressed.connect(_on_randomize)
	buttons.add_child(random_button)
	_done_button = _make_button("Save" if _from_playground else "Play")
	_done_button.pressed.connect(_on_done)
	buttons.add_child(_done_button)
	if _from_playground:
		var cancel := _make_button("Cancel")
		cancel.pressed.connect(_on_cancel)
		buttons.add_child(cancel)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_locks()
	_head.bobble.nudge_toward(Vector2(1, -0.4), 0.8)


func _fresh_build() -> HeadBuild:
	var build := HeadBuild.new()
	build.randomize_all(_rng, Game.inventory)
	return build


## Esc cancels Customize instead of quitting. On first launch there's nothing
## to cancel back to, so Esc is left to the game (which quits).
func _unhandled_input(event: InputEvent) -> void:
	if _from_playground and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


## The banner sample shows only the player's name, never the punchline.
func _sample_name() -> String:
	if _name_edit != null and _name_edit.text.strip_edges() != "":
		return _name_edit.text.strip_edges()
	return Game.banner_name() if Game.steam_available else "Your name"


## The preview figure lives in the right part of the screen.
func _layout() -> void:
	var view := get_viewport_rect().size
	var area_left := 580.0
	var area := Rect2(area_left, 0, maxf(view.x - area_left, 300.0), view.y)
	var top := 20.0
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
		tab.add_child(_make_item_picker(category))
		if category == "accessory":
			tab.add_child(_make_item_picker("accessory_variant"))
		if category == "face_shape":
			_skin_color = _color_row(tab, "Skin color", _build.skin, func(c: Color) -> void: _build.skin = c, HeadBuild.SKIN_PRESETS)
		elif category == "hair":
			_hair_color = _color_row(tab, "Hair color", _build.hair_color, func(c: Color) -> void: _build.hair_color = c, HeadBuild.HAIR_PRESETS)
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
	# Steam players: alternate between the Steam face and this one, or lock either.
	if Game.steam_available:
		tab.add_child(_make_picker("face_mode", func() -> String: return SceneStyle.FACE_MODE_NAMES[_style.face_mode],
			func(step: int) -> void: _style.cycle_face_mode(step)))
	return tab


func _make_body_tab() -> Control:
	var tab := _tab_box("Body")
	tab.add_child(_make_item_picker("body_shape"))
	tab.add_child(_make_item_picker("body_variant"))
	tab.add_child(_make_item_picker("rig"))

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
	var template_row := HBoxContainer.new()
	template_row.add_theme_constant_override("separation", 8)
	var template := _make_button("Save template…")
	template.pressed.connect(_open_template_save.bind(false))
	template_row.add_child(template)
	var blank := _make_button("Save blank template…")
	blank.pressed.connect(_open_template_save.bind(true))
	template_row.add_child(blank)
	tab.add_child(template_row)
	tab.add_child(_hint_label("Paint over a template in Krita or GIMP, then upload it. The whole image covers the body; each body shape shows the part inside its outlines, arms and legs included. The blank one has plain outlines to paint straight onto."))
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
	_banner_sample = Banner.new(20)
	_banner_sample.set_text(_sample_name())
	_banner_sample.apply_style(_style)
	_banner_sample.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_child(_banner_sample)
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
	box.add_theme_constant_override("separation", 4)
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


## A picker for a catalog item: items the player doesn't own read "(locked)".
## Changing a hat or body also moves its Style picker to a style the player owns.
func _make_item_picker(category: String) -> Control:
	return _make_picker(category,
		func() -> String:
			if category == "accessory_variant" and _build.accessory == 0:
				return "-"
			if category == "mouth" and not Catalog.animal_face(_build.face_shape).is_empty():
				return "The face's own"  # animal faces have their mouth built in
			var index := _build.get_choice(category)
			var text := HeadBuild.option_label(category, index)
			if _build.is_option_owned(category, index, Game.inventory):
				return text
			if Catalog.rarity(_build.item_id_for(category, index)) == Catalog.Rarity.MULTIPLAYER:
				return text + " (multiplayer)"
			return text + " (locked)",
		func(step: int) -> void:
			if category == "accessory_variant" and _build.accessory == 0:
				return
			_build.cycle(category, step)
			if category == "hair":
				_refresh_hair_color_enabled()
			if category == "rig" or category == "body_shape":
				_layout()  # the balloon floats higher, so the figure refits
			if category == "accessory" or category == "body_shape":
				_build.select_owned_variant(category, Game.inventory)
			for key in ["accessory_variant", "body_variant", "mouth"]:
				if _value_labels.has(key):
					(_value_labels[key] as Callable).call(),
		func() -> bool: return not _build.is_option_owned(category, _build.get_choice(category), Game.inventory))


## A "<  value  >" row. `read` returns the value text; `step` changes it;
## `is_locked` (optional) greys the value out.
func _make_picker(key: String, read: Callable, step: Callable, is_locked := Callable()) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label_text: String = HeadBuild.CATEGORY_LABELS.get(key, {"background": "Background", "banner_font": "Font", "face_mode": "Face"}.get(key, key))
	row.add_child(_row_label(label_text))
	var value := Label.new()
	value.custom_minimum_size = Vector2(170, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	var prev := _make_button("<")
	prev.custom_minimum_size = Vector2(36, 30)
	var next := _make_button(">")
	next.custom_minimum_size = Vector2(36, 30)
	var refresh := func() -> void:
		value.text = read.call()
		var locked: bool = is_locked.is_valid() and is_locked.call()
		value.add_theme_color_override("font_color", Color("#8c8496") if locked else Color.WHITE)
	prev.pressed.connect(func() -> void: step.call(-1); refresh.call(); _changed(-1.0))
	next.pressed.connect(func() -> void: step.call(1); refresh.call(); _changed(1.0))
	row.add_child(prev)
	row.add_child(value)
	row.add_child(next)
	_value_labels[key] = refresh
	refresh.call()
	return row


func _color_row(parent: Control, text: String, color: Color, on_change: Callable, presets: Array[Color] = []) -> ColorPickerButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_row_label(text))
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(170, 28)
	for preset in presets:
		picker.get_picker().add_preset(preset)
	picker.color_changed.connect(func(c: Color) -> void: on_change.call(c); _changed(0.0))
	row.add_child(picker)
	parent.add_child(row)
	return picker


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size = Vector2(0, 32)
	return button


# --------------------------------------------------------------------------
# Changes
# --------------------------------------------------------------------------

## Something changed: refresh the preview and give the head a little nudge.
func _changed(direction: float) -> void:
	_background.refresh()
	_banner_sample.apply_style(_style)
	_layout()
	_update_locks()
	if direction != 0.0:
		_head.bobble.nudge_toward(Vector2(direction, -0.3), 0.6)


## The rainbow mane keeps its own colors, so the hair color does nothing there.
func _refresh_hair_color_enabled() -> void:
	_hair_color.disabled = _build.hair == HeadView.RAINBOW_HAIR


func _refresh_all() -> void:
	for key in _value_labels:
		(_value_labels[key] as Callable).call()
	_size_slider.set_value_no_signal(_build.head_size)
	_refresh_size_label()
	_hair_color.color = _build.hair_color
	_refresh_hair_color_enabled()
	_skin_color.color = _build.skin
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


## Play/Save only works when every choice is owned.
func _update_locks() -> void:
	var locked := _build.locked_categories(Game.inventory)
	_done_button.disabled = not locked.is_empty()
	if locked.is_empty():
		_lock_note.text = ""
	else:
		var names: Array[String] = []
		for category in locked:
			names.append(HeadBuild.CATEGORY_LABELS[category].to_lower())
		_lock_note.text = "Locked: %s. Find %s in fireworks drops, or pick something you own." % [", ".join(names), "it" if names.size() == 1 else "them"]


func _on_randomize() -> void:
	var keep_texture := _build.use_body_texture
	_build.randomize_all(_rng, Game.inventory)
	_build.use_body_texture = keep_texture
	_refresh_all()
	_head.bobble.nudge_toward(Vector2(_rng.randf_range(-1.0, 1.0), -1.0), 1.0)


func _on_done() -> void:
	if not _build.locked_categories(Game.inventory).is_empty():
		return
	if _name_edit != null:
		_build.player_name = _name_edit.text.strip_edges().left(HeadBuild.MAX_NAME_LENGTH)
	Game.uploads.commit()
	Game.save_build(_build, _style)
	# First launch plays the reveal; returning from Customize goes straight back.
	Game.skip_reveal_once = _from_playground
	Game.go_to(Game.REVEAL_SCENE)


## Throws away every change, including staged uploads.
func _on_cancel() -> void:
	Game.uploads.discard()
	Game.skip_reveal_once = true
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


func _open_template_save(blank: bool) -> void:
	_pending_upload = "template_blank" if blank else "template"
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.title = "Save the blank body template" if blank else "Save the body template"
	_file_dialog.filters = PackedStringArray(["*.png ; PNG image"])
	_file_dialog.current_file = "big_head_body_template_blank.png" if blank else "big_head_body_template.png"
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	if _pending_upload.begins_with("template"):
		save_template(path, _pending_upload == "template_blank")
	else:
		import_upload(_pending_upload, path)


## Stages a picked image (Save keeps it, Cancel drops it) and previews it.
func import_upload(kind: String, path: String) -> void:
	var error := Game.uploads.stage_import(path, kind)
	if error != "":
		_status.text = error
		return
	_status.text = ""
	var texture := Game.uploads.preview_texture(kind)
	if kind == UploadStore.BODY:
		_head.body_texture = texture
		_build.use_body_texture = true
	else:
		_background.image = texture
		_style.use_background_image = true
	_refresh_all()


func _remove_upload(kind: String) -> void:
	Game.uploads.stage_remove(kind)
	if kind == UploadStore.BODY:
		_head.body_texture = null
		_build.use_body_texture = false
	else:
		_background.image = null
		_style.use_background_image = false
	_refresh_all()


func save_template(path: String, blank := false) -> void:
	var texture := load(BLANK_TEMPLATE if blank else BODY_TEMPLATE) as Texture2D
	if texture == null:
		_status.text = "The body template is missing from this build."
		return
	var err := texture.get_image().save_png(path)
	_status.text = "" if err == OK else "Couldn't save the template (error %d)." % err
