extends Object

var handlers: Dictionary = {
	"goto": preload("res://addons/godot_vim/commands/goto.gd"),
	"find": preload("res://addons/godot_vim/commands/find.gd"),
	"marks": preload("res://addons/godot_vim/commands/marks.gd"),
	"delmarks": preload("res://addons/godot_vim/commands/delmarks.gd"),
	"moveline": preload("res://addons/godot_vim/commands/moveline.gd"),
	"movecolumn": preload("res://addons/godot_vim/commands/movecolumn.gd"),
	
	# GodotVIM speficic commands:
	"reload": preload("res://addons/godot_vim/commands/reload.gd"),
	"remap": preload("res://addons/godot_vim/commands/remap.gd"),
}

var aliases: Dictionary = {
	"delm": ":delmarks"
}

var globals: Dictionary

## Returns [enum @GlobalScope.Error]
func dispatch(command : String, do_allow_aliases: bool = true) -> int:
	var command_idx_end: int = command.find(' ', 1)
	if command_idx_end == -1:
		command_idx_end = command.length()
	var handler_name: String = command.substr(1, command_idx_end-1)
	
	if do_allow_aliases and aliases.has(handler_name):
		return dispatch( aliases[handler_name], false )
	
	if not handlers.has(handler_name):
		return ERR_DOES_NOT_EXIST
	
	var handler = handlers.get(handler_name)
	var handler_instance = handler.new()
	var args: String = command.substr(command_idx_end, command.length())
	handler_instance.execute(globals, args)
	return OK
