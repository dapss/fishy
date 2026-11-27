# Bottom-right corner grip for resizing the window when it has no border.
extends Control

const SIZE := 18.0
const COLOR := Color("3a6b8a")
const COLOR_HOVER := Color("5fb3d9")

var _hover := false


func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -SIZE
	offset_top = -SIZE
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	tooltip_text = "Drag to resize"
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func _draw() -> void:
	var c := COLOR_HOVER if _hover else COLOR
	for i in 3:
		var d := 4.0 + i * 4.0
		draw_line(Vector2(size.x - d, size.y - 2.0), Vector2(size.x - 2.0, size.y - d), c, 1.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_window().start_resize(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT)
		accept_event()
