const Contants = preload("res://addons/godot_vim/constants.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Mode = Contants.Mode

func execute(api: Dictionary, _args):
	print("[Godot VIM] Reloading...")
	api.status_bar.display_text("Reloading plugin...", Control.TEXT_DIRECTION_LTR)
	api.vim_plugin.initialize(true)

