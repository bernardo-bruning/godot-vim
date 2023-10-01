extends Object

var handlers = {
	"goto": preload("res://addons/godot_vim/commands/goto.gd"),
	"find": preload("res://addons/godot_vim/commands/find.gd"),
	"marks": preload("res://addons/godot_vim/commands/marks.gd")
}

var globals

func dispatch(command : String):
	var command_idx_end = command.find(' ', 1)
	if command_idx_end == -1: command_idx_end = command.length()
	var handler_name = command.substr(1, command_idx_end-1)
	if not handlers.has(handler_name):
		return ERR_DOES_NOT_EXIST
	
	var handler = handlers.get(handler_name)
	var handler_instance = handler.new()
	var args = command.substr(command_idx_end, command.length())
	handler_instance.execute(globals, args)
	return OK
