# Root of the game: money, shop, upgrades, save/load, window + UI.
extends Control

const Data = preload("res://scripts/data.gd")
const TankScript = preload("res://scripts/tank.gd")
const Settings = preload("res://scripts/settings.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ResizeGrip = preload("res://scripts/resize_grip.gd")
const SAVE_PATH := "user://fishy_save.json"
const AUTOSAVE_SECONDS := 30.0
const WIDGET_SIZE := Vector2i(560, 360)
const MIN_WINDOW := Vector2i(360, 240)
# In "auto" layout the window switches to compact below this size.
const COMPACT_BELOW := Vector2(720, 470)

var money := Data.START_MONEY
var lifetime := 0.0
var unlocked := 1                 # highest species index shown in the shop
var upgrades := {}

var settings := Settings.new()
var font: SystemFont
var tank
var bg: ColorRect
var top_bar: PanelContainer
var title_label: Label
var money_label: Label
var stats_label: Label
var bar_spacer: Control
var info_label: Label
var pin_button: Button
var shop_button: Button
var min_button: Button
var close_button: Button
var main_vb: VBoxContainer
var shop_box: VBoxContainer      # fish + upgrade buttons; lives in main_vb or shop_popup
var shop_popup: PanelContainer
var settings_panel
var grip: Control
var fish_buttons: Array = []
var upgrade_buttons := {}
var compact := false

var _msg := ""
var _msg_time := 0.0
var _refresh_t := 0.0
var _save_t := 0.0
var _afford_normal: StyleBoxFlat
var _afford_hover: StyleBoxFlat


func _ready() -> void:
	for k in Data.UPGRADES:
		upgrades[k] = 0
	settings.load_file()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Lucida Console", "Courier New", "monospace"])
	theme = _build_theme()
	_build_ui()
	_restore_window()
	_apply_settings()
	resized.connect(_update_layout)
	if not _load_game():
		_apply_upgrades()
		tank.add_fish(0, 0, 0, 0.3)
		_say("Welcome! Click the water to drop food *. Click or drag over $ to collect. Right-click a fish to sell it. Esc for settings.")
	_refresh()


func _process(dt: float) -> void:
	_msg_time -= dt
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh()
	_save_t += dt
	if _save_t >= AUTOSAVE_SECONDS:
		_save_t = 0.0
		_save_game()
		_store_window()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()
		_store_window()


func _input(event: InputEvent) -> void:
	# Alt + drag anywhere moves the window (handy in compact/borderless mode).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed:
		get_window().start_drag()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		if shop_popup.visible:
			shop_popup.visible = false
		else:
			_toggle_settings()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S and compact and not settings_panel.visible:
		_toggle_shop()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- economy

func capacity() -> int:
	return 6 + 2 * int(upgrades.tank)


func coin_mult() -> float:
	return pow(1.25, upgrades.minerals) * (1.0 + 0.05 * upgrades.weed + 0.25 * upgrades.castle)


func owned(species: int) -> int:
	var n := 0
	for f in tank.fishes:
		if f.species == species:
			n += 1
	return n


func fish_cost(species: int) -> float:
	return floor(float(Data.SPECIES[species].cost) * pow(1.15, owned(species)))


func sell_value(f) -> float:
	return floor(float(Data.SPECIES[f.species].cost) * 0.4 * (1.0 + 0.5 * f.level))


func _apply_upgrades() -> void:
	tank.coin_mult = coin_mult()
	tank.feeder_level = upgrades.feeder
	tank.has_castle = upgrades.castle > 0
	tank.set_snails(upgrades.snail)
	tank.set_weeds(2 + upgrades.weed)


func _buy_fish(i: int) -> void:
	var cost := fish_cost(i)
	if i > unlocked or money < cost:
		return
	if tank.fishes.size() >= capacity():
		_say("The tank is full! Buy a bigger tank or sell a fish.")
		return
	money -= cost
	tank.add_fish(i, 0, 0, 0.3, true)
	unlocked = max(unlocked, min(i + 1, Data.SPECIES.size() - 1))
	_say("A new %s %s splashes in!" % [Data.SPECIES[i].name, Data.SPECIES[i].icon])
	_refresh()


func _buy_upgrade(key: String) -> void:
	var lv: int = upgrades[key]
	var u: Dictionary = Data.UPGRADES[key]
	if lv >= int(u.max):
		return
	var cost := Data.upgrade_cost(key, lv)
	if money < cost:
		return
	money -= cost
	upgrades[key] = lv + 1
	_apply_upgrades()
	_say("Bought %s (level %d)." % [u.name, lv + 1])
	_refresh()


func _sell_fish(f) -> void:
	if tank.fishes.size() <= 1:
		_say("You can't sell your last fish. It would get lonely.")
		return
	var v := sell_value(f)
	money += v
	tank.remove_fish(f)
	_say("Sold a %s for $%s." % [Data.SPECIES[f.species].name, Data.fmt(v)])
	_refresh()


func _on_money(amount: float) -> void:
	money += amount
	lifetime += amount


# ---------------------------------------------------------------- UI

func _build_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 15

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("0f1a2b")
	normal.border_color = Color("2b5876")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("16283f")
	hover.border_color = Color("5fb3d9")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1f3a57")
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("0a121e")
	disabled.border_color = Color("1a2a3a")
	for type in ["Button", "CheckButton", "OptionButton"]:
		th.set_stylebox("normal", type, normal)
		th.set_stylebox("hover", type, hover)
		th.set_stylebox("pressed", type, pressed)
		th.set_stylebox("hover_pressed", type, hover)
		th.set_stylebox("disabled", type, disabled)
		th.set_stylebox("focus", type, StyleBoxEmpty.new())
		th.set_color("font_color", type, Color("bfe6ff"))
		th.set_color("font_hover_color", type, Color("ffffff"))
		th.set_color("font_pressed_color", type, Color("ffffff"))
		th.set_color("font_hover_pressed_color", type, Color("ffffff"))
		th.set_color("font_disabled_color", type, Color("4a5d70"))
	th.set_color("font_color", "Label", Color("9fc7e0"))

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("0b1322")
	panel.border_color = Color("2b5876")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(14)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "PopupMenu", panel)
	th.set_stylebox("hover", "PopupMenu", hover)
	th.set_color("font_color", "PopupMenu", Color("bfe6ff"))
	th.set_color("font_hover_color", "PopupMenu", Color("ffffff"))
	th.set_color("font_color", "TooltipLabel", Color("bfe6ff"))
	th.set_stylebox("panel", "TooltipPanel", panel)

	# Buttons you can afford right now glow green.
	_afford_normal = normal.duplicate() as StyleBoxFlat
	_afford_normal.bg_color = Color("0f2a22")
	_afford_normal.border_color = Color("3fbf7f")
	_afford_hover = _afford_normal.duplicate() as StyleBoxFlat
	_afford_hover.bg_color = Color("16402f")
	_afford_hover.border_color = Color("7fffb0")
	return th


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = Color("070b14")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	main_vb = VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 6)
	margin.add_child(main_vb)

	# Top bar. Dragging it moves the window (needed when borderless).
	top_bar = PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color("0b1322")
	bar_style.set_corner_radius_all(3)
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 4
	bar_style.content_margin_top = 2
	bar_style.content_margin_bottom = 2
	top_bar.add_theme_stylebox_override("panel", bar_style)
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	top_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	top_bar.gui_input.connect(_on_top_bar_input)
	main_vb.add_child(top_bar)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top)
	title_label = Label.new()
	title_label.text = "><> fishy <><"
	title_label.add_theme_color_override("font_color", Color("5fb3d9"))
	top.add_child(title_label)
	money_label = Label.new()
	money_label.add_theme_color_override("font_color", Color("ffd84d"))
	money_label.add_theme_font_size_override("font_size", 18)
	top.add_child(money_label)
	stats_label = Label.new()
	stats_label.clip_text = true
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stats_label)
	# Fills the gap in compact mode, where the stats label is hidden.
	bar_spacer = Control.new()
	bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar_spacer)
	shop_button = _make_button("[ shop ]", _toggle_shop)
	shop_button.tooltip_text = "Open the shop (S)"
	top.add_child(shop_button)
	pin_button = _make_button("[ pin ]", func(): _set_setting("on_top", not settings.values.on_top))
	pin_button.tooltip_text = "Keep the tank above other windows."
	top.add_child(pin_button)
	var gear := _make_button("[ = ]", _toggle_settings)
	gear.tooltip_text = "Settings (Esc)"
	top.add_child(gear)
	min_button = _make_button("_", func(): get_window().mode = Window.MODE_MINIMIZED)
	min_button.tooltip_text = "Minimize"
	top.add_child(min_button)
	close_button = _make_button("x", _quit)
	close_button.tooltip_text = "Save and quit"
	top.add_child(close_button)

	# Tank.
	tank = TankScript.new()
	tank.font = font
	tank.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tank.custom_minimum_size = Vector2(300, 150)
	tank.money_earned.connect(_on_money)
	tank.sell_requested.connect(_sell_fish)
	main_vb.add_child(tank)

	info_label = Label.new()
	info_label.custom_minimum_size.y = 20
	info_label.clip_text = true
	main_vb.add_child(info_label)

	# Shop.
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 6)
	main_vb.add_child(shop_box)
	shop_box.add_child(_section_label("FISH"))
	var fish_flow := HFlowContainer.new()
	fish_flow.add_theme_constant_override("h_separation", 6)
	fish_flow.add_theme_constant_override("v_separation", 6)
	shop_box.add_child(fish_flow)
	for i in Data.SPECIES.size():
		var b := _make_button("", _buy_fish.bind(i))
		fish_flow.add_child(b)
		fish_buttons.append(b)

	shop_box.add_child(_section_label("UPGRADES"))
	var up_flow := HFlowContainer.new()
	up_flow.add_theme_constant_override("h_separation", 6)
	up_flow.add_theme_constant_override("v_separation", 6)
	shop_box.add_child(up_flow)
	for key in Data.UPGRADES:
		var b := _make_button("", _buy_upgrade.bind(key))
		b.tooltip_text = Data.UPGRADES[key].desc
		up_flow.add_child(b)
		upgrade_buttons[key] = b

	# Shop pop-up used in compact mode: covers the bottom of the tank.
	shop_popup = PanelContainer.new()
	shop_popup.anchor_left = 0.0
	shop_popup.anchor_right = 1.0
	shop_popup.anchor_top = 1.0
	shop_popup.anchor_bottom = 1.0
	shop_popup.offset_left = 8
	shop_popup.offset_right = -8
	shop_popup.offset_bottom = -8
	shop_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	shop_popup.visible = false
	add_child(shop_popup)

	grip = ResizeGrip.new()
	add_child(grip)

	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.changed.connect(_set_setting)
	settings_panel.snap_requested.connect(_snap_to_corner)
	settings_panel.reset_requested.connect(_reset_game)
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	add_child(settings_panel)


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = "-- " + text + " --"
	l.add_theme_color_override("font_color", Color("3a6b8a"))
	l.add_theme_font_size_override("font_size", 13)
	return l


func _toggle_shop() -> void:
	if compact:
		shop_popup.visible = not shop_popup.visible
		_refresh()


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		shop_popup.visible = false
		settings_panel.sync(settings.values)


# ---------------------------------------------------------------- window + settings

func _set_setting(key: String, value) -> void:
	settings.values[key] = value
	_apply_settings()
	settings.save_file()
	settings_panel.sync(settings.values)


func _apply_settings() -> void:
	var v: Dictionary = settings.values
	var w := get_window()
	w.min_size = MIN_WINDOW
	w.borderless = v.borderless
	w.always_on_top = v.on_top
	w.transparent = v.transparent
	get_viewport().transparent_bg = v.transparent
	bg.visible = not v.transparent
	tank.transparent_outside = v.transparent
	Engine.max_fps = int(v.fps)
	pin_button.text = "[ unpin ]" if v.on_top else "[ pin ]"
	grip.visible = v.borderless
	min_button.visible = v.borderless
	close_button.visible = v.borderless
	_update_layout()


func _update_layout() -> void:
	if shop_box == null:
		return
	var mode: String = settings.values.layout
	var want := mode == "compact" or (mode == "auto" and (size.x < COMPACT_BELOW.x or size.y < COMPACT_BELOW.y))
	title_label.visible = not want
	stats_label.visible = not want
	bar_spacer.visible = want
	shop_button.visible = want
	if want == compact:
		return
	compact = want
	shop_box.get_parent().remove_child(shop_box)
	if compact:
		shop_popup.add_child(shop_box)
	else:
		main_vb.add_child(shop_box)
		shop_popup.visible = false


func _on_top_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			# Double-click the bar to flip between full and compact.
			_set_setting("layout", "full" if compact else "compact")
		else:
			get_window().start_drag()
		accept_event()


func _snap_to_corner(corner: String) -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED
	var r := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.size = WIDGET_SIZE
	var y := r.end.y - WIDGET_SIZE.y - 12
	var x := r.end.x - WIDGET_SIZE.x - 12 if corner == "right" else r.position.x + 12
	w.position = Vector2i(x, y)
	_store_window()


func _restore_window() -> void:
	var v: Dictionary = settings.values
	var w := get_window()
	var sz := Vector2i(max(MIN_WINDOW.x, int(v.win_w)), max(MIN_WINDOW.y, int(v.win_h)))
	w.size = sz
	if int(v.win_x) < 0:
		return
	var rect := Rect2i(Vector2i(int(v.win_x), int(v.win_y)), sz)
	# Only restore the position if it is still on a connected screen.
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).intersects(rect):
			w.position = rect.position
			return


func _store_window() -> void:
	var w := get_window()
	if w.mode != Window.MODE_WINDOWED:
		return
	settings.values.win_x = w.position.x
	settings.values.win_y = w.position.y
	settings.values.win_w = w.size.x
	settings.values.win_h = w.size.y
	settings.save_file()


func _quit() -> void:
	_save_game()
	_store_window()
	get_tree().quit()


func _reset_game() -> void:
	money = Data.START_MONEY
	lifetime = 0.0
	unlocked = 1
	for k in upgrades:
		upgrades[k] = 0
	tank.reset()
	_apply_upgrades()
	tank.add_fish(0, 0, 0, 0.3, true)
	_save_game()
	settings_panel.visible = false
	_say("Fresh start! One guppy, $%d. Good luck." % int(Data.START_MONEY))
	_refresh()


func _say(text: String) -> void:
	_msg = text
	_msg_time = 6.0


func _refresh() -> void:
	if tank == null:
		return
	money_label.text = "$ " + Data.fmt(money)
	var rate: float = tank.estimate_rate()
	var rate_txt := "%.1f" % rate if rate < 100.0 else Data.fmt(rate)
	stats_label.text = "~$%s/s   fish %d/%d" % [rate_txt, tank.fishes.size(), capacity()]

	var f = tank.hovered
	if f != null:
		var sp: Dictionary = Data.SPECIES[f.species]
		var bars := int(round((1.0 - f.hunger) * 8.0))
		var lv_txt := "MAX" if f.level >= Data.MAX_LEVEL else "%d (xp %d/%d)" % [f.level, f.xp, Data.xp_needed(f.level)]
		info_label.text = "%s %s   lvl %s   food [%s%s]   $%s per coin   right-click: sell for $%s" % [
			sp.icon, sp.name, lv_txt, "#".repeat(bars), "-".repeat(8 - bars),
			Data.fmt(tank.fish_value(f)), Data.fmt(sell_value(f))]
		info_label.add_theme_color_override("font_color", sp.color)
	elif _msg_time > 0.0:
		info_label.text = _msg
		info_label.add_theme_color_override("font_color", Color("9fc7e0"))
	else:
		info_label.text = ""

	var full: bool = tank.fishes.size() >= capacity()
	for i in fish_buttons.size():
		var b: Button = fish_buttons[i]
		var sp: Dictionary = Data.SPECIES[i]
		var cost := fish_cost(i)
		if i > unlocked:
			b.text = "???  $" + Data.fmt(cost)
			b.tooltip_text = "Buy the previous fish to discover this one."
			b.disabled = true
			_mark_affordable(b)
		else:
			b.text = "%s  %s  $%s" % [sp.icon, sp.name, Data.fmt(cost)]
			b.tooltip_text = "%s: drops $%s every %ss. You own %d." % [
				sp.name, Data.fmt(sp.value), str(sp.interval), owned(i)]
			b.disabled = money < cost or full
			_mark_affordable(b)

	for key in upgrade_buttons:
		var b: Button = upgrade_buttons[key]
		var u: Dictionary = Data.UPGRADES[key]
		var lv: int = upgrades[key]
		if lv >= int(u.max):
			b.text = "%s  MAX" % u.name
			b.disabled = true
			_mark_affordable(b)
		else:
			var cost := Data.upgrade_cost(key, lv)
			var lv_txt := "" if int(u.max) == 1 else "  lv%d" % lv
			b.text = "%s%s  $%s" % [u.name, lv_txt, Data.fmt(cost)]
			b.disabled = money < cost
			_mark_affordable(b)


func _mark_affordable(b: Button) -> void:
	if b.disabled:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_stylebox_override("hover")
		b.remove_theme_color_override("font_color")
	else:
		b.add_theme_stylebox_override("normal", _afford_normal)
		b.add_theme_stylebox_override("hover", _afford_hover)
		b.add_theme_color_override("font_color", Color("b8ffd6"))


# ---------------------------------------------------------------- save / load

func _save_game() -> void:
	if tank == null:
		return
	var data := {
		"v": 1,
		"money": money,
		"lifetime": lifetime,
		"unlocked": unlocked,
		"upgrades": upgrades,
		"fish": tank.serialize_fish(),
		"time": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	money = float(d.get("money", Data.START_MONEY))
	lifetime = float(d.get("lifetime", 0.0))
	unlocked = clampi(int(d.get("unlocked", 1)), 1, Data.SPECIES.size() - 1)
	var ups = d.get("upgrades", {})
	if typeof(ups) == TYPE_DICTIONARY:
		for k in ups:
			if upgrades.has(k):
				upgrades[k] = clampi(int(ups[k]), 0, int(Data.UPGRADES[k].max))
	_apply_upgrades()
	var fish_list = d.get("fish", [])
	if typeof(fish_list) == TYPE_ARRAY:
		for fd in fish_list:
			var s := int(fd.get("s", 0))
			if s >= 0 and s < Data.SPECIES.size():
				tank.add_fish(s, clampi(int(fd.get("lv", 0)), 0, Data.MAX_LEVEL), int(fd.get("xp", 0)), float(fd.get("hg", 0.2)))
	if tank.fishes.is_empty():
		tank.add_fish(0, 0, 0, 0.3)

	var away := Time.get_unix_time_from_system() - float(d.get("time", Time.get_unix_time_from_system()))
	if away > 30.0:
		_offline_earnings(away)
	else:
		_say("Welcome back!")
	return true


func _offline_earnings(secs: float) -> void:
	secs = min(secs, Data.OFFLINE_CAP_SECONDS)
	# Without a snail most coins vanish before you get back.
	var collect := 0.85 if upgrades.snail > 0 else 0.15
	var earned := 0.0
	for f in tank.fishes:
		var active := secs
		if upgrades.feeder == 0:
			active = min(secs, max(0.0, (1.0 - f.hunger) * Data.HUNGER_TIME))
			f.hunger = min(1.0, f.hunger + secs / Data.HUNGER_TIME)
		earned += tank.fish_value(f) / float(Data.SPECIES[f.species].interval) * active
	earned = floor(earned * collect)
	money += earned
	lifetime += earned
	var tip := "" if upgrades.snail > 0 else "  (a snail would have saved more coins!)"
	_say("You were away %s. Your fish made $%s.%s" % [Data.fmt_time(secs), Data.fmt(earned), tip])
