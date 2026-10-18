extends Control
## Company splash. Steam initializes in the Game autoload before this runs,
## and the avatar request is already in flight while the name fades.

const HOLD_SECONDS := 1.6

var _leaving := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0f0d14")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var title := Label.new()
	title.text = Game.COMPANY_NAME
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#f4efe6"))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "presents"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("#8c8496"))
	box.add_child(sub)

	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.8)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(_leave)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_action("ui_cancel"):
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Game.go_to(Game.scene_after_splash())
