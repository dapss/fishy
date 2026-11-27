# Player preferences (window mode, layout, frame rate, window placement).
# Stored apart from the game save so resetting progress keeps your layout.
extends RefCounted

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"borderless": false,
	"on_top": false,
	"transparent": false,
	"layout": "auto",        # auto | full | compact
	"fps": 30,
	"win_x": -1,             # -1 = let the OS place the window
	"win_y": -1,
	"win_w": 1000,
	"win_h": 640,
}

var values := DEFAULTS.duplicate()


func load_file() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEFAULTS:
		var v = cf.get_value("settings", k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]):
			values[k] = v


func save_file() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)
