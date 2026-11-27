# Root of the game: money, shop, upgrades, save/load, UI.
extends Control

const Data = preload("res://scripts/data.gd")
const TankScript = preload("res://scripts/tank.gd")
const SAVE_PATH := "user://fishy_save.json"
const AUTOSAVE_SECONDS := 30.0

var money := Data.START_MONEY
var lifetime := 0.0
var unlocked := 1                 # highest species index shown in the shop
var upgrades := {}

var font: SystemFont
var tank
var money_label: Label
var stats_label: Label
var info_label: Label
var pin_button: Button
var fish_buttons: Array = []
var upgrade_buttons := {}

var _msg := ""
var _msg_time := 0.0
var _refresh_t := 0.0
var _save_t := 0.0


func _ready() -> void:
	for k in Data.UPGRADES:
		upgrades[k] = 0
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Lucida Console", "Courier New", "monospace"])
	theme = _build_theme()
	_build_ui()
	if not _load_game():
		_apply_upgrades()
		tank.add_fish(0, 0, 0, 0.3)
		_say("Welcome! Click the water to drop food *. Click or drag over $ to collect. Right-click a fish to sell it.")
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()


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
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("bfe6ff"))
	th.set_color("font_hover_color", "Button", Color("ffffff"))
	th.set_color("font_pressed_color", "Button", Color("ffffff"))
	th.set_color("font_disabled_color", "Button", Color("4a5d70"))
	th.set_color("font_color", "Label", Color("9fc7e0"))
	return th


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("070b14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	# Top bar.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	vb.add_child(top)
	var title := Label.new()
	title.text = "><> fishy <><"
	title.add_theme_color_override("font_color", Color("5fb3d9"))
	top.add_child(title)
	money_label = Label.new()
	money_label.add_theme_color_override("font_color", Color("ffd84d"))
	money_label.add_theme_font_size_override("font_size", 18)
	top.add_child(money_label)
	stats_label = Label.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stats_label)
	pin_button = _make_button("[ pin on top ]", _toggle_pin)
	pin_button.tooltip_text = "Keep the tank above other windows."
	top.add_child(pin_button)
	top.add_child(_make_button("[ save ]", func(): _save_game(); _say("Saved.")))

	# Tank.
	tank = TankScript.new()
	tank.font = font
	tank.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tank.custom_minimum_size = Vector2(420, 260)
	tank.money_earned.connect(_on_money)
	tank.sell_requested.connect(_sell_fish)
	vb.add_child(tank)

	info_label = Label.new()
	info_label.custom_minimum_size.y = 22
	info_label.clip_text = true
	vb.add_child(info_label)

	# Shop.
	vb.add_child(_section_label("FISH"))
	var fish_flow := HFlowContainer.new()
	fish_flow.add_theme_constant_override("h_separation", 6)
	fish_flow.add_theme_constant_override("v_separation", 6)
	vb.add_child(fish_flow)
	for i in Data.SPECIES.size():
		var b := _make_button("", _buy_fish.bind(i))
		fish_flow.add_child(b)
		fish_buttons.append(b)

	vb.add_child(_section_label("UPGRADES"))
	var up_flow := HFlowContainer.new()
	up_flow.add_theme_constant_override("h_separation", 6)
	up_flow.add_theme_constant_override("v_separation", 6)
	vb.add_child(up_flow)
	for key in Data.UPGRADES:
		var b := _make_button("", _buy_upgrade.bind(key))
		b.tooltip_text = Data.UPGRADES[key].desc
		up_flow.add_child(b)
		upgrade_buttons[key] = b


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


func _toggle_pin() -> void:
	var w := get_window()
	w.always_on_top = not w.always_on_top
	pin_button.text = "[ unpin ]" if w.always_on_top else "[ pin on top ]"


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
		else:
			b.text = "%s  %s  $%s" % [sp.icon, sp.name, Data.fmt(cost)]
			b.tooltip_text = "%s: drops $%s every %ss. You own %d." % [
				sp.name, Data.fmt(sp.value), str(sp.interval), owned(i)]
			b.disabled = money < cost or full

	for key in upgrade_buttons:
		var b: Button = upgrade_buttons[key]
		var u: Dictionary = Data.UPGRADES[key]
		var lv: int = upgrades[key]
		if lv >= int(u.max):
			b.text = "%s  MAX" % u.name
			b.disabled = true
		else:
			var cost := Data.upgrade_cost(key, lv)
			var lv_txt := "" if int(u.max) == 1 else "  lv%d" % lv
			b.text = "%s%s  $%s" % [u.name, lv_txt, Data.fmt(cost)]
			b.disabled = money < cost


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
