# Settings overlay. Builds its own widgets and reports changes through
# signals; the main scene owns the actual settings and applies them.
extends Control

signal changed(key: String, value)
signal snap_requested(corner: String)      # "left" | "right"
signal reset_requested
signal closed

const LAYOUTS := ["auto", "full", "compact"]
const LAYOUT_NAMES := ["Auto (compact when small)", "Full", "Compact"]
const FPS := [15, 30, 60]
const FPS_NAMES := ["15  (battery saver)", "30", "60"]

var _borderless: CheckButton
var _on_top: CheckButton
var _transparent: CheckButton
var _layout: OptionButton
var _fps: OptionButton
var _reset_button: Button
var _reset_armed := 0.0
var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			closed.emit())
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_scroll.add_child(vb)
	_content = vb
	resized.connect(_fit)
	visibility_changed.connect(_fit)

	var title := Label.new()
	title.text = "-- settings --"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("5fb3d9"))
	vb.add_child(title)

	_borderless = _check(vb, "Borderless window", "No title bar. Drag the top bar to move, the corner grip to resize.", "borderless")
	_on_top = _check(vb, "Always on top", "Keep the tank above other windows.", "on_top")
	_transparent = _check(vb, "Transparent background (experimental)", "Only the tank shows; the desktop shows around it.", "transparent")

	_layout = _option(vb, "Layout", LAYOUT_NAMES)
	_layout.item_selected.connect(func(i): changed.emit("layout", LAYOUTS[i]))
	_fps = _option(vb, "Frame rate", FPS_NAMES)
	_fps.item_selected.connect(func(i): changed.emit("fps", FPS[i]))

	var snap := HBoxContainer.new()
	snap.add_theme_constant_override("separation", 6)
	var snap_label := Label.new()
	snap_label.text = "Snap widget to"
	snap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap.add_child(snap_label)
	snap.add_child(_button("bottom-left", func(): snap_requested.emit("left")))
	snap.add_child(_button("bottom-right", func(): snap_requested.emit("right")))
	vb.add_child(snap)

	var hint := Label.new()
	hint.text = "Esc  settings     S  shop (compact)     Alt+drag  move window"
	hint.add_theme_color_override("font_color", Color("4f7a96"))
	hint.add_theme_font_size_override("font_size", 13)
	vb.add_child(hint)

	var bottom := HBoxContainer.new()
	_reset_button = _button("Reset save...", _on_reset)
	_reset_button.add_theme_color_override("font_color", Color("ff8a8a"))
	bottom.add_child(_reset_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	bottom.add_child(_button("Close", func(): closed.emit()))
	vb.add_child(bottom)
	_fit.call_deferred()


func _process(dt: float) -> void:
	if _reset_armed > 0.0:
		_reset_armed -= dt
		if _reset_armed <= 0.0:
			_reset_button.text = "Reset save..."


# Scroll only when the window is too short for the whole panel.
func _fit() -> void:
	if _content == null:
		return
	var want := _content.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = min(want, max(80.0, size.y - 48.0))


# Show the current values without re-emitting change signals.
func sync(values: Dictionary) -> void:
	_borderless.set_pressed_no_signal(values.borderless)
	_on_top.set_pressed_no_signal(values.on_top)
	_transparent.set_pressed_no_signal(values.transparent)
	_layout.select(max(0, LAYOUTS.find(values.layout)))
	_fps.select(max(0, FPS.find(int(values.fps))))
	_reset_armed = 0.0
	_reset_button.text = "Reset save..."


func _on_reset() -> void:
	# Two clicks within a few seconds, so it can't happen by accident.
	if _reset_armed > 0.0:
		_reset_armed = 0.0
		_reset_button.text = "Reset save..."
		reset_requested.emit()
	else:
		_reset_armed = 4.0
		_reset_button.text = "Click again: erase ALL progress"


func _check(parent: Control, text: String, tip: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.tooltip_text = tip
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on): changed.emit(key, on))
	parent.add_child(c)
	return c


func _option(parent: Control, label: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for it in items:
		o.add_item(it)
	row.add_child(o)
	parent.add_child(row)
	return o


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
