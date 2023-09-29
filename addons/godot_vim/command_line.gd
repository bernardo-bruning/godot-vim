extends LineEdit

const Cursor = preload("res://addons/godot_vim/cursor.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Constants = preload("res://addons/godot_vim/constants.gd")
const Dispatcher = preload("res://addons/godot_vim/dispatcher.gd")
const Mode = Constants.Mode

const Marks = preload("res://addons/godot_vim/commands/marks.gd")
const Goto = preload("res://addons/godot_vim/commands/goto.gd")
const Find = preload("res://addons/godot_vim/commands/find.gd")

var code_edit: CodeEdit
var cursor: Cursor
var status_bar: StatusBar
var globals: Dictionary
var dispatcher: Dispatcher

var is_paused: bool = false
var search_pattern: String = ''

func _ready():
	dispatcher = Dispatcher.new()
	dispatcher.globals = globals
	placeholder_text = "Enter command..."
	show()
	
	text_submitted.connect(_on_text_submitted)
	text_changed.connect(_on_text_changed)
	editable = true

func set_command(cmd: String):
	text = cmd
	caret_column = text.length()

func _on_text_changed(cmd: String):
	if !cmd.begins_with('/'):	return
	var pattern: String = cmd.substr(1)
	var rmatch: RegExMatch = globals.vim_plugin.search_regex(
		code_edit,
		pattern,
		cursor.get_caret_pos() + Vector2i.RIGHT
	)
	if rmatch == null:
		code_edit.remove_secondary_carets()
		return
	var pos: Vector2i = globals.vim_plugin.idx_to_pos(code_edit, rmatch.get_start())
	if code_edit.get_caret_count() < 2:
		code_edit.add_caret(pos.y, pos.x)
	code_edit.select(pos.y, pos.x, pos.y, pos.x + rmatch.get_string().length(), 1)
	code_edit.scroll_vertical = code_edit.get_scroll_pos_for_line(pos.y)

func handle_command(cmd: String):
	if cmd.begins_with('/'):
		var find = Find.new()
		find.execute(globals, cmd)
		return
	
	if cmd.trim_prefix(':').is_valid_int():
		var goto = Goto.new()
		goto.execute(globals, cmd.trim_prefix(':'))
		return
	
	if dispatcher.dispatch(cmd) == OK:
		set_paused(true)
		return

	status_bar.display_error('Unknown command: "%s"' % [ cmd.trim_prefix(':') ])
	set_paused(true)

func close():
	hide()
	clear()
	set_paused(false)

func set_paused(paused: bool):
	is_paused = paused
	text = "Press ENTER to continue" if is_paused else ""
	editable = !is_paused

func _on_text_submitted(new_text: String):
	if is_paused:
		cursor.set_mode(Mode.NORMAL)
		status_bar.main_label.text = ''
		return
	handle_command(new_text)
