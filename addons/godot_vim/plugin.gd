@tool
extends EditorPlugin

const SPACES: String = " \t"
const KEYWORDS: String = ".,\"'-=+!@#$%^&*()[]{}?~/\\<>:;"
const DIGITS: String = "0123456789"
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const CommandLine = preload("res://addons/godot_vim/command_line.gd")
const Cursor = preload("res://addons/godot_vim/cursor.gd")
const Dispatcher = preload("res://addons/godot_vim/dispatcher.gd")

var cursor: Cursor
var key_map: KeyMap
var command_line: CommandLine
var status_bar: StatusBar
var globals: Dictionary = {}
var dispatcher: Dispatcher

func _enter_tree():
	EditorInterface.get_script_editor().connect("editor_script_changed", _on_script_changed)
	
	var shader_tabcontainer = get_shader_tabcontainer() as TabContainer
	# TODO handle shader_tabcontainer == null
	shader_tabcontainer.tab_changed.connect(_on_shader_tab_changed)
	shader_tabcontainer.visibility_changed.connect(_on_shader_tab_visibility_changed)
	
	globals = {}
	initialize(true)


func initialize(forced: bool = false):
	_load(forced)
	
	print("[Godot VIM] Initialized.")
	print("    If you wish to set keybindings, please run :remap in the command line")


func _on_script_changed(script: Script):
	if !script:
		return
	
	mark_recent_file(script.resource_path)
	
	_load()

func _on_shader_tab_changed(_tab: int):
	call_deferred(&"_load")

func _on_shader_tab_visibility_changed():
	call_deferred(&"_load")


func mark_recent_file(path: String):
	if !globals.has("marks"):
		globals.marks = {}
	var marks: Dictionary = globals.marks
	
	# Check if path is already in the recent files (stored in start_index)
	# This is to avoid flooding the recent files list with the same files
	var start_index: int = 0
	while start_index <= 9:
		var m: String = str(start_index)
		if !marks.has(m) or marks[m].file == path: # Found
			break
		start_index += 1
	
	# Shift all files from start_index down one
	for i in range(start_index, -1, -1):
		var m: String = str(i)
		var prev_m: String = str(i - 1)
		if !marks.has(prev_m):
			continue
		marks[m] = marks[prev_m]
	
	# Mark "-1" won't be accessible to the user
	# It's just the current file, and will be indexed next time the
	# loop above ^^^ is called
	marks['-1'] = { 'file' : path, 'pos' : Vector2i(-1, 0) }


func edit_script(path: String, pos: Vector2i):
	var script = load(path)
	if script == null:
		status_bar.display_error('Could not open file "%s"' % path)
		return ''
	EditorInterface.edit_script(script, pos.y, pos.x)

#region LOAD

# TODO better dependency management

func _init_cursor(code_edit: CodeEdit, is_editing_shader: bool):
	if cursor != null:
		cursor.queue_free()
	
	cursor = Cursor.new()
	code_edit.select(code_edit.get_caret_line(), code_edit.get_caret_column(), code_edit.get_caret_line(), code_edit.get_caret_column()+1)
	cursor.code_edit = code_edit
	cursor.globals = globals

func _init_command_line(code_edit: CodeEdit):
	if command_line != null:
		command_line.queue_free()
	command_line = CommandLine.new()
	
	command_line.code_edit = code_edit
	cursor.command_line = command_line
	command_line.cursor = cursor
	command_line.globals = globals
	command_line.hide()

func _init_status_bar():
	if status_bar != null:
		status_bar.queue_free()
	status_bar = StatusBar.new()
	cursor.status_bar = status_bar
	command_line.status_bar = status_bar


func _load(forced: bool = false):
	if globals == null:
		globals = {}
	
	var result: Dictionary = find_code_edit()
	# TODO handle result.is_empty()
	var code_edit: CodeEdit = result.code_edit
	var is_editing_shader: bool = result.is_shader
	
	_init_cursor(code_edit, is_editing_shader)
	_init_command_line(code_edit)
	_init_status_bar()
	
	# KeyMap
	if key_map == null or forced:
		key_map = KeyMap.new(cursor)
	else:
		key_map.cursor = cursor
	cursor.key_map = key_map
	
	var script_editor = EditorInterface.get_script_editor()
	if script_editor == null:	return
	var script_editor_base = script_editor.get_current_editor()
	if script_editor_base == null:	return
	
	globals.command_line = command_line
	globals.status_bar = status_bar
	globals.code_edit = code_edit
	globals.cursor = cursor
	globals.script_editor = script_editor
	globals.vim_plugin = self
	globals.key_map = key_map
	
	dispatcher = Dispatcher.new()
	dispatcher.globals = globals
	
	# Add nodes
	if !is_editing_shader:
		code_edit.add_child(cursor)
		script_editor_base.add_child(status_bar)
		script_editor_base.add_child(command_line)
		return
	
	var shaders_container = code_edit
	for i in 3:
		shaders_container = shaders_container.get_parent()
	# TODO handle shaders_container == null
	
	code_edit.add_child(cursor)
	shaders_container.add_child(status_bar)
	shaders_container.add_child(command_line)

#endregion LOAD

func dispatch(command: String):
	return dispatcher.dispatch(command)


# TODO documentation
func find_code_edit() -> Dictionary:
	var code_edit: CodeEdit = get_shader_code_edit()
	var is_shader: bool = true
	# Shader panel not open; normal gdscript code edit
	if code_edit == null:
		code_edit = get_regular_code_edit()
		is_shader = false
	if code_edit == null:
		return {}
	
	return {
		"code_edit": code_edit,
		"is_shader": is_shader,
	}

func get_regular_code_edit():
	var editor = EditorInterface.get_script_editor().get_current_editor()
	return _select(editor, ['VSplitContainer', 'CodeTextEditor', 'CodeEdit'])

func get_shader_code_edit():
	var container = get_shader_tabcontainer()
	# TODO handle container == null
	
	# Panel not open
	if !container.is_visible_in_tree():
		return
	
	var editors = container.get_children(false)
	for tse in editors:
		if !tse.visible: # Not open
			continue
		
		var code_edit = _select(tse, [
			"VBoxContainer",
			"VSplitContainer",
			"ShaderTextEditor",
			"CodeEdit"
		])
		# TODO handle code_edit == null
		
		# if !code_edit.has_focus():
			# return
		return code_edit

## Returns Option<TabContainer> (aka either TabContainer or null if it fails)
func get_shader_tabcontainer():
	# Get the VSplitContainer containing the script editor and bottom panels
	var container = EditorInterface.get_script_editor()
	for i in 6:
		container = container.get_parent()
	# TODO handle container == null
	
	# Get code edit
	container = _select(container, [
		"PanelContainer",
		"VBoxContainer",
		"WindowWrapper",
		"HSplitContainer",
		"TabContainer"
	])
	return container


func _select(obj: Node, types: Array[String]):
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


## Repeat the function `f` and accumulate the result. A bit like Array::reduce()
## f: func(T) -> T  where T is the previous output
func repeat_accum(count: int, inital_value: Variant, f: Callable) -> Variant:
	var value: Variant = inital_value
	for __ in count:
		value = f.call(value)
	return value

