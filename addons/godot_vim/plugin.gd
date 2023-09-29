@tool
extends EditorPlugin

enum Mode { NORMAL, INSERT, VISUAL, VISUAL_LINE, COMMAND }

# Used for commands like "w" "b" and "e" respectively
enum WordEdgeMode { WORD, BEGINNING, END }

const SPACES: String = " \t"
const KEYWORDS: String = ".,\"'-=+!@#$%^&*()[]{}?~/\\<>:;"
const DIGITS: String = "0123456789"


class StatusBar:
	extends HBoxContainer
	const ERROR_COLOR: String = "#ff8866"
	const SPECIAL_COLOR: String = "#fcba03"
	
	var mode_label: Label
	var main_label: RichTextLabel
	
	func _ready():
		var font = load("res://addons/godot_vim/hack_regular.ttf")
		
		mode_label = Label.new()
		
		mode_label.text = ''
		mode_label.add_theme_color_override(&"font_color", Color.BLACK)
		var stylebox: StyleBoxFlat = StyleBoxFlat.new()
		stylebox.bg_color = Color.GOLD
		stylebox.content_margin_left = 4.0
		stylebox.content_margin_right = 4.0
		stylebox.content_margin_top = 2.0
		stylebox.content_margin_bottom = 2.0
		mode_label.add_theme_stylebox_override(&"normal", stylebox)
		mode_label.add_theme_font_override(&"font", font)
		add_child(mode_label)
		
		main_label = RichTextLabel.new()
		main_label.bbcode_enabled = true
		main_label.text = ''
		main_label.fit_content = true
		main_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_label.text_direction = Control.TEXT_DIRECTION_RTL
		main_label.add_theme_font_override(&"normal_font", font)
		add_child(main_label)
	
	func display_text(text: String, text_direction: Control.TextDirection = TEXT_DIRECTION_RTL):
		main_label.text = text
		main_label.text_direction = text_direction
	
	func display_error(text: String):
		main_label.text = '[color=%s]%s' % [ERROR_COLOR, text]
		main_label.text_direction = Control.TEXT_DIRECTION_LTR
	
	func display_special(text: String):
		main_label.text = '[color=%s]%s' % [SPECIAL_COLOR, text]
		main_label.text_direction = Control.TEXT_DIRECTION_LTR
	
	func set_mode_text(mode: Mode):
		var stylebox: StyleBoxFlat = mode_label.get_theme_stylebox(&"normal")
		match mode:
			Mode.NORMAL:
				mode_label.text = 'NORMAL'
				stylebox.bg_color = Color.LIGHT_SALMON
			Mode.INSERT:
				mode_label.text = 'INSERT'
				stylebox.bg_color = Color.POWDER_BLUE
			Mode.VISUAL:
				mode_label.text = 'VISUAL'
				stylebox.bg_color = Color.PLUM
			Mode.VISUAL_LINE:
				mode_label.text = 'VISUAL LINE'
				stylebox.bg_color = Color.PLUM
			Mode.COMMAND:
				mode_label.text = 'COMMAND'
				stylebox.bg_color = Color.TOMATO
			_:
				pass



class CommandLine:
	extends LineEdit
	
	var code_edit: CodeEdit
	var cursor: Cursor
	var status_bar: StatusBar
	var globals: Dictionary
	
	var is_paused: bool = false
	var search_pattern: String = ''
	
	func _ready():
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
			search_pattern = cmd.substr(1)
			var rmatch: RegExMatch = globals.vim_plugin.search_regex(
				code_edit,
				search_pattern,
				cursor.get_caret_pos() + Vector2i.RIGHT
			)
			if rmatch != null:
				var pos: Vector2i = globals.vim_plugin.idx_to_pos(code_edit, rmatch.get_start())
				cursor.set_caret_pos(pos.y, pos.x)
			else:
				status_bar.display_error('Pattern not found: "%s"' % [search_pattern])
			cursor.set_mode(Mode.NORMAL)
			return
		
		if cmd.trim_prefix(':').is_valid_int():
			var line: int = cmd.trim_prefix(':').to_int()
			cursor.set_caret_pos(line, 0)
			cursor.set_mode(Mode.NORMAL)
			return
		
		if cmd.begins_with(':marks'):
			var marks: Dictionary = globals.get('marks', {})
			if marks.is_empty():
				status_bar.display_error("No marks set")
				cursor.set_mode(Mode.NORMAL)
				return
			
			var display_mark = func(key: String, m: Dictionary) -> String:
				var pos: Vector2i = m.get('pos', Vector2i())
				var file: String = m.get('file', '')
				return "\n%s\t\t%s \t%s \t\t %s" % [key, pos.y, pos.x, file]
			
			var text: String = "[color=%s]List of all marks[/color]\nmark\tline\tcol \t file" % StatusBar.SPECIAL_COLOR
			for key in marks.keys():
				var unicode: int = key.unicode_at(0)
				if (unicode < 65 or unicode > 90) and (unicode < 97 or unicode > 122):
					continue
				text += display_mark.call(key, marks[key])
			for key in marks.keys():
				var unicode: int = key.unicode_at(0)
				if (unicode >= 65 and unicode <= 90) or (unicode >= 97 and unicode <= 122) or key == "-1":
					continue
				text += display_mark.call(key, marks[key])
			
			status_bar.display_text(text, TEXT_DIRECTION_LTR)
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





class Cursor:
	extends Control
	var code_edit: CodeEdit
	var command_line: CommandLine
	var status_bar: StatusBar
	
	var mode: Mode = Mode.NORMAL
	var caret: Vector2
	var input_stream: String = ""
	var selection_from: Vector2i = Vector2i() # For visual modes
	var selection_to: Vector2i = Vector2i() # For visual modes
	var globals: Dictionary = {}
	
	func _init():
		set_focus_mode(FOCUS_ALL)

	func _ready():
		code_edit.connect("focus_entered", focus_entered)
		code_edit.connect("caret_changed", cursor_changed)
		call_deferred('set_mode', Mode.NORMAL)
	
	func cursor_changed():
		draw_cursor()

	func focus_entered():
		if mode == Mode.NORMAL:
			code_edit.release_focus()
			self.grab_focus()
	
	func _input(event):
		if Input.is_key_pressed(KEY_ESCAPE):
			code_edit.cancel_code_completion()
			input_stream = ''
			set_mode(Mode.NORMAL)
			selection_from = Vector2i.ZERO
			selection_to = Vector2i.ZERO
			set_column(code_edit.get_caret_column())
			return
		draw_cursor()
		
		if !has_focus():	return
		if !event is InputEventKey:	return
		if !event.pressed:	return
		if mode == Mode.INSERT or mode == Mode.COMMAND:	return
		if event.keycode == KEY_ESCAPE:
			input_stream = ''
			return
		
		var ch: String = char(event.unicode)
		if Input.is_key_pressed(KEY_ENTER):
			ch = '<CR>'
		if Input.is_key_pressed(KEY_TAB):
			ch = '<TAB>'
		if Input.is_key_pressed(KEY_CTRL):
			if OS.is_keycode_unicode(event.keycode):
				var c: String = char(event.keycode)
				if !Input.is_key_pressed(KEY_SHIFT):
					c = c.to_lower()
				ch = '<C-%s>' % c
		
		input_stream += ch
		status_bar.display_text(input_stream)
		
		var s: int = globals.vim_plugin.get_first_non_digit_idx(input_stream)
		if s == -1:	return # All digits
		
		var cmd: String = input_stream.substr(s)
		var count: int = maxi( input_stream.left(s).to_int(), 1 )
		for i in count:
			input_stream = handle_input_stream(cmd)
	
	
	func handle_input_stream(stream: String) -> String:
		# BEHOLD, THE IF STATEMENT HELL!!! MUAHAHAHAHa
		if stream == 'h':
			move_column(-1)
			return ''
		if stream == 'j':
			move_line(+1)
			return ''
		if stream == 'k':
			move_line(-1)
			return ''
		if stream == 'l':
			move_column(+1)
			return ''
		if stream.to_lower().begins_with('w'):
			var p: Vector2i = get_word_edge_pos(get_line(), get_column(), '' if stream[0] == 'W' else KEYWORDS, WordEdgeMode.WORD)
			set_caret_pos(p.y, p.x)
			return ''
		if stream.to_lower().begins_with('e'):
			var p: Vector2i = get_word_edge_pos(get_line(), get_column(), '' if stream[0] == 'E' else KEYWORDS, WordEdgeMode.END)
			set_caret_pos(p.y, p.x)
			return ''
		if stream.to_lower().begins_with('b'):
			var p: Vector2i = get_word_edge_pos(get_line(), get_column(), '' if stream[0] == 'B' else KEYWORDS, WordEdgeMode.BEGINNING)
			set_caret_pos(p.y, p.x)
			return ''
		
		if stream.to_lower() .begins_with('f') or stream.to_lower() .begins_with('t'):
			if stream.length() == 1:	return stream
			
			var char: String = stream[1] # TODO check for <TAB>, <CR> and <Ctrl-somethign>
			globals.last_search = stream.left(2) # First 2 in case it's longer
			var col: int = find_char_motion(get_line(), get_column(), stream[0], char)
			if col >= 0:
				set_column(col)
			return ''
		if stream.begins_with(';') and globals.has('last_search'):
			var cmd: String = globals.last_search[0]
			var col: int = find_char_motion(get_line(), get_column(), cmd, globals.last_search[1])
			if col >= 0:
				set_column(col)
			return ''
		if stream.begins_with(',') and globals.has('last_search'):
			var cmd: String = globals.last_search[0]
			cmd = cmd.to_upper() if is_lowercase(cmd) else cmd.to_lower()
			var col: int = find_char_motion(get_line(), get_column(), cmd, globals.last_search[1])
			if col >= 0:
				set_column(col)
			return ''
		
		if mode == Mode.VISUAL: # TODO make it work for visual line too
			var range: Array = calc_double_motion_region(selection_to, stream)
			if range.size() == 1:	return stream
			if range.size() == 2:
				selection_from = range[0]
				selection_to = range[1]
				update_visual_selection()
		
		if stream.begins_with('J') and mode == Mode.NORMAL:
			code_edit.begin_complex_operation()
			code_edit.select( get_line(), get_line_length(), get_line()+1, code_edit.get_first_non_whitespace_column(get_line()+1) )
			code_edit.delete_selection()
			code_edit.deselect()
			code_edit.insert_text_at_caret(' ')
			code_edit.end_complex_operation()
			globals.last_command = stream
			return ''
		if stream.begins_with('d'):
			if is_mode_visual(mode):
				DisplayServer.clipboard_set( '\r' + code_edit.get_selected_text() )
				code_edit.delete_selection()
				move_line(+1)
				set_mode(Mode.NORMAL)
				return ''
			
			if stream.begins_with('dd') and mode == Mode.NORMAL:
				code_edit.select( get_line()-1, get_line_length(get_line()-1), get_line(), get_line_length() )
				DisplayServer.clipboard_set( '\r' + code_edit.get_selected_text() )
				code_edit.delete_selection()
				move_line(+1)
				globals.last_command = stream
				return ''
			
			var range: Array = calc_double_motion_region(get_caret_pos(), stream, 1)
			if range.size() == 0:	return ''
			if range.size() == 1:	return stream
			if range.size() == 2:
				code_edit.select(range[0].y, range[0].x, range[1].y, range[1].x + 1)
				code_edit.cut()
				globals.last_command = stream
			return ''
		
		if mode == Mode.NORMAL and stream.begins_with('D'):
			code_edit.select( get_line(), code_edit.get_caret_column(), get_line(), get_line_length() )
			code_edit.cut()
			globals.last_command = stream
			return ''
		if stream.begins_with('p'):
			code_edit.begin_complex_operation()
			if is_mode_visual(mode):
				code_edit.delete_selection()
			if DisplayServer.clipboard_get().begins_with('\r\n'):
				set_column(get_line_length())
			else:
				move_column(+1)
			code_edit.deselect()
			code_edit.paste()
			move_column(-1)
			code_edit.end_complex_operation()
			set_mode(Mode.NORMAL)
			globals.last_command = stream
			return ''
		if stream.begins_with('P'):
			status_bar.display_error("Unimplemented command: P")
			return ''
		if stream.begins_with('$'):
			set_column(get_line_length())
			return ''
		if stream.begins_with('^'):
			set_column( code_edit.get_first_non_whitespace_column(get_line()) )
			return ''
		if stream == 'G':
			set_line(code_edit.get_line_count())
			return ''
		if stream.begins_with('g'):
			if stream.begins_with('gg'):
				set_line(0)
				return ''
			
			if stream.begins_with('gc') and is_mode_visual(mode):
				code_edit.begin_complex_operation()
				for line in range( min(selection_from.y, selection_to.y), max(selection_from.y, selection_to.y)+1 ):
					toggle_comment(line)
				code_edit.end_complex_operation()
				set_mode(Mode.NORMAL)
				return ''
			if stream.begins_with('gcc') and mode == Mode.NORMAL:
				toggle_comment(get_line())
				globals.last_command = stream
				return ''
			return stream
		
		if stream == '0':
			set_column(0)
			return ''
		if stream == 'i' and mode == Mode.NORMAL:
			set_mode(Mode.INSERT)
			return ''
		if stream == 'a' and mode == Mode.NORMAL:
			set_mode(Mode.INSERT)
			move_column(+1)
			return ''
		if stream == 'I' and mode == Mode.NORMAL:
			set_column(code_edit.get_first_non_whitespace_column(get_line()))
			set_mode(Mode.INSERT)
			return ''
		if stream.begins_with('A') and mode == Mode.NORMAL:
			set_mode(Mode.INSERT)
			set_column(get_line_length())
			return ''
		if stream == 'v':
			set_mode(Mode.VISUAL)
			return ''
		if stream == 'V':
			set_mode(Mode.VISUAL_LINE)
			return ''
		if stream.begins_with('o'):
			if is_mode_visual(mode):
				var tmp: Vector2i = selection_from
				selection_from = selection_to
				selection_to = tmp
				return ''
			
			var ind: int = code_edit.get_first_non_whitespace_column(get_line())
			if code_edit.get_line(get_line()).ends_with(':'):
				ind += 1
			var line: int = code_edit.get_caret_line()
			code_edit.insert_line_at(line + int(line < code_edit.get_line_count() - 1), "\t".repeat(ind))
			move_line(+1)
			set_column(ind)
			set_mode(Mode.INSERT)
			globals.last_command = stream
			return ''
		if stream.begins_with('O') and mode == Mode.NORMAL:
			var ind: int = code_edit.get_first_non_whitespace_column(get_line())
			code_edit.insert_line_at(get_line(), "\t".repeat(ind))
			move_line(-1)
			set_column(ind)
			set_mode(Mode.INSERT)
			globals.last_command = stream
			return ''
		
		if stream == 'x':
			code_edit.copy()
			code_edit.delete_selection()
			globals.last_command = stream
			return ''
		if stream.begins_with('s'):
			code_edit.cut()
			set_mode(Mode.INSERT)
			return ''
		if stream == 'u':
			code_edit.undo()
			set_mode(Mode.NORMAL)
			return ''
		if stream.begins_with('<C-r>'):
			code_edit.redo()
			return ''
		if stream.begins_with('r') and mode == Mode.NORMAL:
			if stream.length() < 2:	return stream
			code_edit.begin_complex_operation()
			code_edit.delete_selection()
			var ch: String = stream[1]
			if stream.substr(1).begins_with('<CR>'):
				ch = '\n'
			elif stream.substr(1).begins_with('<TAB>'):
				ch = '\t'
			code_edit.insert_text_at_caret(ch)
			move_column(-1)
			code_edit.end_complex_operation()
			globals.last_command = stream
			return ''
		if stream.begins_with('y'):
			if is_mode_visual(mode):
				code_edit.copy()
				set_mode(Mode.NORMAL)
				return ''
			
			if stream.length() == 1:	return stream
			if stream.begins_with('yy') and mode == Mode.NORMAL:
				code_edit.select(code_edit.get_caret_line(), 0, code_edit.get_caret_line(), get_line_length())
				DisplayServer.clipboard_set( '\r\n' + code_edit.get_selected_text() )
				move_column(0)
				code_edit.deselect()
			
			var range: Array = calc_double_motion_region(get_caret_pos(), stream, 1)
			if range.size() == 0:	return ''
			if range.size() == 1:	return stream
			if range.size() == 2:
				code_edit.select(range[0].y, range[0].x, range[1].y, range[1].x + 1)
				code_edit.copy()
				code_edit.deselect()
			return ''
		
		if stream == '.':
			if globals.has('last_command'):
				handle_input_stream(globals.last_command)
				call_deferred(&'set_mode', Mode.NORMAL)
			return ''
		
		if stream.begins_with(':') and mode == Mode.NORMAL: # Could make this work with visual too ig
			set_mode(Mode.COMMAND)
			command_line.set_command(':')
			return ''
		if stream.begins_with('/') and mode == Mode.NORMAL:
			set_mode(Mode.COMMAND)
			command_line.set_command('/')
			return ''
		if stream.begins_with('n'):
			var rmatch: RegExMatch = globals.vim_plugin.search_regex(
				code_edit,
				command_line.search_pattern,
				get_caret_pos() + Vector2i.RIGHT
			)
			if rmatch != null:
				var pos: Vector2i = globals.vim_plugin.idx_to_pos(code_edit,rmatch.get_start())
				set_caret_pos(pos.y, pos.x)
			return ''
		if stream.begins_with('N'):
			var rmatch: RegExMatch = globals.vim_plugin.search_regex_backwards(
				code_edit,
				command_line.search_pattern,
				get_caret_pos() + Vector2i.LEFT
			)
			if rmatch != null:
				var pos: Vector2i = globals.vim_plugin.idx_to_pos(code_edit,rmatch.get_start())
				set_caret_pos(pos.y, pos.x)
			return ''
		
		if stream.begins_with('c'):
			if mode == Mode.VISUAL:
				code_edit.cut()
				set_mode(Mode.INSERT)
				return ''
			
			if stream.begins_with('cc') and mode == Mode.NORMAL:
				code_edit.begin_complex_operation()
				var l: int = get_line()
				var ind: int = code_edit.get_first_non_whitespace_column(l)
				code_edit.select( l-1, get_line_length(l-1), l, get_line_length(l) )
				code_edit.cut()
				code_edit.insert_line_at(get_line()+1, "\t".repeat(ind))
				code_edit.end_complex_operation()
				move_line(+1)
				set_mode(Mode.INSERT)
				globals.last_command = stream
				return ''
			
			var range: Array = calc_double_motion_region(get_caret_pos(), stream, 1)
			if range.size() == 0:	return ''
			if range.size() == 1:	return stream
			if range.size() == 2:
				code_edit.select(range[0].y, range[0].x, range[1].y, range[1].x + 1)
				code_edit.cut()
				set_mode(Mode.INSERT)
				globals.last_command = stream
			return ''
		if mode == Mode.NORMAL and stream.begins_with('C'):
			code_edit.select( get_line(), code_edit.get_caret_column(), get_line(), get_line_length() )
			code_edit.cut()
			set_mode(Mode.INSERT)
			globals.last_command = stream
			return ''
		if stream.begins_with('z'):
			if stream.begins_with('zz') and mode == Mode.NORMAL:
				code_edit.center_viewport_to_caret()
				return ''
			return stream
		
		if stream.begins_with('>'):
			if is_mode_visual(mode) and stream.length() == 1:
				code_edit.indent_lines()
				return ''
			if stream.length() == 1:	return stream
			if stream.begins_with('>>') and mode == Mode.NORMAL:
				code_edit.indent_lines()
				globals.last_command = stream
				return ''
		if stream.begins_with('<'):
			if is_mode_visual(mode) and stream.length() == 1:
				code_edit.unindent_lines()
				return ''
			if stream.length() == 1:	return stream
			if stream.begins_with('<<') and mode == Mode.NORMAL:
				code_edit.unindent_lines()
				globals.last_command = stream
			return ''
		
		if stream.begins_with('}'):
			var para_edge: Vector2i = get_paragraph_edge_pos( get_line(), 1 )
			set_caret_pos(para_edge.y, para_edge.x)
			return ''
		
		if stream.begins_with('{'):
			var para_edge: Vector2i = get_paragraph_edge_pos( get_line(), -1 )
			set_caret_pos(para_edge.y, para_edge.x)
			return ''
		
		if stream.begins_with('m') and mode == Mode.NORMAL:
			if stream.length() < 2: 	return stream
			if !globals.has('marks'):	globals.marks = {}
			var m: String = stream[1]
			var unicode: int = m.unicode_at(0)
			if (unicode < 65 or unicode > 90) and (unicode < 97 or unicode > 122):
				status_bar.display_error('Marks must be between a-z or A-Z')
				return ''
			globals.marks[m] = {
				'file' : globals.script_editor.get_current_script().resource_path,
				'pos' : Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
			}
			status_bar.display_text('Mark "%s" set' % m, TEXT_DIRECTION_LTR)
			return ''
		if stream.begins_with('`'):
			if stream.length() < 2: 	return stream
			if !globals.has('marks'):	globals.marks = {}
			if !globals.marks.has(stream[1]):
				status_bar.display_error('Mark "%s" not set' % [ stream[1] ])
				return ''
			var mark: Dictionary = globals.marks[stream[1]]
			globals.vim_plugin.edit_script(mark.file, mark.pos)
			return ''
		return ''
	
	
	# Mostly used for commands like "w", "b", and "e"
	# delims is the keywords / characters used as delimiters. Usually, it's the constant KEYWORDS
	func get_word_edge_pos(from_line: int, from_col: int, delims: String, mode: WordEdgeMode) -> Vector2i:
		var search_dir: int = -1 if mode == WordEdgeMode.BEGINNING else 1
		var char_offset: int = 1 if mode == WordEdgeMode.END else -1
		var line: int = from_line
		var col: int = from_col + search_dir
		var text: String = get_line_text(line)
		
		while line >= 0 and line < code_edit.get_line_count():
			while col >= 0 and col < text.length():
				var char: String = text[col]
				if SPACES.contains(char):
					col += search_dir
					continue
				# Please don't question this lmao. It just works, alight?
				var other_char: String = ' ' if col == (text.length()-1) * int(char_offset > 0) else text[col + char_offset]
				
				if SPACES.contains(other_char):
					return Vector2i(col, line)
				if delims.contains(char) != delims.contains(other_char):
					return Vector2i(col, line)
				col += search_dir
			line += search_dir
			text = get_line_text(line)
			col = (text.length() - 1) * int(search_dir < 0 and char_offset < 0)
		return Vector2i(from_col, from_line)
	
	func get_paragraph_edge_pos(from_line: int, search_dir: int):
		var line: int = from_line
		var prev_empty: bool = code_edit.get_line(line) .strip_edges().is_empty()
		line += search_dir
		while line >= 0 and line < code_edit.get_line_count():
			var text: String = code_edit.get_line(line) .strip_edges()
			if text.is_empty() and !prev_empty:
				return Vector2i(text.length(), line)
			prev_empty = text.is_empty()
			line += search_dir
		return Vector2i(0, line)
	
	# motion: command like "f", "t", "F", or "T"
	func find_char_motion(in_line: int, from_col: int, motion: String, char: String) -> int:
		var search_dir: int = 1 if is_lowercase(motion) else -1
		var offset: int = int(motion == 'T') - int(motion == 't') # 1 if T,  -1 if t,  0 otherwise
		var text: String = get_line_text(in_line)
		
		var col: int = -1
		if motion == 'f' or motion == 't':
			col = text.find(char, from_col + search_dir)
		elif motion == 'F' or motion == 'T':
			col = text.rfind(char, from_col + search_dir)
		if col == -1:
			return -1
		return col + offset
	
	# returns: [ Vector2i from_pos, Vector2i to_pos ]
	func calc_double_motion_region(from_pos: Vector2i, stream: String, from_char: int = 0) -> Array[Vector2i]:
		var primary: String = get_stream_char(stream, from_char)
		var secondary: String = get_stream_char(stream, from_char + 1)
		if primary == '':
			return [from_pos] # Incomplete
		
		if primary.to_lower() == 'w':
			var p1: Vector2i = get_word_edge_pos(from_pos.y, from_pos.x, '' if primary == 'W' else KEYWORDS, WordEdgeMode.WORD)
			return [from_pos, p1 + Vector2i.LEFT]
		if primary.to_lower() == 'b':
			var p0: Vector2i = get_word_edge_pos(from_pos.y, from_pos.x, '' if primary == 'B' else KEYWORDS, WordEdgeMode.BEGINNING)
			return [p0, from_pos + Vector2i.LEFT]
		if primary.to_lower() == 'e':
			var p1: Vector2i = get_word_edge_pos(from_pos.y, from_pos.x, '' if primary == 'E' else KEYWORDS, WordEdgeMode.END)
			return [from_pos, p1]
		
		if primary == '$':
			var p1: Vector2i = Vector2i(get_line_length(from_pos.y), from_pos.y)
			return [from_pos, p1]
		if primary == '^':
			var p0: Vector2i = Vector2i(code_edit.get_first_non_whitespace_column(from_pos.y), from_pos.y)
			return [p0, from_pos + Vector2i.LEFT]
		
		if primary != 'i' and primary != 'a':
			return [] # Invalid
		if secondary == '':
			return [from_pos] # Incomplete
		
		if primary == 'i' and secondary.to_lower() == 'w':
			var p0: Vector2i = get_word_edge_pos(from_pos.y, from_pos.x + 1, '' if secondary == 'W' else KEYWORDS, WordEdgeMode.BEGINNING)
			var p1: Vector2i = get_word_edge_pos(from_pos.y, from_pos.x - 1, '' if secondary == 'W' else KEYWORDS, WordEdgeMode.END)
			return [ p0, p1 ]
		
		if primary == 'i' and secondary == 'p':
			var p0: Vector2i = get_paragraph_edge_pos(from_pos.y + 1, -1) + Vector2i.DOWN
			var p1: Vector2i = get_paragraph_edge_pos(from_pos.y - 1, 1)
			return [ p0, p1 ]
		
		return [] # Unknown combination
	
	func toggle_comment(line: int):
		var ind: int = code_edit.get_first_non_whitespace_column(line)
		var text: String = get_line_text(line)
		# Comment line
		if text[ind] != '#':
			code_edit.set_line(line, text.insert(ind, '# '))
			return
		# Uncomment line
		var start_col: int = get_word_edge_pos(line, ind, KEYWORDS, WordEdgeMode.WORD).x
		code_edit.select(line, ind, line, start_col)
		code_edit.delete_selection()
	
	func set_mode(m: int):
		var old_mode: int = mode
		mode = m
		command_line.close()
		match mode:
			Mode.NORMAL:
				code_edit.remove_secondary_carets()
				code_edit.deselect()
				code_edit.release_focus()
				code_edit.deselect()
				self.grab_focus()
				status_bar.set_mode_text(Mode.NORMAL)
				if old_mode == Mode.INSERT:
					move_column(-1)
			Mode.VISUAL:
				if old_mode != Mode.VISUAL_LINE:
					selection_from = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
					selection_to = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
				set_caret_pos(selection_to.y, selection_to.x)
				status_bar.set_mode_text(Mode.VISUAL)
			Mode.VISUAL_LINE:
				if old_mode != Mode.VISUAL:
					selection_from = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
					selection_to = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
				set_caret_pos(selection_to.y, selection_to.x)
				status_bar.set_mode_text(Mode.VISUAL_LINE)
			Mode.COMMAND:
				command_line.show()
				command_line.call_deferred("grab_focus")
				status_bar.set_mode_text(Mode.COMMAND)
			Mode.INSERT:
				code_edit.call_deferred("grab_focus")
				status_bar.set_mode_text(Mode.INSERT)
			_:
				pass
	
	func move_line(offset:int):
		set_line(get_line() + offset)
	
	func get_line() -> int:
		if is_mode_visual(mode):
			return selection_to.y
		return code_edit.get_caret_line()
	
	func get_line_text(line: int = -1) -> String:
		if line == -1:
			return code_edit.get_line(get_line())
		return code_edit.get_line(line)
	
	func get_line_length(line: int = -1) -> int:
		return get_line_text(line).length()
	
	func set_caret_pos(line: int, column: int):
		set_line(line) # line has to be set before column
		set_column(column)
	
	func get_caret_pos() -> Vector2i:
		return Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
	
	func set_line(position:int):
		if !is_mode_visual(mode):
			code_edit.set_caret_line(min(position, code_edit.get_line_count()-1))
			return
		
		selection_to = Vector2i( clampi(selection_to.x, 0, get_line_length(position)), clampi(position, 0, code_edit.get_line_count()) )
		update_visual_selection()
	
	
	func move_column(offset: int):
		set_column(get_column()+offset)
		
	func get_column():
		if is_mode_visual(mode):
			return selection_to.x
		return code_edit.get_caret_column()
	
	func set_column(position: int):
		if !is_mode_visual(mode):
			var line: String = code_edit.get_line(code_edit.get_caret_line())
			code_edit.set_caret_column(min(line.length(), position))
			return
		
		selection_to = Vector2i( clampi(position, 0, get_line_length(selection_to.y)), clampi(selection_to.y, 0, code_edit.get_line_count()) )
		update_visual_selection()
	
	func update_visual_selection():
		if mode == Mode.VISUAL:
			var to_right: bool = selection_to.x >= selection_from.x or selection_to.y > selection_from.y
			code_edit.select( selection_from.y, selection_from.x + int(!to_right), selection_to.y, selection_to.x + int(to_right) )
		elif mode == Mode.VISUAL_LINE:
			var f: int = mini(selection_from.y, selection_to.y) - 1
			var t: int = maxi(selection_from.y, selection_to.y)
			code_edit.select(f, get_line_length(f), t, get_line_length(t))
	
	func is_mode_visual(m: int) -> bool:
		return m == Mode.VISUAL or m == Mode.VISUAL_LINE
	
	func is_lowercase(text: String) -> bool:
		return text == text.to_lower()
	
	func is_uppercase(text: String) -> bool:
		return text == text.to_upper()
	
	func get_stream_char(stream: String, idx: int) -> String:
		return stream[idx] if stream.length() > idx else ''
	
	func draw_cursor():
		if code_edit.is_dragging_cursor():
			selection_from = Vector2i(code_edit.get_selection_from_column(), code_edit.get_selection_from_line())
			selection_to = Vector2i(code_edit.get_selection_to_column(), code_edit.get_selection_to_line())
		
		if code_edit.get_selected_text(0).length() > 1 and !is_mode_visual(mode):
			code_edit.release_focus()
			self.grab_focus()
			set_mode(Mode.VISUAL)
		
		if mode == Mode.INSERT:
			if code_edit.has_selection(0):
				code_edit.deselect(0)
			return
		
		if mode != Mode.NORMAL:
			return
		
		var line: int = code_edit.get_caret_line()
		var column: int = code_edit.get_caret_column()
		if column >= code_edit.get_line(line).length():
			column -= 1
			code_edit.set_caret_column(column)
		
		code_edit.select(line, column, line, column+1)



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

