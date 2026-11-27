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
	"volume": 60,            # 0..100
	"ui_scale": 1.0,
	"eco": true,             # drop to a low frame rate while the window isn't focused
	"widget": "normal",      # tiny | small | normal: size used by "snap widget"
	"tray": false,           # closing / minimizing hides to the system tray
	"autostart": false,      # cached; the Windows registry is the real source
	"update_check": true,    # look for a new version on launch
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
