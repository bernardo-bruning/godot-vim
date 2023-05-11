@tool
extends EditorPlugin

enum Mode { NORMAL_MODE, INSERT_MODE, SELECTION_MODE };

class Cursor:
	extends Control
	var code_edit: CodeEdit
	var mode: Mode = Mode.NORMAL_MODE
	var caret: Vector2
	var selection: PackedVector2Array
	
	func _init():
		set_focus_mode(FOCUS_ALL)

	func _ready():
		code_edit.connect("focus_entered", focus_entered)
		code_edit.connect("caret_changed", cursor_changed)
	
	func cursor_changed():
		draw_cursor()

	func focus_entered():
		if mode == Mode.NORMAL_MODE:
			code_edit.release_focus()
			self.grab_focus()
	
	func _unhandled_input(event):
		if Input.is_key_pressed(KEY_ESCAPE):
				mode = Mode.NORMAL_MODE
				code_edit.release_focus()
				self.grab_focus()
				return
		draw_cursor()
	
	func _input(event):
		if not has_focus():
			return
		if not event is InputEventKey:
			return
		if not event.pressed:
			return
		if mode == Mode.NORMAL_MODE or mode == Mode.SELECTION_MODE:
			if event.keycode == KEY_D:
				if mode == Mode.NORMAL_MODE:
					var line = code_edit.get_line(code_edit.get_caret_line())
					code_edit.select(code_edit.get_caret_line(), 0, code_edit.get_caret_line()+1, 0)
				code_edit.copy()
				code_edit.delete_selection()
				move_column(0)
				
			if event.keycode == KEY_4 && Input.is_key_pressed(KEY_SHIFT):
				set_column(code_edit.get_line(code_edit.get_selection_to_line()).length())
			if event.keycode == KEY_G && Input.is_key_pressed(KEY_SHIFT):
				set_line(code_edit.get_line_count())
			elif event.keycode == KEY_G && not Input.is_key_pressed(KEY_SHIFT):
				set_line(0)
			if event.keycode == KEY_0:
				set_column(0)
			if event.keycode == KEY_H:
				move_column(-1)
			if event.keycode == KEY_J:
				move_line(+1)
			if event.keycode == KEY_K:
				move_line(-1)
			if event.keycode == KEY_L:
				move_column(+1)
			if event.keycode == KEY_I:
				insert_mode()
			if event.keycode == KEY_V:
				mode = Mode.SELECTION_MODE
			if event.keycode == KEY_O:
				insert_mode()
				code_edit.insert_line_at(get_line()+1, "")
				move_line(+1)
			if event.keycode == KEY_A:
				insert_mode()
				move_column(+1)
			if event.keycode == KEY_W:
				move_column(max(code_edit.get_word_under_caret().length(), 1))
			if event.keycode == KEY_B:
				move_column(-max(code_edit.get_word_under_caret().length(), 1))
			if event.keycode == KEY_Y:
				code_edit.copy()
			if event.keycode == KEY_P:
				code_edit.paste()
			if event.keycode == KEY_C:
				code_edit.delete_selection()
				insert_mode()
			if event.keycode == KEY_U:
				code_edit.undo()
			if event.keycode == KEY_R and Input.is_key_pressed(KEY_CTRL):
				code_edit.redo()
	
	func insert_mode():
		mode = Mode.INSERT_MODE
		code_edit.call_deferred("grab_focus")
	
	func move_line(offset:int):
		set_line(get_line() + offset)
	
	func get_line():
		if mode == Mode.SELECTION_MODE:
			return code_edit.get_selection_to_line()
		return code_edit.get_caret_line()
		
	func set_line(position:int):
		if mode == Mode.SELECTION_MODE:
			code_edit.select(code_edit.get_selection_from_line(), code_edit.get_selection_from_column(), position, code_edit.get_selection_to_column())
			return
		code_edit.set_caret_line(min(position, code_edit.get_line_count()-1))
		
	func move_column(offset:int):
		set_column(get_column()+offset)
		
	func get_column():
		if mode == Mode.SELECTION_MODE:
			return code_edit.get_selection_to_column()
		return code_edit.get_caret_column()
		
	func set_column(position):
		if mode == Mode.SELECTION_MODE:
			code_edit.select(code_edit.get_selection_from_line(), code_edit.get_selection_from_column(), code_edit.get_selection_to_line(), position)
			return
		var line = code_edit.get_line(code_edit.get_caret_line())
		code_edit.set_caret_column(min(line.length(), position))
	
	func draw_cursor():
		if mode == Mode.SELECTION_MODE:
			return
			
		if mode == Mode.INSERT_MODE:
			if code_edit.has_selection():
				code_edit.deselect()
			return
		
		var line = code_edit.get_line(code_edit.get_caret_line())
		var length = line.length()
		if mode == Mode.NORMAL_MODE:
			length = length - 1
		var column = min(code_edit.get_caret_column(), length)
		
		code_edit.select(code_edit.get_caret_line(), column, code_edit.get_caret_line(), column+1)

var cursor

func _enter_tree():
	if get_code_edit() != null:
		_load()
	get_editor_interface().get_script_editor().connect("editor_script_changed", _script_changed)

func _script_changed(_script):
	_load()

func _load():
	if cursor != null:
		cursor.queue_free()
	cursor = Cursor.new()
	var code_edit = get_code_edit()
	var caret = code_edit.get_caret_line()
	code_edit.select(code_edit.get_caret_line(), code_edit.get_caret_column(), code_edit.get_caret_line(), code_edit.get_caret_column()+1)
	cursor.code_edit = code_edit
	if get_editor_interface().get_script_editor().get_current_editor() != null:
		get_editor_interface().get_script_editor().get_current_editor().add_child(cursor)
	

func get_code_edit():
	var editor = get_editor_interface().get_script_editor().get_current_editor();
	return _select(editor, ['VSplitContainer', 'CodeTextEditor', 'CodeEdit'])

func _select(obj, types):
	for type in types:
		for child in obj.get_children():
			if child.is_class(type):
				obj = child
				continue
	return obj

func _exit_tree():
	if cursor != null:
		cursor.queue_free()
	pass
