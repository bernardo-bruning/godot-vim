const Contants = preload("res://addons/godot_vim/constants.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Mode = Contants.Mode

const LINE_START_IDX: int = 8
const COL_START_IDX: int = 16
const FILE_START_IDX: int = 25


func execute(api: Dictionary, _args):
	api.marks = {}
	
	api.status_bar.display_text("Deleted all marks")
	api.cursor.set_mode(Mode.NORMAL)


