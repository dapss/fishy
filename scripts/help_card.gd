# Help card: how to play, mouse actions and keyboard shortcuts, plus a
# button to replay the first-time tips. Opened with [?] or F1.
extends Control

signal tips_reset_requested
signal whats_new_requested

const SECTIONS := [
	["HOW TO PLAY", [
		"Fish drop $ coins that sink to the sand. Click a coin, or drag across coins, to collect them.",
		"Fish get hungry over time ( ? above them). Click the water to drop food. Starving fish ( ! ) stop dropping coins.",
		"Each fish eats only its own food: flakes * (free), pellets \u2022, shrimp c, plankton \u00b0 (buy them in the shop). A click drops what the hungriest fish nearby eats; the food bar (or Q) picks one yourself. The auto-feeder uses your stock.",
		"The Dawa doesn't eat: when it's lonely ( ... ), move the mouse back and forth over it to pat it. Keep patting a fully happy Dawa until the hearts above it fill up (about 20 seconds) and it gets super happy: coins twice as often for a minute, then 5 minutes before it can happen again. Algae eaters eat only grime.",
		"Fed fish gain XP and level up (max 5). Higher levels drop bigger coins.",
		"Spend coins in the shop on more fish and upgrades. A snail collects coins for you, the auto-feeder feeds for you.",
		"Sharks don't eat pellets: a hungry shark hunts guppies. Name a guppy to keep it safe. The Guppy hatchery hatches fry for them, also while the game is closed.",
		"Your fish keep earning while the game is closed.",
		"The glass gets dirty over time. Dirty water earns less, then makes fish sick ( ~ ), then costs them levels. Left fully covered, fish start to die.",
		"Clean mode (W): hold the left button and scrub. Slow strokes clean best, fast ones just smear. A grimy sponge cleans badly: right-click to rinse it. Scrub it spotless for +25% coins for a while.",
		"A dead fish can be revived with Fish Medicine within 5 minutes of play (clean the tank first), or flushed. Medicine also cures sick fish. Algae eater fish graze grime off the glass; a filter and a UV lamp slow it down.",
	]],
	["MOUSE", [
		"Click the water: drop food",
		"Click or drag over $: collect coins",
		"Right-click a fish (or double-click): its card, to name, sell, cure, revive or flush it",
		"Clean mode: hold left and drag to scrub, right-click to rinse the sponge",
		"Shift-click a shop button (or Shift+1-9, 0): buy as many as you can afford",
		"Drag the top bar, or Alt+drag anywhere: move the window",
	]],
	["KEYS", [
		"Esc  settings        F1  this help",
		"S    shop            L   fish list",
		"1-0  buy fish        F   feed every hungry fish",
		"Q    what clicks drop (auto / a food)",
		"Space  collect all coins",
		"M    mute            Ctrl+Z  undo a sale",
		"P    pin on top      C   compact / full",
		"W    clean mode (scrub the glass)",
	]],
]

var _scroll: ScrollContainer
var _content: VBoxContainer
var _wrapping: Array = []        # labels that wrap and need a width


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
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)

	var title := Label.new()
	title.text = "-- help --"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("5fb3d9"))
	_content.add_child(title)

	for section in SECTIONS:
		var head := Label.new()
		head.text = section[0]
		head.add_theme_color_override("font_color", Color("7fcf9f"))
		_content.add_child(head)
		var body := Label.new()
		var lines := []
		for line in section[1]:
			# The key table keeps its columns; everything else gets a bullet.
			lines.append(line if section[0] == "KEYS" else "- " + line)
		body.text = "\n".join(lines)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(body)
		_wrapping.append(body)

	var buttons := HBoxContainer.new()
	var again := Button.new()
	again.text = "Show tips again"
	again.tooltip_text = "Replay the first-time tips from the start."
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func():
		hide()
		tips_reset_requested.emit())
	buttons.add_child(again)
	var news := Button.new()
	news.text = "What's new"
	news.tooltip_text = "What changed in the latest versions."
	news.focus_mode = Control.FOCUS_NONE
	news.pressed.connect(func():
		hide()
		whats_new_requested.emit())
	buttons.add_child(news)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	buttons.add_child(close)
	_content.add_child(buttons)

	resized.connect(_fit)
	visibility_changed.connect(_fit)
	_content.minimum_size_changed.connect(_fit)


# As wide as reads comfortably, never bigger than the window; scrolls if short.
func _fit() -> void:
	if _content == null:
		return
	var w := clampf(size.x - 48.0, 200.0, 520.0)
	for l in _wrapping:
		l.custom_minimum_size.x = w - 14.0
	_scroll.custom_minimum_size.x = w
	_scroll.custom_minimum_size.y = minf(_content.get_combined_minimum_size().y, maxf(80.0, size.y - 48.0))


func toggle() -> void:
	visible = not visible
	if visible:
		_scroll.scroll_vertical = 0
