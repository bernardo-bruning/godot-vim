const Contants = preload("res://addons/godot_vim/constants.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Mode = Contants.Mode

func execute(api: Dictionary, _args):
	print("[Godot VIM] Please run :reload in the command line after changing your keybinds")
	var script: Script = api.key_map.get_script()
	# Line 45 is where KeyMap::map() is
	EditorInterface.edit_script(script, 40, 0, false)
	

