# A list of every fish in the tank. Click a row to open that fish's card.
# Opened with L or the "Fish list" button in the shop. The main scene
# supplies the rows (text and color) while the list is open.
extends Control

signal fish_selected(fish)

var _title: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _buttons: Array = []       # one Button per fish, reused between refreshes
var _fish: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
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
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color("5fb3d9"))
	vb.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)

	var hint := Label.new()
	hint.text = "Click a fish to name or sell it."
	hint.add_theme_color_override("font_color", Color("4f7a96"))
	vb.add_child(hint)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(hide)
	vb.add_child(close)

	resized.connect(_fit)
	visibility_changed.connect(_fit)


# rows: Array of {fish, text, color}. Reuses buttons so hovering stays smooth.
func update_rows(title: String, rows: Array) -> void:
	_title.text = title
	while _buttons.size() < rows.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var idx := _buttons.size()
		b.pressed.connect(func():
			if idx < _fish.size():
				fish_selected.emit(_fish[idx]))
		_rows.add_child(b)
		_buttons.append(b)
	_fish.clear()
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.visible = i < rows.size()
		if b.visible:
			_fish.append(rows[i].fish)
			b.text = rows[i].text
			b.add_theme_color_override("font_color", rows[i].color)
			b.add_theme_color_override("font_hover_color", Color(rows[i].color).lightened(0.3))
	_fit()


func _fit() -> void:
	if _rows == null:
		return
	var w := clampf(size.x - 48.0, 220.0, 560.0)
	_scroll.custom_minimum_size.x = w
	# Title, hint, close button and padding take roughly 110 px.
	_scroll.custom_minimum_size.y = minf(_rows.get_combined_minimum_size().y, maxf(60.0, size.y - 150.0))


func toggle() -> void:
	visible = not visible
	if visible:
		_scroll.scroll_vertical = 0
