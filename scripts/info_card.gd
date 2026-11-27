# A small centered card with a title, some text and one button.
# Used for the "while you were away" summary and the stats screen.
# The text scrolls when the window is too short to show all of it.
extends Control

var _title: Label
var _scroll: ScrollContainer
var _body: Label
var _button: Button
# Widest the card may get (the main scene sets this from the window width).
var max_width := 440.0:
	set(v):
		max_width = v
		_fit()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			hide())
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color("5fb3d9"))
	vb.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll.add_child(_body)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(hide)
	vb.add_child(_button)

	resized.connect(_fit)
	_body.minimum_size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	if _body == null:
		return
	var w := clampf(max_width - 40.0, 180.0, 440.0)
	_body.custom_minimum_size.x = w - 14.0          # room for the scrollbar
	_scroll.custom_minimum_size.x = w
	# Title, button and padding take roughly 110 px; the text gets the rest.
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, maxf(40.0, size.y - 110.0))


func open(title: String, body: String, button_text := "Nice!", align_left := false) -> void:
	_title.text = title
	_body.text = body
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_CENTER
	_button.text = button_text
	_scroll.scroll_vertical = 0
	show()
	_fit.call_deferred()
