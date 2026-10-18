class_name Banner
extends PanelContainer
## "<name> is a Big Head." in the player's chosen colors and font.

var _label := Label.new()
var _font_size := 48


func _init(font_size := 48) -> void:
	_font_size = font_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color("#2a1d17"))
	_label.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_text(text: String) -> void:
	_label.text = text
	reset_size()


func apply_style(style: SceneStyle) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = style.banner_color
	box.border_color = Color("#2a1d17")
	box.set_border_width_all(4)
	box.set_corner_radius_all(10)
	box.content_margin_left = _font_size * 0.66
	box.content_margin_right = _font_size * 0.66
	box.content_margin_top = _font_size * 0.2
	box.content_margin_bottom = _font_size * 0.25
	add_theme_stylebox_override("panel", box)
	_label.add_theme_color_override("font_color", style.banner_text_color)
	var font := style.font()
	if font != null:
		_label.add_theme_font_override("font", font)
	else:
		_label.remove_theme_font_override("font")
	# Press Start 2P is very wide; shrink it so long names still fit.
	var size_scale := 0.6 if style.banner_font == 5 else 1.0
	_label.add_theme_font_size_override("font_size", roundi(_font_size * size_scale))
	reset_size()
