const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode

func execute(api : Dictionary, args: String):
	api.command_line.search_pattern = args.substr(1)
	var rmatch: RegExMatch = api.vim_plugin.search_regex(
		api.code_edit,
		api.command_line.search_pattern,
		api.cursor.get_caret_pos() + Vector2i.RIGHT
	)
	if rmatch != null:
		var pos: Vector2i = api.vim_plugin.idx_to_pos(api.code_edit, rmatch.get_start())
		api.cursor.set_caret_pos(pos.y, pos.x)
	else:
		api.status_bar.display_error('Pattern not found: "%s"' % [api.command_line.search_pattern])
	api.cursor.set_mode(Mode.NORMAL)
