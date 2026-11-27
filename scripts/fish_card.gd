# Card for one fish: give it a name, see its stats, sell it.
# Opened by right-clicking (or double-clicking) a fish. The main scene fills in the stats.
# Sick fish get a Cure button; dead fish get Revive and Flush instead of Sell.
extends Control

signal sell_requested(fish)          # sell a living fish, or flush a dead one
signal action_requested(fish)        # use medicine: cure or revive

const MAX_NAME := 16

var fish = null
var _title: Label
var _name_edit: LineEdit
var _stats: Label
var _sell: Button
var _action: Button
# Widest the card may get (the main scene sets this from the window width).
var max_width := 440.0:
	set(v):
		max_width = v
		if _name_edit != null:
			_name_edit.custom_minimum_size.x = clampf(v - 140.0, 120.0, 220.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.35)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = "Name"
	row.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.max_length = MAX_NAME
	_name_edit.placeholder_text = "give it a name"
	_name_edit.custom_minimum_size.x = 220
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_t): close())
	row.add_child(_name_edit)
	vb.add_child(row)

	_stats = Label.new()
	vb.add_child(_stats)

	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 6)
	_action = Button.new()
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_color_override("font_color", Color("9dff9d"))
	_action.visible = false
	_action.pressed.connect(func(): action_requested.emit(fish))
	buttons.add_child(_action)
	_sell = Button.new()
	_sell.focus_mode = Control.FOCUS_NONE
	_sell.add_theme_color_override("font_color", Color("ff8a8a"))
	_sell.pressed.connect(func():
		var f = fish
		close()
		sell_requested.emit(f))
	buttons.add_child(_sell)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var done := Button.new()
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	buttons.add_child(done)
	vb.add_child(buttons)


func open(f, title: String, color: Color) -> void:
	fish = f
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_name_edit.text = f.nickname
	show()
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()


func _on_name_changed(t: String) -> void:
	if fish != null:
		fish.nickname = t.strip_edges()


# action_text "" hides the medicine button.
func update_stats(stats: String, sell_text: String, action_text := "", action_tip := "") -> void:
	_stats.text = stats
	_sell.text = sell_text
	_action.visible = action_text != ""
	_action.text = action_text
	_action.tooltip_text = action_tip


func close() -> void:
	_name_edit.release_focus()
	fish = null
	hide()
