@tool
extends EditorPlugin

enum Mode { NORMAL, INSERT, VISUAL, VISUAL_LINE, COMMAND }

# Used for commands like "w" "b" and "e" respectively
enum WordEdgeMode { WORD, BEGINNING, END }

const SPACES: String = " \t"
const KEYWORDS: String = ".,\"'-=+!@#$%^&*()[]{}?~/\\<>:;"
const DIGITS: String = "0123456789"
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const CommandLine = preload("res://addons/godot_vim/command_line.gd")
const Cursor = preload("res://addons/godot_vim/cursor.gd")

var cursor: Cursor
var command_line: CommandLine
var status_bar: StatusBar
var globals: Dictionary = {}

func _enter_tree():
	globals = {}
	
	if get_code_edit() != null:
		_load()
	get_editor_interface().get_script_editor().connect("editor_script_changed", _script_changed)

func _script_changed(script: Script):
	# Add to recent files
	var path: String = script.resource_path
	var marks: Dictionary = globals.get('marks', {})
	for i in range(9, -1, -1):
		var m: String = str(i)
		var pm: String = str(i - 1)
		if !marks.has(pm):
			continue
		marks[m] = marks[pm]
	marks['-1'] = { 'file' : path, 'pos' : Vector2i(-1, 0) }
	
	_load()


func edit_script(path: String, pos: Vector2i):
	var script = load(path)
	var editor_interface: EditorInterface = globals.editor_interface
	if script == null:
		status_bar.display_error('Could not open file "%s"' % path)
		return ''
	editor_interface.edit_script(script)
	cursor.call_deferred('set_caret_pos', pos.y, pos.x)


func _load():
	if globals == null:
		globals = {}
	
	# Cursor
	if cursor != null:
		cursor.queue_free()
	cursor = Cursor.new()
	var code_edit = get_code_edit()
	code_edit.select(code_edit.get_caret_line(), code_edit.get_caret_column(), code_edit.get_caret_line(), code_edit.get_caret_column()+1)
	cursor.code_edit = code_edit
	cursor.globals = globals
	
	# Command line
	if command_line != null:
		command_line.queue_free()
	command_line = CommandLine.new()
	command_line.code_edit = code_edit
	cursor.command_line = command_line
	command_line.cursor = cursor
	command_line.globals = globals
	command_line.hide()
	
	# Status bar
	if status_bar != null:
		status_bar.queue_free()
	status_bar = StatusBar.new()
	cursor.status_bar = status_bar
	command_line.status_bar = status_bar
	
	var editor_interface = get_editor_interface()
	if editor_interface == null:	return
	var script_editor = editor_interface.get_script_editor()
	if script_editor == null:	return
	var script_editor_base = script_editor.get_current_editor()
	if script_editor_base == null:	return
	
	globals.editor_interface = editor_interface
	globals.command_line = command_line
	globals.status_bar = status_bar
	globals.code_edit = code_edit
	globals.cursor = cursor
	globals.script_editor = script_editor
	globals.vim_plugin = self
	script_editor_base.add_child(cursor)
	script_editor_base.add_child(status_bar)
	script_editor_base.add_child(command_line)


func get_code_edit():
	var editor = get_editor_interface().get_script_editor().get_current_editor()
	return _select(editor, ['VSplitContainer', 'CodeTextEditor', 'CodeEdit'])

func _select(obj: Node, types: Array[String]): # ???
	for type in types:
		for child in obj.get_children():
			if child.is_class(type):
				obj = child
				continue
	return obj

func _exit_tree():
	if cursor != null:
		cursor.queue_free()
	if command_line != null:
		command_line.queue_free()
	if status_bar != null:
		status_bar.queue_free()


# -------------------------------------------------------------
# ** UTIL **
# -------------------------------------------------------------

func search_regex(text_edit: TextEdit, pattern: String, from_pos: Vector2i) -> RegExMatch:
	var regex: RegEx = RegEx.new()
	var err: int = regex.compile(pattern)
	var idx: int = pos_to_idx(text_edit, from_pos)
	var res: RegExMatch = regex.search(text_edit.text, idx)
	if res == null:
		return regex.search(text_edit.text, 0)
	return res

func search_regex_backwards(text_edit: TextEdit, pattern: String, from_pos: Vector2i) -> RegExMatch:
	var regex: RegEx = RegEx.new()
	var err: int = regex.compile(pattern)
	var idx: int = pos_to_idx(text_edit, from_pos)
	# We use pop_back() so it doesn't print an error
	var res: RegExMatch = regex.search_all(text_edit.text, 0, idx).pop_back()
	if res ==  null:
		return regex.search_all(text_edit.text).pop_back()
	return res

func pos_to_idx(text_edit: TextEdit, pos: Vector2i) -> int:
	text_edit.select(0, 0, pos.y, pos.x)
	var len: int = text_edit.get_selected_text().length()
	text_edit.deselect()
	return len

func idx_to_pos(text_edit: TextEdit, idx: int) -> Vector2i:
	var line: int = text_edit.text .count('\n', 0, idx)
	var col: int = idx - text_edit.text .rfind('\n', idx) - 1
	return Vector2i(col, line)

func get_first_non_digit_idx(str: String) -> int:
	if str.is_empty():	return -1
	if str[0] == '0':	return 0 # '0...' is an exception
	for i in str.length():
		if !DIGITS.contains(str[i]):
			return i
	return -1 # All digits

