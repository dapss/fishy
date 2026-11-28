# Pearls: spend them on perks, and move to a new tank for more.
# Opened with O or the "Pearls" button in the shop. The main scene
# supplies what to show (update()) while the card is open.
extends Control

signal perk_requested(key)
signal move_requested(kept)

var _title: Label
var _scroll: ScrollContainer
var _summary: Label
var _perk_box: VBoxContainer
var _perk_buttons := {}          # key -> Button
var _move_label: Label
var _keep_label: Label
var _keep_box: VBoxContainer
var _keep_buttons: Array = []    # reused between refreshes
var _keep_fish: Array = []       # the fish each visible keep button stands for
var _move_button: Button
var _confirm := false            # the move button was clicked once
var _can_move := false
var kept: Array = []             # fish picked to come along
var max_keep := 1


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
	_title.add_theme_color_override("font_color", Color("e8f4ff"))
	vb.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(inner)

	_summary = _wrap_label(Color("b8d8ee"))
	inner.add_child(_summary)
	inner.add_child(_section("PERKS  (they last forever)"))
	_perk_box = VBoxContainer.new()
	_perk_box.add_theme_constant_override("separation", 2)
	inner.add_child(_perk_box)

	inner.add_child(_section("MOVE TO A NEW TANK"))
	_move_label = _wrap_label(Color("b8d8ee"))
	inner.add_child(_move_label)
	_keep_label = _wrap_label(Color("8fb8d0"))
	inner.add_child(_keep_label)
	_keep_box = VBoxContainer.new()
	_keep_box.add_theme_constant_override("separation", 2)
	inner.add_child(_keep_box)
	_move_button = Button.new()
	_move_button.focus_mode = Control.FOCUS_NONE
	_move_button.pressed.connect(_on_move)
	inner.add_child(_move_button)

	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(hide)
	vb.add_child(close)

	resized.connect(_fit)
	visibility_changed.connect(func():
		_confirm = false
		if visible:
			_scroll.scroll_vertical = 0
		_fit())


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("5fb3d9"))
	return l


func _wrap_label(color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", color)
	return l


func _button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return b


# state: {title, summary, perks: [{key, text, tooltip, disabled}],
#         move_text, can_move, keep_text, candidates: [{fish, text, color}], max_keep}
func update(state: Dictionary) -> void:
	_title.text = state.title
	_summary.text = state.summary
	for p in state.perks:
		var b: Button = _perk_buttons.get(p.key)
		if b == null:
			b = _button()
			var key: String = p.key
			b.pressed.connect(func(): perk_requested.emit(key))
			_perk_box.add_child(b)
			_perk_buttons[key] = b
		b.text = p.text
		b.tooltip_text = p.tooltip
		b.disabled = p.disabled
	_move_label.text = state.move_text
	_can_move = state.can_move
	max_keep = int(state.max_keep)

	var cands: Array = state.candidates
	# Forget picks that aren't candidates any more (sold, died...).
	var live := cands.map(func(c): return c.fish)
	kept = kept.filter(func(f): return live.has(f))
	while kept.size() > max_keep:
		kept.pop_back()
	_keep_label.text = state.keep_text % [kept.size(), max_keep] if cands.size() > 0 else state.keep_text_none
	while _keep_buttons.size() < cands.size():
		var b := _button()
		var idx := _keep_buttons.size()
		b.pressed.connect(func(): _toggle_keep(idx))
		_keep_box.add_child(b)
		_keep_buttons.append(b)
	_keep_fish.clear()
	for i in _keep_buttons.size():
		var b: Button = _keep_buttons[i]
		b.visible = i < cands.size()
		if not b.visible:
			continue
		var f = cands[i].fish
		_keep_fish.append(f)
		var on := kept.has(f)
		b.text = ("[x] " if on else "[ ] ") + String(cands[i].text)
		var c: Color = cands[i].color
		b.add_theme_color_override("font_color", c if on else c.darkened(0.25))
		b.add_theme_color_override("font_hover_color", c.lightened(0.3))
	_move_button.disabled = not _can_move
	_move_button.text = "Sure? Click again to move" if _confirm and _can_move else String(state.move_button)
	_fit()


func _toggle_keep(idx: int) -> void:
	if idx >= _keep_fish.size():
		return
	var f = _keep_fish[idx]
	if kept.has(f):
		kept.erase(f)
	elif kept.size() < max_keep:
		kept.append(f)
	else:
		# Full: swap out the oldest pick.
		kept.pop_front()
		kept.append(f)
	_confirm = false


func _on_move() -> void:
	if not _can_move:
		return
	if not _confirm:
		_confirm = true
		_move_button.text = "Sure? Click again to move"
		return
	_confirm = false
	move_requested.emit(kept.duplicate())
	kept.clear()


func _fit() -> void:
	if _scroll == null:
		return
	var w := clampf(size.x - 48.0, 220.0, 520.0)
	_scroll.custom_minimum_size.x = w
	for l in [_summary, _move_label, _keep_label]:
		l.custom_minimum_size.x = w - 14.0
	var inner: Control = _scroll.get_child(0)
	# Title, close button and padding take roughly 90 px.
	_scroll.custom_minimum_size.y = minf(inner.get_combined_minimum_size().y, maxf(80.0, size.y - 90.0))


func toggle() -> void:
	visible = not visible
