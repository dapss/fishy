# Root of the game: money, shop, upgrades, save/load, window + UI.
extends Control

const Data = preload("res://scripts/data.gd")
const TankScript = preload("res://scripts/tank.gd")
const Settings = preload("res://scripts/settings.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const ResizeGrip = preload("res://scripts/resize_grip.gd")
const Audio = preload("res://scripts/audio.gd")
const FishCard = preload("res://scripts/fish_card.gd")
const InfoCard = preload("res://scripts/info_card.gd")
const HelpCard = preload("res://scripts/help_card.gd")
const FishList = preload("res://scripts/fish_list.gd")
const Updater = preload("res://scripts/updater.gd")
const UpdateCard = preload("res://scripts/update_card.gd")
const Changelog = preload("res://scripts/changelog.gd")
const BACKUP_DIR := "user://backups"
const BACKUP_KEEP := 10
const BACKUP_EVERY := 900.0        # seconds between automatic backups
const RUN_KEY := "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const SAVE_PATH := "user://fishy_save.json"
const AUTOSAVE_SECONDS := 30.0
const WIDGET_SIZES := {
	"tiny": Vector2i(360, 240),
	"small": Vector2i(460, 300),
	"normal": Vector2i(560, 360),
}
const MIN_WINDOW := Vector2i(360, 240)
# In "auto" layout the window switches to compact below this size (x UI scale).
const COMPACT_BELOW := Vector2(720, 470)
const ECO_FPS := 10
const HIDDEN_FPS := 5
const DRAG_FPS := 60
# Dragging the window within this many pixels of a screen edge snaps it flush.
const SNAP_PX := 24
const UNDO_SECONDS := 8.0
# First-time tips, checked in this order; each is shown once per save.
const TIP_ORDER := ["coin", "food", "buy", "snail", "name", "settings", "dirt"]
const MAX_MEDICINE := 99

var money := Data.START_MONEY
var lifetime := 0.0
var unlocked := 1                 # highest species index shown in the shop
var upgrades := {}
var tips_seen := {}
var stats := {}
var medicine := 0                 # Fish Medicine in stock
var _save_predates_dirt := false         # true when the save predates dirty tanks

var settings := Settings.new()
var audio
var font: SystemFont
var tank
var bg: ColorRect
var top_bar: PanelContainer
var title_label: Label
var money_label: Label
var stats_label: Label
var goal_label: Label
var bar_spacer: Control
var top_row: HBoxContainer
var outer_margin: MarginContainer
var settings_button: Button
var shop_scroll: ScrollContainer   # holds the shop inside the compact pop-up
var _compact_btn := {}              # tighter button styles for the compact top bar
var info_label: Label
var undo_button: Button
var clean_button: Button
var medicine_button: Button
var _dirt_stage := 0              # last warned dirt stage (0 ok, 1 dirty, 2 sick, 3 filthy)
var pin_button: Button
var shop_button: Button
var min_button: Button
var close_button: Button
var main_vb: VBoxContainer
var shop_box: VBoxContainer      # fish + upgrade buttons; lives in main_vb or shop_popup
var shop_popup: PanelContainer
var settings_panel
var fish_card
var info_card
var help_card
var updater
var update_card
var _manual_update_check := false
var _card_queue: Array = []       # info cards waiting for the one on screen to close
var help_button: Button
var fish_list
var fish_list_button: Button
var fish_section_label: Label
var tip_box: PanelContainer
var tip_label: Label
var tray: StatusIndicator
var tray_menu: PopupMenu
var grip: Control
var fish_buttons: Array = []
var upgrade_buttons := {}
var compact := false

var _msg := ""
var _msg_time := 0.0
var _refresh_t := 0.0
var _save_t := 0.0
var _play_time := 0.0
var _focused := true
var _dragging := false
var _drag_grab := Vector2i.ZERO   # mouse position relative to the window's outer corner
var _undo := {}
var _undo_time := 0.0
var _tip_time := 0.0
var _tip_cooldown := 3.0
var _prev_volume := 60
var _backup_t := 0.0
var _afford_normal: StyleBoxFlat
var _afford_hover: StyleBoxFlat
var _afford_tight := {}            # the same, with compact padding
var _floating_labels: Array = []   # labels that need a backing when transparent
var _section_labels: Array = []
var _label_backing: StyleBoxFlat


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)   # closing may hide to the tray instead
	for k in Data.UPGRADES:
		upgrades[k] = 0
	settings.load_file()
	settings.values.autostart = _autostart_enabled()
	stats = _default_stats()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Lucida Console", "Courier New", "monospace"])
	theme = _build_theme()
	audio = Audio.new()
	add_child(audio)
	_build_ui()
	_build_tray()
	_set_food_cursor()
	# Borderless first: Windows keeps the outer size when the frame is
	# removed, so sizing before that would make the inside grow.
	resized.connect(_update_layout)
	_apply_settings()
	_restore_window()
	_update_layout.call_deferred()
	var returning := _load_game()
	if not returning:
		_apply_upgrades()
		tank.add_fish(0, 0, 0, 0.3)
		_say("Welcome! Click the water to feed your fish. Esc for settings.")
	_backup_save("start")
	_refresh()
	updater.cleanup()
	_refresh_autostart_path()
	_check_whats_new(returning)
	if settings.values.update_check and OS.has_feature("template"):
		get_tree().create_timer(4.0 if not OS.is_debug_build() else 1.0).timeout.connect(func(): _check_for_update(false))


func _process(dt: float) -> void:
	_play_time += dt
	stats.play_seconds += dt
	stats.best_money = maxf(stats.best_money, money)
	_backup_t += dt
	if _backup_t >= BACKUP_EVERY:
		_backup_t = 0.0
		_save_game()
		_backup_save("auto")
	_msg_time -= dt
	_undo_time -= dt
	_tip_cooldown -= dt
	if tip_box.visible:
		_tip_time -= dt
		if _tip_time <= 0.0:
			_hide_tip()
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_check_dirt_stage()
		_refresh()
		_check_tips()
	_save_t += dt
	if _dragging:
		_drag_step()
	if _save_t >= AUTOSAVE_SECONDS:
		_save_t = 0.0
		_save_game()
		_store_window()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_game()
			_store_window()
			if settings.values.tray:
				_hide_to_tray()
			else:
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			_save_game()
			_store_window()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_apply_fps()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_apply_fps()


func _exit_tree() -> void:
	# Release the custom cursor texture before the renderer shuts down.
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CAN_DROP)


func _input(event: InputEvent) -> void:
	if _dragging and event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag()
	# Alt + drag anywhere moves the window (handy in compact/borderless mode).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed:
		_begin_drag()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.keycode
	var handled := true
	if k == KEY_ESCAPE:
		if tank.clean_mode and not (help_card.visible or fish_list.visible or fish_card.visible or info_card.visible or settings_panel.visible):
			_toggle_clean()
		elif help_card.visible:
			help_card.hide()
		elif fish_list.visible:
			fish_list.hide()
		elif fish_card.visible:
			fish_card.close()
		elif info_card.visible:
			info_card.hide()
		elif shop_popup.visible:
			shop_popup.visible = false
		else:
			_toggle_settings()
	elif k == KEY_F1 or event.unicode == 63:      # F1 or "?"
		_toggle_help()
	elif settings_panel.visible or fish_card.visible or info_card.visible or help_card.visible or fish_list.visible or update_card.visible:
		handled = false
	elif k == KEY_Z and event.ctrl_pressed:
		_undo_sell()
	elif k == KEY_S and compact:
		_toggle_shop()
	elif k >= KEY_1 and k <= KEY_6:
		_buy_fish(k - KEY_1)
	elif k == KEY_F:
		_feed_key()
	elif k == KEY_W:
		_toggle_clean()
	elif k == KEY_SPACE:
		if tank.collect_all() == 0:
			_say("No coins to collect right now.")
	elif k == KEY_M:
		_toggle_mute()
	elif k == KEY_L:
		_toggle_fish_list()
	elif k == KEY_P:
		_set_setting("on_top", not settings.values.on_top)
		_say("Pinned on top." if settings.values.on_top else "Unpinned.")
	elif k == KEY_C:
		_set_setting("layout", "full" if compact else "compact")
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# F drops a pellet above every hungry fish. If nobody is hungry, it drops
# one at the mouse (or somewhere at the top) like a click would.
func _feed_key() -> void:
	var fed := 0
	for f in tank.fishes:
		if f.hunger > 0.35 and fed < 12 and not f.dead:
			tank.drop_food(Vector2(f.pos.x + f.w * 0.5, maxf(2.0, f.pos.y - 1.0)))
			fed += 1
	if fed == 0:
		if tank.mouse_in_tank():
			tank.drop_food(tank.mouse_cell - Vector2(0.5, 0.5))
		else:
			tank.drop_food(Vector2(randf_range(2.0, tank.cols - 3.0), 2.0))
		fed = 1
	else:
		_say("Fed %d hungry fish." % fed if fed > 1 else "Fed a hungry fish.")
	stats.food += fed
	audio.play("food")


func _toggle_mute() -> void:
	if int(settings.values.volume) > 0:
		_prev_volume = int(settings.values.volume)
		_set_setting("volume", 0)
		_say("Sound off (M to turn it back on).")
	else:
		_set_setting("volume", max(10, _prev_volume))
		_say("Sound on.")


# ---------------------------------------------------------------- economy

func capacity() -> int:
	return 6 + 2 * int(upgrades.tank)


func coin_mult(ups := upgrades) -> float:
	return pow(1.25, ups.minerals) * (1.0 + 0.05 * ups.weed + 0.25 * ups.castle)


func owned(species: int) -> int:
	var n := 0
	for f in tank.fishes:
		if f.species == species and not f.dead:
			n += 1
	return n


func fish_cost(species: int) -> float:
	return floor(float(Data.SPECIES[species].cost) * pow(1.15, owned(species)))


func sell_value(f) -> float:
	return floor(float(Data.SPECIES[f.species].cost) * 0.4 * (1.0 + 0.5 * f.level))


func fish_title(f) -> String:
	var species: String = Data.SPECIES[f.species].name
	return species if f.nickname == "" else "%s the %s" % [f.nickname, species]


func _apply_upgrades() -> void:
	tank.coin_mult = coin_mult()
	tank.feeder_level = upgrades.feeder
	tank.has_castle = upgrades.castle > 0
	tank.set_snails(upgrades.snail)
	tank.set_weeds(2 + upgrades.weed)
	tank.set_plecos(upgrades.pleco)
	tank.dirt_rate_mult = 1.0 - Data.dirt_slowdown(upgrades)


# Hold Shift to buy as many as you can afford (and have room for).
func _buy_fish(i: int) -> void:
	if i < 0 or i >= Data.SPECIES.size() or i > unlocked:
		return
	var many := Input.is_key_pressed(KEY_SHIFT)
	var n := 0
	while true:
		var cost := fish_cost(i)
		if money < cost:
			break
		if tank.fishes.size() >= capacity():
			if n == 0:
				_say("The tank is full! Buy a bigger tank or sell a fish.")
			break
		money -= cost
		tank.add_fish(i, 0, 0, 0.3, true)
		n += 1
		if not many:
			break
	if n == 0:
		return
	unlocked = max(unlocked, min(i + 1, Data.SPECIES.size() - 1))
	stats.fish_bought += n
	audio.play("buy")
	var sp: Dictionary = Data.SPECIES[i]
	if n == 1:
		_say("A new %s %s splashes in!" % [sp.name, sp.icon])
	else:
		_say("%d new %s %s splash in!" % [n, sp.name, sp.icon])
	_save_game()
	_refresh()


func _buy_upgrade(key: String) -> void:
	var u: Dictionary = Data.UPGRADES[key]
	var many := Input.is_key_pressed(KEY_SHIFT)
	var n := 0
	while int(upgrades[key]) < int(u.max):
		var cost := Data.upgrade_cost(key, upgrades[key])
		if money < cost:
			break
		money -= cost
		upgrades[key] += 1
		n += 1
		if not many:
			break
	if n == 0:
		return
	_apply_upgrades()
	audio.play("buy")
	if n == 1:
		_say("Bought %s (level %d)." % [u.name, upgrades[key]])
	else:
		_say("Bought %d levels of %s (now level %d)." % [n, u.name, upgrades[key]])
	_save_game()
	_refresh()


func _sell_fish(f) -> void:
	if f == null or not tank.fishes.has(f):
		return
	if f.dead:
		_flush_fish(f)
		return
	if tank.living() <= 1:
		_say("You can't sell your last fish. It would get lonely.")
		return
	var v := sell_value(f)
	# Remember the fish so a misclick can be undone.
	_undo = {"s": f.species, "lv": f.level, "xp": f.xp, "hg": f.hunger,
		"n": f.nickname, "pos": f.pos, "value": v, "title": fish_title(f)}
	_undo_time = UNDO_SECONDS
	money += v
	stats.fish_sold += 1
	tank.remove_fish(f)
	audio.play("sell")
	_say("Sold %s for $%s." % [fish_title(f), Data.fmt(v)])
	_save_game()
	_refresh()


# Down the toilet: gone for good, with a small refund (none for bones).
func _flush_fish(f) -> void:
	var refund := 0.0 if f.skeleton else floorf(sell_value(f) * Data.FLUSH_REFUND)
	money += refund
	stats.fish_flushed += 1
	tank.remove_fish(f)
	tank._popup("~@~ flush ~@~", f.pos + Vector2(f.w * 0.5, 0.0), Color("5fb3d9"))
	audio.play("flush")
	if refund > 0.0:
		_say("Flushed %s. Got $%s back." % [fish_title(f), Data.fmt(refund)])
	else:
		_say("Flushed what was left of %s." % fish_title(f))
	_save_game()
	_refresh()


# ---------------------------------------------------------------- medicine

# About a third of the price of the best fish you keep, so it always stings.
func medicine_cost() -> float:
	var best := 0
	for f in tank.fishes:
		best = maxi(best, f.species)
	return maxf(25.0, floor(float(Data.SPECIES[best].cost) / 3.0))


func _buy_medicine() -> void:
	var many := Input.is_key_pressed(KEY_SHIFT)
	var n := 0
	while medicine < MAX_MEDICINE and money >= medicine_cost():
		money -= medicine_cost()
		medicine += 1
		n += 1
		if not many:
			break
	if n == 0:
		return
	audio.play("buy")
	_say("Bought %s. You have %d." % ["a Fish Medicine" if n == 1 else "%d Fish Medicines" % n, medicine])
	_save_game()
	_refresh()


# Medicine on a fish: revives a dead one, cures a sick one. Buys one on
# the spot if you have none but can afford it.
func _use_medicine(f) -> void:
	if f == null or not tank.fishes.has(f):
		return
	if f.dead and f.skeleton:
		_say("Too late for medicine. All you can do is flush it.")
		return
	if not f.dead and not f.sick:
		return
	if f.dead and tank.dirt_level() >= Data.SICK_AT:
		_say("Clean the tank below %d%% first, or it'll just die again (W to clean)." % int(Data.SICK_AT * 100))
		audio.play("warn")
		return
	if medicine <= 0:
		if money < medicine_cost():
			_say("You need Fish Medicine ($%s) from the shop." % Data.fmt(medicine_cost()))
			return
		money -= medicine_cost()
		medicine += 1
	medicine -= 1
	if f.dead:
		tank.revive(f)
		stats.fish_revived += 1
		_say("%s is back! It's weak for a minute and lost a level." % fish_title(f))
	else:
		tank.cure(f)
		if tank.dirt_level() >= Data.SICK_AT:
			_say("%s is cured, but it'll get sick again unless you clean the tank." % fish_title(f))
		else:
			_say("%s is cured." % fish_title(f))
	_save_game()
	_refresh()


func _on_fish_died(f) -> void:
	stats.fish_died += 1
	_say("%s died from the dirty water! Right-click it: revive within %d min, or flush it." % [
		fish_title(f), int(Data.REVIVE_WINDOW / 60.0)])
	_save_game()


func _on_spotless() -> void:
	stats.spotless += 1
	_say("Sparkling clean! +25%% coins for %d minutes." % int(Data.SPARKLE_TIME / 60.0))
	_save_game()


func _toggle_clean() -> void:
	if not settings.values.dirt:
		_say("Dirt is turned off in settings.")
		return
	tank.set_clean_mode(not tank.clean_mode)
	shop_popup.visible = false
	if tank.clean_mode:
		_say("Hold left and scrub slowly. Right-click rinses the sponge. W or Esc when done.")
	else:
		_say("Done cleaning. The tank is %d%% dirty." % int(round(tank.dirt_level() * 100.0)))
	_refresh()


# Warn once each time the tank gets into a worse stage.
func _check_dirt_stage() -> void:
	var lv: float = tank.dirt_level()
	var stage := 0
	if lv >= Data.FILTHY_AT:
		stage = 3
	elif lv >= Data.SICK_AT:
		stage = 2
	elif lv >= Data.DIRTY_AT:
		stage = 1
	if stage > _dirt_stage:
		if stage >= 2:
			audio.play("warn")
		if stage == 2:
			_say("The water is making your fish sick! Press W to clean the tank.")
		elif stage == 3:
			_say("The tank is filthy: sick fish are losing levels. Clean it (W)!")
	# A little slack so hovering around a threshold doesn't nag.
	if stage > _dirt_stage or lv < [0.0, Data.DIRTY_AT, Data.SICK_AT, Data.FILTHY_AT][_dirt_stage] - 0.05:
		_dirt_stage = stage


func _undo_sell() -> void:
	if _undo.is_empty() or _undo_time <= 0.0:
		return
	if money < _undo.value:
		_say("Can't undo: you've already spent that money.")
		return
	if tank.fishes.size() >= capacity():
		_say("Can't undo: the tank is full.")
		return
	money -= _undo.value
	stats.fish_sold -= 1
	var f = tank.add_fish(_undo.s, _undo.lv, _undo.xp, _undo.hg)
	f.nickname = _undo.n
	f.pos = _undo.pos
	f.target = _undo.pos
	_say("%s is back!" % _undo.title)
	_undo = {}
	_undo_time = 0.0
	audio.play("buy")
	_save_game()
	_refresh()


func _on_money(amount: float, coins: int, by_snail: bool) -> void:
	money += amount
	lifetime += amount
	if by_snail:
		stats.earned_snails += amount
		stats.coins_snails += coins
	else:
		stats.earned_you += amount
		stats.coins_you += coins


# What to save up for: the cheapest thing in the shop you can't afford yet.
func _next_goal() -> Dictionary:
	var best := {}
	if tank.fishes.size() < capacity():
		for i in range(min(unlocked, Data.SPECIES.size() - 1) + 1):
			var c := fish_cost(i)
			if c > money and (best.is_empty() or c < best.cost):
				best = {"name": Data.SPECIES[i].name, "cost": c}
	for key in Data.UPGRADES:
		if upgrades[key] < int(Data.UPGRADES[key].max):
			var c := Data.upgrade_cost(key, upgrades[key])
			if c > money and (best.is_empty() or c < best.cost):
				best = {"name": String(Data.UPGRADES[key].name).split(" ")[0], "cost": c}
	return best


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

	var edit := disabled.duplicate() as StyleBoxFlat
	edit.border_color = Color("2b5876")
	var edit_focus := edit.duplicate() as StyleBoxFlat
	edit_focus.border_color = Color("5fb3d9")
	th.set_stylebox("normal", "LineEdit", edit)
	th.set_stylebox("focus", "LineEdit", edit_focus)
	th.set_color("font_color", "LineEdit", Color("ffffff"))
	th.set_color("font_placeholder_color", "LineEdit", Color("4a5d70"))
	th.set_color("caret_color", "LineEdit", Color("5fb3d9"))

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

	_label_backing = StyleBoxFlat.new()
	_label_backing.bg_color = Color("0b1322")
	_label_backing.set_corner_radius_all(3)
	_label_backing.content_margin_left = 8
	_label_backing.content_margin_right = 8

	# Buttons you can afford right now glow green.
	_afford_normal = normal.duplicate() as StyleBoxFlat
	_afford_normal.bg_color = Color("0f2a22")
	_afford_normal.border_color = Color("3fbf7f")
	_afford_hover = _afford_normal.duplicate() as StyleBoxFlat
	_afford_hover.bg_color = Color("16402f")
	_afford_hover.border_color = Color("7fffb0")

	for state in ["normal", "hover"]:
		var a := (_afford_normal if state == "normal" else _afford_hover).duplicate() as StyleBoxFlat
		a.content_margin_left = 5
		a.content_margin_right = 5
		a.content_margin_top = 2
		a.content_margin_bottom = 2
		_afford_tight[state] = a
	for state in ["normal", "hover", "pressed", "disabled"]:
		var src: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}[state]
		var tight := src.duplicate() as StyleBoxFlat
		tight.content_margin_left = 5
		tight.content_margin_right = 5
		tight.content_margin_top = 2
		tight.content_margin_bottom = 2
		_compact_btn[state] = tight
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
	outer_margin = margin
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
	top_row = top
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top)
	title_label = Label.new()
	title_label.text = "><> fishy <><"
	title_label.add_theme_color_override("font_color", Color("5fb3d9"))
	top.add_child(title_label)
	money_label = Label.new()
	money_label.add_theme_color_override("font_color", Color("ffd84d"))
	top.add_child(money_label)
	stats_label = Label.new()
	stats_label.clip_text = true
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stats_label)
	goal_label = Label.new()
	goal_label.add_theme_color_override("font_color", Color("7fcf9f"))
	goal_label.tooltip_text = "The cheapest thing in the shop you can't afford yet."
	goal_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(goal_label)
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
	help_button = _make_button("[ ? ]", _toggle_help)
	help_button.tooltip_text = "Help (F1)"
	top.add_child(help_button)
	settings_button = _make_button("[ = ]", _toggle_settings)
	settings_button.tooltip_text = "Settings (Esc)"
	top.add_child(settings_button)
	min_button = _make_button("_", _minimize)
	min_button.tooltip_text = "Minimize"
	top.add_child(min_button)
	close_button = _make_button("x", _close_pressed)
	close_button.tooltip_text = "Save and quit"
	top.add_child(close_button)

	# Tank.
	tank = TankScript.new()
	tank.font = font
	tank.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tank.custom_minimum_size = Vector2(200, 90)
	tank.money_earned.connect(_on_money)
	tank.fish_opened.connect(_open_fish_card)
	tank.fish_died.connect(_on_fish_died)
	tank.spotless.connect(_on_spotless)
	# Snail pickups are quieter and rate-limited so they don't get annoying.
	tank.sfx.connect(func(sound, gain): audio.play(sound, gain, 140 if gain < 0.5 else 45))
	main_vb.add_child(tank)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	main_vb.add_child(info_row)
	info_label = Label.new()
	info_label.custom_minimum_size.y = 20
	info_label.clip_text = true
	info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floating_labels.append(info_label)
	info_row.add_child(info_label)
	undo_button = _make_button("[ undo sell ]", _undo_sell)
	undo_button.tooltip_text = "Get the fish back (Ctrl+Z)"
	undo_button.visible = false
	info_row.add_child(undo_button)
	clean_button = _make_button("[ clean ]", _toggle_clean)
	clean_button.tooltip_text = "Clean mode (W): hold left and scrub the glass.\nSlow strokes clean best. Right-click rinses the sponge."
	info_row.add_child(clean_button)

	# Shop.
	shop_box = VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 6)
	# Fill the pop-up's width so the flow rows put several buttons side by side.
	shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vb.add_child(shop_box)
	# A flow container, so the button drops under the label in narrow windows.
	var fish_head := HFlowContainer.new()
	fish_head.add_theme_constant_override("h_separation", 6)
	fish_head.add_theme_constant_override("v_separation", 4)
	fish_section_label = _section_label("FISH  (keys 1-6, Shift = buy max)")
	fish_section_label.tooltip_text = "Keys 1-6 buy fish. Hold Shift to buy as many as you can afford."
	fish_section_label.mouse_filter = Control.MOUSE_FILTER_PASS
	fish_head.add_child(fish_section_label)
	var head_space := Control.new()
	head_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fish_head.add_child(head_space)
	fish_list_button = _make_button("Fish list (L)", _toggle_fish_list)
	fish_list_button.tooltip_text = "Every fish in your tank, with level and hunger."
	fish_head.add_child(fish_list_button)
	shop_box.add_child(fish_head)
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
		up_flow.add_child(b)
		upgrade_buttons[key] = b
	medicine_button = _make_button("", _buy_medicine)
	up_flow.add_child(medicine_button)

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
	shop_scroll = ScrollContainer.new()
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_popup.add_child(shop_scroll)

	# First-time tip bubble, just under the top bar.
	tip_box = PanelContainer.new()
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color("0f2a22")
	tip_style.border_color = Color("3fbf7f")
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(4)
	tip_style.set_content_margin_all(10)
	tip_box.add_theme_stylebox_override("panel", tip_style)
	tip_box.anchor_left = 0.5
	tip_box.anchor_right = 0.5
	tip_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tip_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tip_box.tooltip_text = "Click to dismiss"
	tip_box.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_hide_tip())
	tip_box.visible = false
	add_child(tip_box)
	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_color_override("font_color", Color("b8ffd6"))
	tip_box.add_child(tip_label)

	grip = ResizeGrip.new()
	add_child(grip)

	fish_card = FishCard.new()
	fish_card.sell_requested.connect(_sell_fish)
	fish_card.action_requested.connect(_use_medicine)
	add_child(fish_card)

	info_card = InfoCard.new()
	info_card.visibility_changed.connect(_next_card)
	add_child(info_card)

	fish_list = FishList.new()
	fish_list.fish_selected.connect(func(f):
		fish_list.hide()
		_open_fish_card(f))
	add_child(fish_list)

	help_card = HelpCard.new()
	help_card.tips_reset_requested.connect(_reset_tips)
	help_card.whats_new_requested.connect(func():
		_queue_card("-- what's new --", Changelog.text_since("", 3), "Close", true))
	add_child(help_card)

	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.changed.connect(_set_setting)
	settings_panel.snap_requested.connect(_snap_to_corner)
	settings_panel.reset_requested.connect(_reset_game)
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	settings_panel.help_requested.connect(_toggle_help)
	settings_panel.stats_requested.connect(_show_stats)
	settings_panel.export_requested.connect(func(): _open_save_dialog(true))
	settings_panel.import_requested.connect(func(): _open_save_dialog(false))
	settings_panel.backups_requested.connect(_open_backups)
	settings_panel.update_check_requested.connect(func(): _check_for_update(true))
	add_child(settings_panel)

	updater = Updater.new()
	updater.update_found.connect(_on_update_found)
	updater.up_to_date.connect(func(v):
		if _manual_update_check:
			_say("You have the latest version (v%s)." % v))
	updater.check_failed.connect(func(reason):
		if _manual_update_check:
			_say("Couldn't check for updates (%s)." % reason))
	updater.download_progress.connect(func(f): update_card.set_progress(f))
	updater.download_failed.connect(func(reason): update_card.set_failed(reason))
	updater.ready_to_restart.connect(_install_update)
	add_child(updater)
	update_card = UpdateCard.new()
	update_card.update_pressed.connect(func(): updater.download())
	add_child(update_card)


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
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_floating_labels.append(l)
	_section_labels.append(l)
	return l


# A food-pellet cursor for "click here to feed".
func _set_food_cursor() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if d < 3.3:
				img.set_pixel(x, y, Color("d98c4a"))
			elif d < 4.6:
				img.set_pixel(x, y, Color("1a0f08"))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_CROSS, Vector2(8, 8))


func _toggle_shop() -> void:
	if compact:
		shop_popup.visible = not shop_popup.visible
		_refresh()


func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		shop_popup.visible = false
		settings_panel.sync(settings.values)


func _open_fish_card(f) -> void:
	_fit_popups()
	var sp: Dictionary = Data.SPECIES[f.species]
	fish_card.open(f, "%s  %s" % [sp.icon, sp.name], sp.color)
	_refresh()


# ---------------------------------------------------------------- tips

func _toggle_help() -> void:
	settings_panel.visible = false
	shop_popup.visible = false
	help_card.toggle()


func _reset_tips() -> void:
	tips_seen.clear()
	_tip_cooldown = 1.0
	_play_time = 0.0
	_save_game()
	_say("Tips will show again as you play.")


func _toggle_fish_list() -> void:
	settings_panel.visible = false
	shop_popup.visible = false
	fish_list.toggle()
	_refresh()


func _check_tips() -> void:
	if tip_box.visible or _tip_cooldown > 0.0 or settings_panel.visible or info_card.visible or help_card.visible or fish_list.visible or update_card.visible:
		return
	for id in TIP_ORDER:
		if tips_seen.has(id):
			continue
		var text := _tip_text(id)
		if text != "":
			tips_seen[id] = true
			tip_label.text = text
			tip_box.visible = true
			_tip_time = 10.0
			return


func _tip_text(id: String) -> String:
	match id:
		"coin":
			if upgrades.snail == 0:
				for c in tank.coins:
					if c.landed and c.life < tank.COIN_LIFE - 3.0:
						return "Coins sink to the sand. Click a $ or drag across them to collect.  (Space collects them all.)"
		"food":
			for f in tank.fishes:
				if f.hunger > 0.7 and not f.dead:
					return "A fish is hungry ( ? ). Click the water to drop food *  (or press F)."
		"buy":
			if lifetime > 0.0 and money >= fish_cost(0) and tank.fishes.size() < capacity():
				return "You can afford another fish! " + ("Open the [ shop ] (S)." if compact else "Buy one below, or press 1.")
		"snail":
			if upgrades.snail == 0 and money >= Data.upgrade_cost("snail", 0):
				return "Tired of clicking coins? A snail collects them for you. It's in the shop."
		"name":
			if _play_time > 150.0:
				return "Tip: right-click a fish to name it or see its stats."
		"dirt":
			if settings.values.dirt and tank.dirt_level() >= 0.2:
				return "The glass is getting dirty. Press W (or [ clean ]) and scrub with the left button held. Right-click rinses the sponge."
		"settings":
			if _play_time > 240.0:
				return "Tip: Esc opens settings: desktop widget mode, always on top, sound, text size."
	return ""


func _hide_tip() -> void:
	tip_box.visible = false
	_tip_cooldown = 6.0


# ---------------------------------------------------------------- window + settings

func _set_setting(key: String, value) -> void:
	if key == "autostart":
		_set_autostart(value)
		settings.values.autostart = _autostart_enabled()
		settings_panel.sync(settings.values)
		if value and not settings.values.autostart:
			_say("Couldn't turn on Start with Windows.")
		else:
			_say("fishy will start with Windows." if value else "fishy won't start with Windows anymore.")
		return
	settings.values[key] = value
	_apply_settings()
	if key == "widget":
		_resize_widget()
	settings.save_file()
	settings_panel.sync(settings.values)


func _apply_settings() -> void:
	var v: Dictionary = settings.values
	var w := get_window()
	w.min_size = MIN_WINDOW
	if w.borderless != v.borderless:
		var inner := w.size                 # keep the same inside size
		w.borderless = v.borderless
		w.size = inner
	w.always_on_top = v.on_top
	# The window itself is always created transparent-capable (project setting
	# display/window/size/transparent): Windows ignores turning that on later.
	# So the toggle only decides whether we paint a background.
	get_viewport().transparent_bg = v.transparent
	bg.visible = not v.transparent
	tank.transparent_outside = v.transparent
	tank.dirt_enabled = v.dirt
	tank.deaths_enabled = v.fish_death
	if not v.dirt and tank.clean_mode:
		tank.set_clean_mode(false)
	# Text floating over the desktop is unreadable, so give it a dark backing.
	for l in _floating_labels:
		if v.transparent:
			l.add_theme_stylebox_override("normal", _label_backing)
		else:
			l.remove_theme_stylebox_override("normal")
	# Text and tank size.
	var s := float(v.ui_scale)
	theme.default_font_size = int(round(15.0 * s))
	money_label.add_theme_font_size_override("font_size", int(round(18.0 * s)))
	for l in _section_labels:
		l.add_theme_font_size_override("font_size", int(round(13.0 * s)))
	tank.base_font_size = int(round(16.0 * s))
	tank._recalc_grid()
	audio.volume = int(v.volume) / 100.0
	_apply_fps()
	pin_button.text = "[ unpin ]" if v.on_top else "[ pin ]"
	grip.visible = v.borderless
	min_button.visible = v.borderless
	close_button.visible = v.borderless
	close_button.tooltip_text = "Keep running minimized (quit from the tray icon)" if v.tray else "Save and quit"
	_update_layout()


func _apply_fps() -> void:
	var fps := int(settings.values.fps)
	if get_window().mode == Window.MODE_MINIMIZED:
		fps = HIDDEN_FPS
	elif _dragging:
		fps = DRAG_FPS
	elif settings.values.eco and not _focused:
		fps = min(fps, ECO_FPS)
	Engine.max_fps = fps


func _update_layout() -> void:
	if shop_box == null:
		return
	var mode: String = settings.values.layout
	var limit: Vector2 = COMPACT_BELOW * float(settings.values.ui_scale)
	var want := mode == "compact" or (mode == "auto" and (size.x < limit.x or size.y < limit.y))
	title_label.visible = not want
	stats_label.visible = not want
	goal_label.visible = not want
	bar_spacer.visible = want
	shop_button.visible = want
	# Very narrow widgets: tighter spacing, and the pin button steps aside
	# (pinning is still in settings and the tray menu).
	var scale := float(settings.values.ui_scale)
	top_row.add_theme_constant_override("separation", 6 if want else 12)
	pin_button.visible = not (want and size.x < 470.0 * scale)
	_style_for_size(want, scale)
	if want == compact:
		return
	compact = want
	shop_box.get_parent().remove_child(shop_box)
	if compact:
		shop_scroll.add_child(shop_box)
	else:
		main_vb.add_child(shop_box)
		shop_popup.visible = false


# Small windows: tighter margins and buttons, smaller status text.
func _style_for_size(small: bool, scale: float) -> void:
	for side in ["left", "right", "top", "bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, 4 if small else 8)
	main_vb.add_theme_constant_override("separation", 3 if small else 6)
	shop_button.text = "[shop]" if small else "[ shop ]"
	settings_button.text = "[=]" if small else "[ = ]"
	help_button.text = "[?]" if small else "[ ? ]"
	undo_button.text = "[undo]" if small else "[ undo sell ]"
	fish_section_label.text = "-- FISH --" if small else "-- FISH  (keys 1-6, Shift = buy max) --"
	fish_list_button.text = "List (L)" if small else "Fish list (L)"
	for b in [shop_button, pin_button, help_button, settings_button, min_button, close_button, undo_button]:
		for state in _compact_btn:
			if small:
				b.add_theme_stylebox_override(state, _compact_btn[state])
			else:
				b.remove_theme_stylebox_override(state)
	var small_font := int(round(13.0 * scale))
	for l in [info_label, tip_label]:
		if small:
			l.add_theme_font_size_override("font_size", small_font)
		else:
			l.remove_theme_font_size_override("font_size")
	info_label.custom_minimum_size.y = 16 if small else 20
	var shop_buttons: Array = fish_buttons + upgrade_buttons.values() + [medicine_button, fish_list_button]
	for b in shop_buttons:
		for state in _compact_btn:
			if small:
				b.add_theme_stylebox_override(state, _compact_btn[state])
			else:
				b.remove_theme_stylebox_override(state)
	_fit_popups()


# Keep pop-ups inside the window: the compact shop scrolls when it's
# taller than the space under the top bar, cards wrap to the window width.
func _fit_popups() -> void:
	var top := top_bar.get_global_rect().end.y
	# Space under the top bar, minus the pop-up's own padding and gap.
	var pad: float = shop_popup.get_theme_stylebox("panel").get_minimum_size().y
	var room := maxf(60.0, size.y - top - pad - 16.0)
	shop_scroll.custom_minimum_size.y = minf(shop_box.get_combined_minimum_size().y, room)
	info_card.max_width = size.x - 40.0
	update_card.max_width = size.x - 40.0
	fish_card.max_width = size.x - 40.0


func _on_top_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			# Double-click the bar to flip between full and compact.
			_set_setting("layout", "full" if compact else "compact")
		else:
			_begin_drag()
		accept_event()


func _snap_to_corner(corner: String) -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED
	var r := DisplayServer.screen_get_usable_rect(w.current_screen)
	var sz := _widget_size()
	w.size = sz
	var y := r.end.y - sz.y - 12
	var x := r.end.x - sz.x - 12 if corner == "right" else r.position.x + 12
	w.position = Vector2i(x, y)
	_store_window()


func _widget_size() -> Vector2i:
	return WIDGET_SIZES.get(settings.values.widget, WIDGET_SIZES.normal)


# Resize to the chosen widget size, keeping whichever screen corner the
# window is closest to in place (widgets usually live in a corner).
func _resize_widget() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED
	var r := DisplayServer.screen_get_usable_rect(w.current_screen)
	var old := Rect2i(w.position, w.size)
	var sz := _widget_size()
	var center := old.get_center()
	var x := old.position.x if center.x < r.get_center().x else old.end.x - sz.x
	var y := old.position.y if center.y < r.get_center().y else old.end.y - sz.y
	x = clampi(x, r.position.x, max(r.position.x, r.end.x - sz.x))
	y = clampi(y, r.position.y, max(r.position.y, r.end.y - sz.y))
	w.size = sz
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


# ---------------------------------------------------------------- dragging

# We move the window ourselves (instead of letting Windows do it) so it can
# snap to screen edges and never slide under the taskbar.
func _begin_drag() -> void:
	var w := get_window()
	if w.mode != Window.MODE_WINDOWED:
		w.start_drag()
		return
	_dragging = true
	_drag_grab = DisplayServer.mouse_get_position() - DisplayServer.window_get_position_with_decorations()
	_apply_fps()


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_store_window()
	_apply_fps()


func _drag_step() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()
		return
	var w := get_window()
	var mouse := DisplayServer.mouse_get_position()
	var outer_pos := DisplayServer.window_get_position_with_decorations()
	var outer_size := DisplayServer.window_get_size_with_decorations()
	var area := _usable_rect_at(mouse)
	var target := snap_to_area(mouse - _drag_grab, outer_size, area, SNAP_PX)
	# window.position is the client area; keep the title bar offset (0 if borderless).
	w.position = target + (w.position - outer_pos)


# The usable area (screen minus taskbar) of the monitor under the mouse.
func _usable_rect_at(p: Vector2i) -> Rect2i:
	for i in DisplayServer.get_screen_count():
		if Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i)).has_point(p):
			return DisplayServer.screen_get_usable_rect(i)
	return DisplayServer.screen_get_usable_rect(get_window().current_screen)


# Where a window of `sz` dragged to `p` should go: edges within `snap`
# pixels of the area's edges stick to them, and it always stays fully
# inside the area (so it never covers the taskbar).
static func snap_to_area(p: Vector2i, sz: Vector2i, area: Rect2i, snap: int) -> Vector2i:
	var x := p.x
	var y := p.y
	if abs(x - area.position.x) <= snap:
		x = area.position.x
	elif abs(x + sz.x - area.end.x) <= snap:
		x = area.end.x - sz.x
	if abs(y - area.position.y) <= snap:
		y = area.position.y
	elif abs(y + sz.y - area.end.y) <= snap:
		y = area.end.y - sz.y
	x = clampi(x, area.position.x, max(area.position.x, area.end.x - sz.x))
	y = clampi(y, area.position.y, max(area.position.y, area.end.y - sz.y))
	return Vector2i(x, y)


func _minimize() -> void:
	if settings.values.tray:
		_hide_to_tray()
	else:
		get_window().mode = Window.MODE_MINIMIZED


func _close_pressed() -> void:
	if settings.values.tray:
		_save_game()
		_store_window()
		_hide_to_tray()
	else:
		_quit()


func _quit() -> void:
	_save_game()
	_store_window()
	get_tree().quit()


func _reset_game() -> void:
	_save_game()
	_backup_save("before-reset")
	stats = _default_stats()
	tips_seen.clear()
	money = Data.START_MONEY
	lifetime = 0.0
	unlocked = 1
	for k in upgrades:
		upgrades[k] = 0
	_undo = {}
	medicine = 0
	_dirt_stage = 0
	tank.set_clean_mode(false)
	tank.reset()
	_apply_upgrades()
	tank.add_fish(0, 0, 0, 0.3, true)
	_save_game()
	settings_panel.visible = false
	_say("Fresh start! One guppy, $%d. Good luck." % int(Data.START_MONEY))
	_refresh()


# ---------------------------------------------------------------- tray

func _build_tray() -> void:
	tray_menu = PopupMenu.new()
	tray_menu.add_item("Show / hide tank", 0)
	tray_menu.add_check_item("Always on top", 1)
	tray_menu.add_separator()
	tray_menu.add_item("Quit fishy", 3)
	tray_menu.about_to_popup.connect(func(): tray_menu.set_item_checked(1, settings.values.on_top))
	tray_menu.id_pressed.connect(_on_tray_menu)
	add_child(tray_menu)
	tray = StatusIndicator.new()
	tray.icon = load("res://icon.svg")
	tray.tooltip = "fishy"
	add_child(tray)
	tray.menu = tray.get_path_to(tray_menu)
	tray.pressed.connect(func(button, _pos):
		if button == MOUSE_BUTTON_LEFT:
			_toggle_window())


func _on_tray_menu(id: int) -> void:
	match id:
		0:
			_toggle_window()
		1:
			_set_setting("on_top", not settings.values.on_top)
		3:
			_quit()


func _toggle_window() -> void:
	if get_window().mode == Window.MODE_MINIMIZED:
		_show_from_tray()
	else:
		_store_window()
		_hide_to_tray()


# Godot can't hide its main window, so "to the tray" means minimized and
# still running; the tray icon shows money and brings the tank back.
func _hide_to_tray() -> void:
	get_window().mode = Window.MODE_MINIMIZED
	_apply_fps()


func _show_from_tray() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED
	w.move_to_foreground()
	w.grab_focus()
	_apply_fps()


# ---------------------------------------------------------------- refresh

func _say(text: String) -> void:
	_msg = text
	_msg_time = 6.0


func _refresh() -> void:
	if tank == null:
		return
	money_label.text = "$ " + Data.fmt(money)
	var rate: float = tank.estimate_rate()
	var rate_txt := "%.1f" % rate if rate < 100.0 else Data.fmt(rate)
	var dirt_pct := int(round(tank.dirt_level() * 100.0))
	stats_label.text = "~$%s/s   fish %d/%d%s" % [rate_txt, tank.fishes.size(), capacity(),
		"   dirt %d%%" % dirt_pct if settings.values.dirt else ""]
	tray.tooltip = "fishy   $%s   (~$%s/s)" % [Data.fmt(money), rate_txt]

	var goal := _next_goal()
	if goal.is_empty():
		goal_label.text = ""
	else:
		var filled := int(clampf(money / goal.cost, 0.0, 1.0) * 10.0)
		goal_label.text = "next: %s [%s%s] $%s" % [goal.name, "#".repeat(filled), "-".repeat(10 - filled),
			Data.fmt(goal.cost - money)]

	var f = tank.hovered
	var warning := _dirt_warning()
	if tank.clean_mode:
		var load_bars := int(round(tank.sponge_load * 5.0))
		var sponge := "#".repeat(load_bars) + "-".repeat(5 - load_bars)
		if compact:
			# Short enough for a Tiny window; the rinse hint shows when it's needed.
			# The dirt % is on the [done] button, which leaves room for the hint.
			info_label.text = "sponge [%s]%s" % [sponge, "  rinse: right-click" if tank.sponge_load >= 0.6 else ""]
		else:
			info_label.text = "Scrubbing: hold left, slow strokes.  dirt %d%%   sponge [%s]   right-click: rinse   W: done" % [
				dirt_pct, sponge]
		info_label.add_theme_color_override("font_color", Color("f2d25c"))
	elif f != null and f.dead:
		info_label.text = ("%s  dead  (right-click)" if compact else "%s is dead.  Right-click to revive it or flush it.") % fish_title(f)
		if f.skeleton:
			info_label.text = "%s: just bones. Right-click to flush." % fish_title(f)
		info_label.add_theme_color_override("font_color", Color("9aa3ad"))
	elif f != null:
		var sp: Dictionary = Data.SPECIES[f.species]
		var bars := int(round((1.0 - f.hunger) * 8.0))
		var lv_txt := "MAX" if f.level >= Data.MAX_LEVEL else "%d (xp %d/%d)" % [f.level, f.xp, Data.xp_needed(f.level)]
		if compact:
			info_label.text = "%s lv%s  [%s%s]  $%s/coin" % [
				fish_title(f), "MAX" if f.level >= Data.MAX_LEVEL else str(f.level),
				"#".repeat(bars / 2), "-".repeat(4 - bars / 2), Data.fmt(tank.fish_value(f))]
		else:
			info_label.text = "%s %s   lvl %s   food [%s%s]   $%s per coin   right-click: name / sell" % [
				sp.icon, fish_title(f), lv_txt, "#".repeat(bars), "-".repeat(8 - bars), Data.fmt(tank.fish_value(f))]
		info_label.add_theme_color_override("font_color", sp.color)
	elif _msg_time > 0.0:
		info_label.text = _msg
		info_label.add_theme_color_override("font_color", Color("9fc7e0"))
	elif warning != "":
		info_label.text = warning
		info_label.add_theme_color_override("font_color",
			Color("ff7a7a") if tank.dirt_level() >= Data.FILTHY_AT or tank.death_countdown() >= 0.0 else Color("ffcf5c"))
	elif compact:
		# Small windows have no stats in the top bar, so show them here.
		info_label.text = "fish %d/%d  ~$%s/s%s" % [tank.fishes.size(), capacity(), rate_txt,
			"" if goal.is_empty() else "  next: %s $%s" % [goal.name, Data.fmt(goal.cost - money)]]
		info_label.add_theme_color_override("font_color", Color("6f97b3"))
	else:
		info_label.text = ""
	# Whatever doesn't fit gets "..."; hover the line to read all of it.
	info_label.tooltip_text = info_label.text
	undo_button.visible = _undo_time > 0.0 and not _undo.is_empty()
	clean_button.visible = settings.values.dirt and (tank.clean_mode or tank.dirt_level() >= 0.05)
	if tank.clean_mode:
		clean_button.text = "[done %d%%]" % dirt_pct if compact else "[ done ]"
	else:
		clean_button.text = ("[ clean %d%% ]" if not compact else "[ %d%% ]") % dirt_pct
	if tank.dirt_level() >= Data.SICK_AT and not tank.clean_mode:
		clean_button.add_theme_color_override("font_color", Color("ffcf5c") if tank.dirt_level() < Data.FILTHY_AT else Color("ff7a7a"))
	else:
		clean_button.remove_theme_color_override("font_color")

	if fish_card.visible:
		var cf = fish_card.fish
		if cf == null or not tank.fishes.has(cf):
			fish_card.close()
		else:
			_update_fish_card(cf)

	if fish_list.visible:
		_refresh_fish_list()

	if tip_box.visible:
		tip_label.custom_minimum_size.x = min(520.0, size.x - (36.0 if compact else 80.0))
		var y := top_bar.get_global_rect().end.y + (6.0 if compact else 30.0)
		tip_box.offset_top = y
		tip_box.offset_bottom = y

	_refresh_shop(rate)
	if compact and shop_popup.visible:
		_fit_popups()


func _update_fish_card(cf) -> void:
	var med := "use 1 medicine (you have %d)" % medicine if medicine > 0 else "buy medicine $%s" % Data.fmt(medicine_cost())
	if cf.dead and cf.skeleton:
		fish_card.update_stats("Too late to revive: just bones now.\nBones make the tank dirty faster.", "Flush")
		return
	if cf.dead:
		var left := int(ceil(cf.revive_left))
		var why := ""
		if tank.dirt_level() >= Data.SICK_AT:
			why = "\nClean the tank below %d%% to revive it." % int(Data.SICK_AT * 100)
		fish_card.update_stats("Died from dirty water.\nRevive within %d:%02d (game time).\nComes back one level lower.%s" % [
			left / 60, left % 60, why], "Flush  +$%s" % Data.fmt(floor(sell_value(cf) * Data.FLUSH_REFUND)),
			"Revive", "Revive with Fish Medicine: " + med)
		return
	var bars := int(round((1.0 - cf.hunger) * 10.0))
	var lv_txt := "MAX" if cf.level >= Data.MAX_LEVEL else "%d   (xp %d/%d)" % [cf.level, cf.xp, Data.xp_needed(cf.level)]
	var status := ""
	if cf.sick:
		status = "\nSick: slow, no XP, half the good from food."
	elif cf.weak > 0.0:
		status = "\nStill weak: no coins for %ds." % int(ceil(cf.weak))
	fish_card.update_stats("Level  %s\nFood   [%s%s]\nDrops  $%s every %ss%s" % [
		lv_txt, "#".repeat(bars), "-".repeat(10 - bars), Data.fmt(tank.fish_value(cf)),
		str(Data.SPECIES[cf.species].interval), status], "Sell for $%s" % Data.fmt(sell_value(cf)),
		"Cure" if cf.sick else "", "Cure with Fish Medicine: " + med)


# The most urgent thing about dirty water, for the info line.
func _dirt_warning() -> String:
	if not settings.values.dirt:
		return ""
	var pct := int(round(tank.dirt_level() * 100.0))
	var t: float = tank.death_countdown()
	if t >= 0.0 and t < 120.0:
		return "A fish will die in %d:%02d! Clean the tank (W)." % [int(t) / 60, int(t) % 60]
	if tank.dirt_level() >= Data.FILTHY_AT:
		return ("Filthy %d%%! Fish losing levels. W" if compact else "The tank is filthy (%d%%): sick fish are losing levels. Press W to clean.") % pct
	if tank.dirt_level() >= Data.SICK_AT:
		return ("Dirty %d%%: fish get sick. W" if compact else "The tank is dirty (%d%%): fish are getting sick. Press W to clean.") % pct
	return ""


func _refresh_shop(rate: float) -> void:
	var full: bool = tank.fishes.size() >= capacity()
	for i in fish_buttons.size():
		var b: Button = fish_buttons[i]
		var sp: Dictionary = Data.SPECIES[i]
		var cost := fish_cost(i)
		# The pop-up shop uses short labels so 2-3 buttons fit per row;
		# the tooltip has the full details.
		if i > unlocked:
			b.text = ("??? $" if compact else "???  $") + Data.fmt(cost)
			b.tooltip_text = "Buy the previous fish to discover this one."
			b.disabled = true
		else:
			b.text = "%s $%s" % [sp.icon, Data.fmt(cost)] if compact else "%s  %s  $%s" % [sp.icon, sp.name, Data.fmt(cost)]
			var coin: float = max(1.0, round(float(sp.value) * coin_mult()))
			b.tooltip_text = "%s  (key %d)\nIncome  +$%s/s   (a $%s coin every %ss)\nYou own %d.%s" % [
				sp.name, i + 1, _fmt_rate(coin / float(sp.interval)), Data.fmt(coin), str(sp.interval),
				owned(i), "\nThe tank is full." if full else ""]
			b.disabled = money < cost or full
		_mark_affordable(b)

	for key in upgrade_buttons:
		var b: Button = upgrade_buttons[key]
		var u: Dictionary = Data.UPGRADES[key]
		var lv: int = upgrades[key]
		b.tooltip_text = _upgrade_tooltip(key, rate)
		var label: String = u.short if compact else u.name
		if lv >= int(u.max):
			b.text = "%s  MAX" % label if not compact else "%s MAX" % label
			b.disabled = true
		else:
			var cost := Data.upgrade_cost(key, lv)
			var lv_txt := "" if int(u.max) == 1 else ((" %d" if compact else "  lv%d") % lv)
			b.text = ("%s%s $%s" if compact else "%s%s  $%s") % [label, lv_txt, Data.fmt(cost)]
			b.disabled = money < cost
		_mark_affordable(b)
	medicine_button.text = ("Medicine %d $%s" if compact else "Fish Medicine (%d)  $%s") % [medicine, Data.fmt(medicine_cost())]
	medicine_button.tooltip_text = "Revives a dead fish (within %d min) or cures a sick one.\nRight-click the fish to use it. You have %d." % [
		int(Data.REVIVE_WINDOW / 60.0), medicine]
	medicine_button.disabled = money < medicine_cost() or medicine >= MAX_MEDICINE
	_mark_affordable(medicine_button)
	for key in ["pleco", "filter", "uv"]:
		upgrade_buttons[key].visible = settings.values.dirt
	medicine_button.visible = settings.values.dirt


func _upgrade_tooltip(key: String, rate: float) -> String:
	var lv: int = upgrades[key]
	var maxed: bool = lv >= int(Data.UPGRADES[key].max)
	var after := upgrades.duplicate()
	after[key] = lv + 1
	var gain := rate * (coin_mult(after) / coin_mult() - 1.0)
	match key:
		"snail":
			return "A snail looks after its own stretch of sand and collects the coins there.\nYou have %d." % lv
		"feeder":
			var now := "off" if lv == 0 else "every %ds" % int(Data.FEEDER_INTERVAL[lv])
			if maxed:
				return "Drops food when fish get hungry.\nNow: %s (max)" % now
			return "Drops food when fish get hungry.\nNow: %s  ->  every %ds" % [now, int(Data.FEEDER_INTERVAL[lv + 1])]
		"filter", "uv":
			var now := int(round(Data.dirt_slowdown(upgrades) * 100.0))
			var after_pct := int(round(Data.dirt_slowdown(after) * 100.0))
			return "%s\nDirt builds up %d%% slower now%s (all together at most 50%%)." % [Data.UPGRADES[key].desc, now,
				"" if maxed else " -> %d%%" % after_pct]
		"pleco":
			return "%s\nYou have %d." % [Data.UPGRADES[key].desc, lv]
		"tank":
			if maxed:
				return "Room for %d fish (max)." % capacity()
			return "Room for 2 more fish:  %d  ->  %d" % [capacity(), capacity() + 2]
		_:
			var desc: String = Data.UPGRADES[key].desc
			if maxed:
				return desc
			return "%s\nIncome  +$%s/s" % [desc, _fmt_rate(gain)]


func _fmt_rate(r: float) -> String:
	return "%.1f" % r if r < 100.0 else Data.fmt(r)


# In the pop-up shop every style keeps the tight padding.
func _mark_affordable(b: Button) -> void:
	if b.disabled:
		for state in ["normal", "hover"]:
			if compact:
				b.add_theme_stylebox_override(state, _compact_btn[state])
			else:
				b.remove_theme_stylebox_override(state)
		b.remove_theme_color_override("font_color")
	else:
		b.add_theme_stylebox_override("normal", _afford_tight.normal if compact else _afford_normal)
		b.add_theme_stylebox_override("hover", _afford_tight.hover if compact else _afford_hover)
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
		"tips": tips_seen.keys(),
		"stats": stats,
		"medicine": medicine,
		"dirt": tank.dirt.serialize(),
		"time": Time.get_unix_time_from_system(),
	}
	stats.food += tank.player_food
	tank.player_food = 0
	data.stats = stats
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _load_game(skip_offline := false) -> bool:
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
	var st = d.get("stats", null)
	if typeof(st) == TYPE_DICTIONARY:
		for k in st:
			if stats.has(k):
				stats[k] = st[k]
	var tips = d.get("tips", null)
	if typeof(tips) == TYPE_ARRAY:
		for t in tips:
			tips_seen[String(t)] = true
	elif lifetime > 1000.0:
		# An older save from someone who clearly knows the basics already.
		for t in ["coin", "food", "buy", "snail"]:
			tips_seen[t] = true
	_apply_upgrades()
	var fish_list = d.get("fish", [])
	if typeof(fish_list) == TYPE_ARRAY:
		for fd in fish_list:
			var s := int(fd.get("s", 0))
			if s >= 0 and s < Data.SPECIES.size():
				var f = tank.add_fish(s, clampi(int(fd.get("lv", 0)), 0, Data.MAX_LEVEL), int(fd.get("xp", 0)), float(fd.get("hg", 0.2)))
				f.nickname = String(fd.get("n", "")).left(16)
				f.sick = bool(fd.get("sick", false))
				if fd.has("dead"):
					f.dead = true
					f.revive_left = clampf(float(fd.dead), 0.0, Data.REVIVE_WINDOW)
					f.skeleton = bool(fd.get("bones", false)) or f.revive_left <= 0.0
					f.pos.y = 2.0
	if tank.living() == 0:
		tank.add_fish(0, 0, 0, 0.3)
	medicine = clampi(int(d.get("medicine", 0)), 0, MAX_MEDICINE)
	tank.dirt.load_from(d.get("dirt", null))
	_save_predates_dirt = not d.has("dirt")

	var away := Time.get_unix_time_from_system() - float(d.get("time", Time.get_unix_time_from_system()))
	if skip_offline:
		_say("Save loaded.")
	elif away > 30.0:
		_offline_earnings(away)
	else:
		_say("Welcome back!")
	return true


func _offline_earnings(secs: float) -> void:
	secs = min(secs, Data.OFFLINE_CAP_SECONDS)
	# Without a snail most coins vanish before you get back.
	var collect := 0.85 if upgrades.snail > 0 else 0.15
	# Grime keeps building while you're away, but only up to a point, and
	# nothing gets sick or dies while the game is closed.
	var dirt_before: float = tank.dirt_level()
	# Saves from before dirt existed start with clean glass.
	if settings.values.dirt and not _save_predates_dirt:
		tank.dirt.rate_mult = 1.0 - Data.dirt_slowdown(upgrades)
		tank.dirt.grow_offline(secs, Data.OFFLINE_DIRT_CAP)
	var dirt_after: float = tank.dirt_level()
	var dirt_mult := (Data.dirt_penalty(dirt_before) + Data.dirt_penalty(dirt_after)) * 0.5 if settings.values.dirt else 1.0
	var earned := 0.0
	for f in tank.fishes:
		if f.dead:
			continue
		var active := secs
		if upgrades.feeder == 0:
			active = min(secs, max(0.0, (1.0 - f.hunger) * Data.HUNGER_TIME))
			f.hunger = min(1.0, f.hunger + secs / Data.HUNGER_TIME)
		earned += tank.fish_value(f) / float(Data.SPECIES[f.species].interval) * active
	# fish_value already counts today's dirt; use the average over the time away.
	earned = floor(earned * collect * dirt_mult / maxf(0.01, tank.water_mult()))
	money += earned
	lifetime += earned
	stats.earned_offline += earned
	if earned <= 0.0:
		_say("Welcome back! You were away %s." % Data.fmt_time(secs))
		return
	var lines := ["You were gone %s." % Data.fmt_time(secs), "Your fish made  $%s" % Data.fmt(earned)]
	if upgrades.snail == 0:
		lines.append(("" if compact else "\n") + "(A snail would have collected a lot more of it.)")
	if upgrades.feeder == 0:
		lines.append("Your fish are hungry: click the water to feed them.")
	if dirt_after - dirt_before > 0.05:
		lines.append("The tank got dirtier: %d%% now. Press W to clean." % int(round(dirt_after * 100.0)))
	_fit_popups()
	_queue_card("-- while you were away --", "\n".join(lines))
	_say("You were away %s. Your fish made $%s." % [Data.fmt_time(secs), Data.fmt(earned)])


# ---------------------------------------------------------------- fish list

func _refresh_fish_list() -> void:
	var sorted: Array = tank.fishes.duplicate()
	sorted.sort_custom(func(a, b): return tank.fish_value(a) > tank.fish_value(b))
	var rows := []
	for f in sorted:
		var sp: Dictionary = Data.SPECIES[f.species]
		var bars := int(round((1.0 - f.hunger) * 6.0))
		var mark := "  !" if f.hunger >= 1.0 else ("  ?" if f.hunger > 0.7 else "")
		if f.sick:
			mark += "  sick"
		if f.dead:
			mark = "  bones" if f.skeleton else "  DEAD %d:%02d" % [int(ceil(f.revive_left)) / 60, int(ceil(f.revive_left)) % 60]
		rows.append({
			"fish": f,
			"color": sp.color,
			"text": "%s  %s  lv%s  [%s%s]  $%s%s" % [sp.icon, fish_title(f),
				"MAX" if f.level >= Data.MAX_LEVEL else str(f.level),
				"#".repeat(bars), "-".repeat(6 - bars), Data.fmt(tank.fish_value(f)), mark],
		})
	fish_list.update_rows("-- your fish  %d/%d --" % [tank.fishes.size(), capacity()], rows)


# ---------------------------------------------------------------- stats

func _default_stats() -> Dictionary:
	return {
		"earned_you": 0.0, "earned_snails": 0.0, "earned_offline": 0.0,
		"coins_you": 0, "coins_snails": 0,
		"fish_bought": 0, "fish_sold": 0, "food": 0,
		"fish_died": 0, "fish_revived": 0, "fish_flushed": 0, "spotless": 0,
		"play_seconds": 0.0, "best_money": 0.0,
		"started": Time.get_unix_time_from_system(),
	}


func _show_stats() -> void:
	settings_panel.visible = false
	var d := Time.get_datetime_dict_from_unix_time(int(stats.started))
	var best = null
	for f in tank.fishes:
		if f.dead:
			continue
		if best == null or f.level > best.level or (f.level == best.level and tank.fish_value(f) > tank.fish_value(best)):
			best = f
	var row := func(label: String, value: String) -> String:
		return label.rpad(15) + value
	var lines := [
		row.call("Playing since", "%d %s %d" % [d.day, MONTHS[d.month - 1], d.year]),
		row.call("Time played", Data.fmt_time(stats.play_seconds)),
		row.call("Total earned", "$" + Data.fmt(lifetime)),
		row.call("  by you", "$" + Data.fmt(stats.earned_you)),
		row.call("  by snails", "$" + Data.fmt(stats.earned_snails)),
		row.call("  while away", "$" + Data.fmt(stats.earned_offline)),
		row.call("Coins clicked", str(int(stats.coins_you))),
		row.call("Snail coins", str(int(stats.coins_snails))),
		row.call("Most money", "$" + Data.fmt(stats.best_money)),
		row.call("Fish bought", str(int(stats.fish_bought))),
		row.call("Fish sold", str(int(stats.fish_sold))),
		row.call("Food dropped", str(int(stats.food) + tank.player_food)),
		row.call("Spotless cleans", str(int(stats.spotless))),
		row.call("Fish lost", str(int(stats.fish_died))),
		row.call("  revived", str(int(stats.fish_revived))),
		row.call("  flushed", str(int(stats.fish_flushed))),
		row.call("Best fish", "" if best == null else "%s, lv %d" % [fish_title(best), best.level]),
	]
	_fit_popups()
	info_card.open("-- stats --", "\n".join(lines), "Close", true)


# ---------------------------------------------------------------- backups, export, import

func _backup_save(tag: String) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := ProjectSettings.globalize_path(BACKUP_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	# Quick restarts shouldn't push older, more useful backups out of the folder.
	if tag == "start":
		for n in DirAccess.get_files_at(dir):
			var age := Time.get_unix_time_from_system() - FileAccess.get_modified_time("%s/%s" % [dir, n])
			if age < 600.0:
				return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), "%s/save_%s_%s.json" % [dir, stamp, tag])
	# Keep only the newest few. Names start with the date, so sorting is by age.
	var files := Array(DirAccess.get_files_at(dir)).filter(func(n): return n.begins_with("save_") and n.ends_with(".json"))
	files.sort()
	while files.size() > BACKUP_KEEP:
		DirAccess.remove_absolute("%s/%s" % [dir, files.pop_front()])


func _open_backups() -> void:
	var dir := ProjectSettings.globalize_path(BACKUP_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(dir)


func _open_save_dialog(export: bool) -> void:
	settings_panel.visible = false
	var dlg := FileDialog.new()
	dlg.use_native_dialog = true
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json ; fishy save"])
	if export:
		dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dlg.title = "Export save"
		var d := Time.get_date_dict_from_system()
		dlg.current_file = "fishy-save-%04d-%02d-%02d.json" % [d.year, d.month, d.day]
		dlg.file_selected.connect(export_save)
	else:
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dlg.title = "Import save"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
		dlg.current_dir = ProjectSettings.globalize_path(BACKUP_DIR)
		dlg.file_selected.connect(import_save)
	dlg.file_selected.connect(func(_p): dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func export_save(path: String) -> bool:
	_save_game()
	var ok := DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), path) == OK
	_say(("Exported your save to " + path.get_file()) if ok else "Couldn't export the save there.")
	return ok


func import_save(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("fish", null)) != TYPE_ARRAY or not d.has("money"):
		_say("That file isn't a fishy save.")
		return false
	# Keep the current progress as a backup, then load the chosen one.
	_save_game()
	_backup_save("before-import")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		_say("Couldn't import the save.")
		return false
	f.store_string(text)
	f.close()
	money = Data.START_MONEY
	lifetime = 0.0
	unlocked = 1
	for k in upgrades:
		upgrades[k] = 0
	tips_seen.clear()
	stats = _default_stats()
	_undo = {}
	medicine = 0
	_dirt_stage = 0
	tank.set_clean_mode(false)
	tank.reset()
	_load_game(true)
	_say("Imported " + path.get_file())
	_refresh()
	return true


# ---------------------------------------------------------------- info cards

# One card at a time: the next one opens when the current one closes.
func _queue_card(title: String, body: String, button := "Nice!", align_left := false) -> void:
	if info_card.visible:
		_card_queue.append([title, body, button, align_left])
		return
	_fit_popups()
	info_card.open(title, body, button, align_left)


func _next_card() -> void:
	if info_card.visible or _card_queue.is_empty():
		return
	var c: Array = _card_queue.pop_front()
	_queue_card.call_deferred(c[0], c[1], c[2], c[3])


# After an update, show what changed once. Brand new players skip it.
func _check_whats_new(returning: bool) -> void:
	var current: String = updater.current_version
	var seen: String = settings.values.seen_version
	if returning and (seen == "" or Changelog.newer(current, seen)):
		# Saves from before this note existed come from v0.2.0 or older.
		var since := seen if seen != "" else "0.2.0"
		var body := Changelog.text_since(since)
		if body != "":
			_queue_card("-- what's new in v%s --" % current, body, "Nice!", true)
	if seen != current:
		settings.values.seen_version = current
		settings.save_file()


# ---------------------------------------------------------------- updates

func _check_for_update(manual: bool) -> void:
	_manual_update_check = manual
	if manual:
		_say("Checking for updates...")
	updater.check()


func _on_update_found(info: Dictionary) -> void:
	settings_panel.visible = false
	update_card.open(info, updater.current_version, updater.can_self_update())


# Save everything first, so the new version starts exactly where we are.
func _install_update() -> void:
	_save_game()
	_backup_save("before-update")
	_store_window()
	settings.save_file()
	if not updater.install():
		update_card.set_failed("couldn't replace the game file")
		return
	updater.restart()
	get_tree().quit()


# ---------------------------------------------------------------- start with Windows

# If the game moved (installed somewhere new, or the folder was moved),
# point Start with Windows at where it is now.
func _refresh_autostart_path() -> void:
	if settings.values.autostart and OS.has_feature("template"):
		_set_autostart(true)


# Registered under HKCU\...\Run, so it only affects this Windows user.
func _autostart_command() -> String:
	var exe := OS.get_executable_path().replace("/", "\\")
	if OS.has_feature("template"):
		return "\"%s\"" % exe
	# Running from the Godot editor binary: point it at this project.
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/").replace("/", "\\")
	return "\"%s\" --path \"%s\"" % [exe, project]


func _autostart_enabled() -> bool:
	if OS.get_name() != "Windows":
		return false
	return OS.execute("reg", ["query", RUN_KEY, "/v", "fishy"]) == 0


func _set_autostart(on: bool) -> void:
	if OS.get_name() != "Windows":
		return
	if on:
		# reg.exe needs the quotes inside the value escaped, or paths with
		# spaces (C:\Users\Some Name\...) would break at login.
		var value := _autostart_command().replace("\"", "\\\"")
		OS.execute("reg", ["add", RUN_KEY, "/v", "fishy", "/t", "REG_SZ", "/d", value, "/f"])
	else:
		OS.execute("reg", ["delete", RUN_KEY, "/v", "fishy", "/f"])
