const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode


func execute(api, args: String):
	#EditorInterface.save_scene()
	press_save_shortcut()
	api.cursor.set_mode(Mode.NORMAL)


func press_save_shortcut():
	var a = InputEventKey.new()
	a.keycode = KEY_S
	a.ctrl_pressed = true
	a.alt_pressed = true
	a.pressed = true
	Input.parse_input_event(a)
	pass
