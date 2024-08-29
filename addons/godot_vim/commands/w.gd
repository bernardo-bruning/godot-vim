const Constants = preload("res://addons/godot_vim/constants.gd")
const MODE = Constants.Mode


func execute(api, _args: String):
	#EditorInterface.save_scene()
	press_save_shortcut()
	api.cursor.set_mode(MODE.NORMAL)


func press_save_shortcut():
	var a = InputEventKey.new()
	a.keycode = KEY_S
	a.ctrl_pressed = true
	a.alt_pressed = true
	a.pressed = true
	Input.parse_input_event(a)
