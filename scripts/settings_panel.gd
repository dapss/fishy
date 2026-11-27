# Settings overlay. Builds its own widgets and reports changes through
# signals; the main scene owns the actual settings and applies them.
extends Control

signal changed(key: String, value)
signal snap_requested(corner: String)      # "left" | "right"
signal reset_requested
signal closed

const LAYOUTS := ["auto", "full", "compact"]
const LAYOUT_NAMES := ["Auto", "Full", "Compact"]
const FPS := [15, 30, 60]
const FPS_NAMES := ["15", "30", "60"]
const WIDGETS := ["tiny", "small", "normal"]
const WIDGET_NAMES := ["Tiny", "Small", "Normal"]
const SCALES := [0.8, 1.0, 1.25, 1.5]
const SCALE_NAMES := ["80%", "100%", "125%", "150%"]

var _borderless: CheckButton
var _on_top: CheckButton
var _transparent: CheckButton
var _layout: OptionButton
var _fps: OptionButton
var _scale: OptionButton
var _widget: OptionButton
var _volume: HSlider
var _volume_label: Label
var _eco: CheckButton
var _tray: CheckButton
var _reset_button: Button
var _reset_armed := 0.0
var _scroll: ScrollContainer
var _content: VBoxContainer
var _hint: Label


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
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(_scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_scroll.add_child(vb)
	_content = vb
	resized.connect(_fit)
	visibility_changed.connect(_fit)
	# Re-measure once wrapped text has settled on its real height.
	vb.minimum_size_changed.connect(_fit)

	var title := Label.new()
	title.text = "-- settings --"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("5fb3d9"))
	vb.add_child(title)

	_borderless = _check(vb, "Borderless window", "No title bar. Drag the top bar to move, the corner grip to resize.", "borderless")
	_on_top = _check(vb, "Always on top", "Keep the tank above other windows.", "on_top")
	_transparent = _check(vb, "Transparent background", "Experimental: only the tank shows; your desktop shows around it.", "transparent")

	_layout = _option(vb, "Layout", LAYOUT_NAMES)
	_layout.tooltip_text = "Auto switches to compact (pop-up shop) when the window is small."
	_layout.item_selected.connect(func(i): changed.emit("layout", LAYOUTS[i]))
	_fps = _option(vb, "Frame rate", FPS_NAMES)
	_fps.tooltip_text = "Frames per second. 15 saves the most battery."
	_fps.item_selected.connect(func(i): changed.emit("fps", FPS[i]))
	_scale = _option(vb, "Text size", SCALE_NAMES)
	_scale.tooltip_text = "Scales text, buttons and the tank together."
	_scale.item_selected.connect(func(i): changed.emit("ui_scale", SCALES[i]))

	var vol := HBoxContainer.new()
	vol.add_theme_constant_override("separation", 12)
	var vol_name := Label.new()
	vol_name.text = "Sound"
	vol_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.add_child(vol_name)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 5
	_volume.custom_minimum_size.x = 110
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.value_changed.connect(func(v):
		_volume_label.text = _vol_text(v)
		changed.emit("volume", int(v)))
	vol.add_child(_volume)
	_volume_label = Label.new()
	_volume_label.custom_minimum_size.x = 48
	vol.add_child(_volume_label)
	vb.add_child(vol)

	_eco = _check(vb, "Battery saver", "Drop to 10 FPS while you're using another window.", "eco")
	_tray = _check(vb, "Keep running when closed", "Closing minimizes instead of quitting, so your fish keep earning. Quit from the tray icon menu.", "tray")

	_widget = _option(vb, "Widget size", WIDGET_NAMES)
	_widget.tooltip_text = "Tiny 360x240, Small 460x300, Normal 560x360.\nResizes the window now (keeping it in its corner) and is used by the snap buttons."
	_widget.item_selected.connect(func(i): changed.emit("widget", WIDGETS[i]))

	var snap := HBoxContainer.new()
	snap.add_theme_constant_override("separation", 6)
	var snap_label := Label.new()
	snap_label.text = "Snap to"
	snap_label.tooltip_text = "Move the widget to a bottom corner, just above the taskbar."
	snap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snap.add_child(snap_label)
	snap.add_child(_button("left", func(): snap_requested.emit("left")))
	snap.add_child(_button("right", func(): snap_requested.emit("right")))
	vb.add_child(snap)

	var hint := Label.new()
	_hint = hint
	hint.text = ("Esc settings · S shop · 1-6 buy fish · F feed · Space collect all · "
		+ "M mute · Ctrl+Z undo sell · Alt+drag move · double-click a fish to name it")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


# Size the panel to its content, but never bigger than the window:
# it scrolls when the window is too short (or, rarely, too narrow).
func _fit() -> void:
	if _content == null:
		return
	var want := _content.get_combined_minimum_size()
	var max_w := maxf(200.0, size.x - 48.0)
	var w := minf(maxf(want.x, 380.0), max_w)
	_scroll.custom_minimum_size.x = w
	_content.custom_minimum_size.x = w - 14.0   # room for the scrollbar
	# A wrapping label only knows its height once it knows its width.
	_hint.custom_minimum_size.x = w - 14.0
	_scroll.custom_minimum_size.y = minf(_content.get_combined_minimum_size().y, maxf(80.0, size.y - 48.0))


# Show the current values without re-emitting change signals.
func sync(values: Dictionary) -> void:
	_borderless.set_pressed_no_signal(values.borderless)
	_on_top.set_pressed_no_signal(values.on_top)
	_transparent.set_pressed_no_signal(values.transparent)
	_layout.select(max(0, LAYOUTS.find(values.layout)))
	_fps.select(max(0, FPS.find(int(values.fps))))
	var si := 1
	for i in SCALES.size():
		if is_equal_approx(SCALES[i], float(values.ui_scale)):
			si = i
	_scale.select(si)
	_widget.select(max(0, WIDGETS.find(values.widget)))
	_volume.set_value_no_signal(int(values.volume))
	_volume_label.text = _vol_text(int(values.volume))
	_eco.set_pressed_no_signal(values.eco)
	_tray.set_pressed_no_signal(values.tray)
	_reset_armed = 0.0
	_reset_button.text = "Reset save..."


func _vol_text(v) -> String:
	return "off" if int(v) == 0 else "%d%%" % int(v)


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
