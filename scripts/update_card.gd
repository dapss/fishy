# "A new version is out" card: what's new, then Update / Later.
# While downloading it shows progress; the main scene does the restart.
extends Control

signal update_pressed
signal later_pressed

var _title: Label
var _scroll: ScrollContainer
var _body: Label
var _status: Label
var _later: Button
var _update: Button
var _page := ""
var _self_update := true
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
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scroll.add_child(_body)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("7fcf9f"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_later = Button.new()
	_later.text = "Later"
	_later.focus_mode = Control.FOCUS_NONE
	_later.pressed.connect(func():
		hide()
		later_pressed.emit())
	row.add_child(_later)
	_update = Button.new()
	_update.focus_mode = Control.FOCUS_NONE
	_update.pressed.connect(_on_update)
	row.add_child(_update)
	vb.add_child(row)

	resized.connect(_fit)
	_body.minimum_size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	if _body == null:
		return
	var w := clampf(max_width - 40.0, 180.0, 440.0)
	_body.custom_minimum_size.x = w - 14.0
	_status.custom_minimum_size.x = w
	_scroll.custom_minimum_size.x = w
	# Title, status, buttons and padding take roughly 140 px.
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, maxf(30.0, size.y - 140.0))


# self_update false: this copy can't replace itself, so the button opens
# the download page instead.
func open(info: Dictionary, current: String, self_update: bool) -> void:
	_page = info.get("page", "")
	_self_update = self_update and str(info.get("url", "")) != ""
	_title.text = "-- fishy v%s is out --" % info.version
	var notes := _clean_notes(str(info.get("notes", "")))
	_body.text = "You have v%s. Your fish and coins stay as they are.%s" % [current, ("\n\nWhat's new:\n" + notes) if notes != "" else ""]
	_update.text = "Update and restart" if _self_update else "Open download page"
	_update.disabled = false
	_later.disabled = false
	_status.text = ""
	_status.visible = false
	_scroll.scroll_vertical = 0
	show()
	_fit.call_deferred()


func set_progress(fraction: float) -> void:
	_status.visible = true
	_status.add_theme_color_override("font_color", Color("7fcf9f"))
	_status.text = "Downloading... %d%%" % int(fraction * 100.0)


func set_failed(reason: String) -> void:
	_status.visible = true
	_status.add_theme_color_override("font_color", Color("ff8a8a"))
	_status.text = "Update failed (%s). Nothing changed." % reason
	_update.disabled = false
	_later.disabled = false
	_update.text = "Try again"


func _on_update() -> void:
	if not _self_update:
		if _page != "":
			OS.shell_open(_page)
		hide()
		return
	_update.disabled = true
	_later.disabled = true
	set_progress(0.0)
	update_pressed.emit()


# GitHub release notes are Markdown; show them as plain text, not too long.
func _clean_notes(md: String) -> String:
	var out := []
	for line in md.replace("\r", "").split("\n"):
		var l := line.strip_edges()
		if l == "":
			continue
		if l.begins_with("#"):
			continue          # headings like "## What's new" repeat our own
		l = l.replace("**", "").replace("`", "")
		if l.begins_with("* ") or l.begins_with("- "):
			l = "- " + l.substr(2)
		out.append(l)
		if out.size() >= 12:
			out.append("...")
			break
	return "\n".join(out)
