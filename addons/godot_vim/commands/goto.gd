const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode

func execute(api, args):
	api.cursor.set_caret_pos(args.to_int(), 0)
	api.cursor.set_mode(Mode.NORMAL)
