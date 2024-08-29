const Constants = preload("res://addons/godot_vim/constants.gd")
const MODE = Constants.Mode


func execute(api, args):
	api.cursor.set_caret_pos(args.to_int() - 1, 0)
	api.cursor.set_mode(MODE.NORMAL)
