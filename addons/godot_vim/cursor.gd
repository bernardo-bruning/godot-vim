extends Control

const CommandLine = preload("res://addons/godot_vim/command_line.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode
const WordEdgeMode = Constants.WordEdgeMode
const KEYWORDS = Constants.KEYWORDS
const SPACES = Constants.SPACES

var code_edit: CodeEdit
var command_line: CommandLine
var status_bar: StatusBar
var key_map: KeyMap

var mode: Mode = Mode.NORMAL
var selection_from: Vector2i = Vector2i() # For visual modes
var selection_to: Vector2i = Vector2i() # For visual modes
var globals: Dictionary = {}

func _init():
	set_focus_mode(FOCUS_ALL)

func _ready():
	key_map = KeyMap.new(self)
	
	code_edit.connect("focus_entered", focus_entered)
	code_edit.connect("caret_changed", cursor_changed)
	call_deferred('set_mode', Mode.NORMAL)

func _exit_tree():
	key_map = null

func cursor_changed():
	draw_cursor()

func focus_entered():
	if mode == Mode.NORMAL:
		code_edit.release_focus()
		self.grab_focus()


func reset_normal():
	code_edit.cancel_code_completion()
	key_map.clear()
	set_mode(Mode.NORMAL)
	selection_from = Vector2i.ZERO
	selection_to = Vector2i.ZERO
	set_column(code_edit.get_caret_column())
	return


## Returns whether to return to Normal mode
func back_to_normal_mode(event: InputEvent, m: Mode) -> bool:
	# Esc
	if Input.is_key_pressed(KEY_ESCAPE):
		reset_normal()
		return true
	
	# jk
	if m == Mode.INSERT:
		var old_time: int = Time.get_ticks_msec()
		if !Input.is_key_label_pressed(KEY_J):
			return false
		
		if !Time.get_ticks_msec() - old_time < 700 or !Input.is_key_label_pressed(KEY_K):
			return false
		
		code_edit.backspace()
		code_edit.cancel_code_completion()
		reset_normal()
		move_column(+1)
		return true
	return false


func _input(event):
	if back_to_normal_mode(event, mode):
		code_edit.cancel_code_completion()
		return
	
	draw_cursor()
	if !has_focus():	return
	if !event is InputEventKey:	return
	if !event.pressed:	return
	if mode == Mode.INSERT or mode == Mode.COMMAND:	return

	if event.keycode == KEY_ESCAPE:
		key_map.clear()
		return
	
	# See KeyMap.key_map, KeyMap.register_event()
	var cmd: Dictionary = key_map.register_event(event, mode)
	status_bar.display_text(key_map.get_input_stream_as_string())


## TODO Old commands we are yet to move (delete as they get implemented)
# func handle_input_stream(stream: String) -> String:
# 	if stream == '.':
# 		if globals.has('last_command'):
# 			handle_input_stream(globals.last_command)
# 			call_deferred(&'set_mode', Mode.NORMAL)
# 		return ''
# 	
# 	
# 	if stream.begins_with('m') and mode == Mode.NORMAL:
# 		if stream.length() < 2: 	return stream
# 		if !globals.has('marks'):	globals.marks = {}
# 		var m: String = stream[1]
# 		var unicode: int = m.unicode_at(0)
# 		if (unicode < 65 or unicode > 90) and (unicode < 97 or unicode > 122):
# 			status_bar.display_error('Marks must be between a-z or A-Z')
# 			return ''
# 		globals.marks[m] = {
# 			'file' : globals.script_editor.get_current_script().resource_path,
# 			'pos' : Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
# 		}
# 		status_bar.display_text('Mark "%s" set' % m, TEXT_DIRECTION_LTR)
# 		return ''
# 	if stream.begins_with('`'):
# 		if stream.length() < 2: 	return stream
# 		if !globals.has('marks'):	globals.marks = {}
# 		if !globals.marks.has(stream[1]):
# 			status_bar.display_error('Mark "%s" not set' % [ stream[1] ])
# 			return ''
# 		var mark: Dictionary = globals.marks[stream[1]]
# 		globals.vim_plugin.edit_script(mark.file, mark.pos)
# 		return ''
# 	return ''

# Mostly used for commands like "w", "b", and "e"
# Bitmask bits:
#  0 = char is normal char, 1 = char is keyword, 2 = chcar is space
# TODO bug where it doesn't stop at line start: func get_char_wrapping()
func get_word_edge_pos(from_line: int, from_col: int, forward: bool, word_end: bool, big_word: bool) -> Vector2i:
	var search_dir: int = int(forward) - int(!forward) # 1 if forward else -1
	var line: int = from_line
	# Nudge it by (going backwards) + (word end ("e") or beginning ("b"))
	var col: int = from_col + search_dir * (int(!forward) + int(word_end == forward))
	# Cancel 1st bit (keywords) if big word so that keywords and normal chars are treated the same
	var big_word_mask: int = 0b10 if big_word else 0b11
	
	var text: String = get_line_text(line)
	while line >= 0 and line < code_edit.get_line_count():
		while col >= 0 and col < text.length():
			var char: String = text[col]
			var right: String = ' ' if col == text.length()-1 else text[col + 1] # ' ' if eol else the char to the right
			
			var a: int = (int(KEYWORDS.contains(char)) | (int(SPACES.contains(char)) << 1)) & big_word_mask
			var b: int = (int(KEYWORDS.contains(right)) | (int(SPACES.contains(right)) << 1)) & big_word_mask
			
			# Same as:	if a != b and (a if word_end else b) != 2	but without branching
			if a != b and a*int(word_end) + b*int(!word_end) != 2:
				return Vector2i(col + int(!word_end), line)
			
			col += search_dir
		line += search_dir
		text = get_line_text(line)
		col = (text.length() - 1) * int(search_dir < 0)
	
	return Vector2i(from_col, from_line)


# Get the 'edge' or a paragraph (like with { or } motions)
func get_paragraph_edge_pos(from_line: int, forward: bool):
	var search_dir: int = int(forward) - int(!forward)
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


func find_char_in_line(line: int, from_col: int, forward: bool, stop_before: bool, char: String) -> int:
	var text: String = get_line_text(line)
	
	# Search char
	var col: int = text.find(char, from_col + 1)  if forward else  text.rfind(char, from_col - 1)
	if col == -1: # Not found
		return -1
	
	# col + offset
	# where offset = ( int(!forward) - int(forward) ) * int(stop_before)
	# 	= 1 if forward, -1 if !forward, 0 otherwise
	return col + (int(!forward) - int(forward)) * int(stop_before)


func set_line_commented(line: int, is_commented: bool):
	var ind: int = code_edit.get_first_non_whitespace_column(line)
	var text: String = get_line_text(line)
	
	if is_commented:
		code_edit.set_line(line, text.insert(ind, '# '))
		return
	# We use get_word_edge_pos() in case there's multiple '#'s
	var start_col: int = get_word_edge_pos(line, ind, true, false, true).x
	code_edit.select(line, ind, line, start_col)
	code_edit.delete_selection()

func is_line_commented(line: int) -> bool:
	var ind: int = code_edit.get_first_non_whitespace_column(line)
	var text: String = get_line_text(line)
	return text[ind] == '#'


func set_mode(m: int):
	var old_mode: int = mode
	mode = m
	command_line.close()
	match mode:
		Mode.NORMAL:
			code_edit.remove_secondary_carets() # Secondary carets are used when searching with '/' (See command_line.gd)
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
			push_error("[vim::cursor::set_mode()] Unknown mode %s" % mode)

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



# ------------------------------------------------------------------------------
# * COMMANDS *
# ------------------------------------------------------------------------------

# MOTIONS ----------------------------------------------------------------------
# Motion commands must return a Vector2i with the cursor's new position

func cmd_move_by_chars(args: Dictionary) -> Vector2i:
	return Vector2i(get_column() + args.get("move_by", 0), get_line())

func cmd_move_by_lines(args: Dictionary) -> Vector2i:
	return Vector2i(get_column(), get_line() + args.get("move_by", 0))

func cmd_move_by_word(args: Dictionary) -> Vector2i:
	return get_word_edge_pos(
		get_line(),
		get_column(),
		args.get("forward", true),
		args.get("word_end", false),
		args.get("big_word", false)
	)

func cmd_move_by_paragraph(args: Dictionary) -> Vector2i:
	var para_edge: Vector2i = get_paragraph_edge_pos(get_line(), args.get('forward', false))
	return para_edge

func cmd_move_to_bol(args: Dictionary) -> Vector2i:
	return Vector2i(0, get_line())

func cmd_move_to_eol(args: Dictionary) -> Vector2i:
	return Vector2i(get_line_length(), get_line())

func cmd_move_to_first_non_whitespace_char(args: Dictionary) -> Vector2i:
	return Vector2i(code_edit.get_first_non_whitespace_column(get_line()), get_line())

func cmd_move_to_bof(args: Dictionary) -> Vector2i:
	return Vector2i(0, 0)

func cmd_move_to_eof(args: Dictionary) -> Vector2i:
	return Vector2i(0, code_edit.get_line_count())

func cmd_find_again(args: Dictionary) -> Vector2i:
	if command_line.search_pattern.is_empty():
		return get_caret_pos()
	
	var rmatch: RegExMatch
	if args.get('forward', false):
		rmatch = globals.vim_plugin.search_regex(
			code_edit,
			command_line.search_pattern,
			get_caret_pos() + Vector2i.RIGHT
		)
	else:
		rmatch = globals.vim_plugin.search_regex_backwards(
			code_edit,
			command_line.search_pattern,
			get_caret_pos() + Vector2i.LEFT
		)
	
	if rmatch == null:
		return get_caret_pos()
	return globals.vim_plugin.idx_to_pos(code_edit, rmatch.get_start())

func cmd_find_in_line(args: Dictionary) -> Vector2i:
	var line: int = get_line()
	var col: int = find_char_in_line(
		line,
		get_column(),
		args.get('forward', false),
		args.get('stop_before', false),
		args.get('selected_char', '')
		)
	
	globals.last_search = args
	
	if col >= 0:
		return Vector2i(col, line)
	return Vector2i(get_column(), line)

# 'mut' ('mutable') because 'args' will be changed
func cmd_find_in_line_again(args_mut: Dictionary) -> Vector2i:
	if !globals.has('last_search'):	return get_caret_pos()
	
	var last_search: Dictionary = globals.last_search
	var line: int = get_line()
	var col: int = find_char_in_line(
		line,
		get_column(),
		last_search.get('forward', false) != args_mut.get('invert', false), # Invert 'forward' if necessary (xor)
		last_search.get('stop_before', false),
		last_search.get('selected_char', '')
		)
	
	args_mut.inclusive = globals.last_search.get('inclusive', false)
	if col >= 0:
		return Vector2i(col, line)
	return Vector2i(get_column(), line)


# ACTIONS ----------------------------------------------------------------------

func cmd_insert(args: Dictionary):
	set_mode(Mode.INSERT)
	var offset: String = args.get("offset", "in_place")
	
	if offset == "after":
		move_column(1)
	elif offset == "bol":
		set_column( code_edit.get_first_non_whitespace_column(get_line()) )
	elif offset == "eol":
		set_column( get_line_length() )
	elif offset == "new_line_below":
		var line: int = code_edit.get_caret_line()
		var ind: int = code_edit.get_first_non_whitespace_column(line) + int(code_edit.get_line(line).ends_with(':'))
		code_edit.insert_line_at(line + int(line < code_edit.get_line_count() - 1), "\t".repeat(ind))
		move_line(+1)
		set_column(ind)
		set_mode(Mode.INSERT)
	elif offset == "new_line_above":
		var ind: int = code_edit.get_first_non_whitespace_column(code_edit.get_caret_line())
		code_edit.insert_line_at(code_edit.get_caret_line(), "\t".repeat(ind))
		move_line(-1)
		set_column(ind)
		set_mode(Mode.INSERT)

func cmd_visual(args: Dictionary):
	if args.get('line_wise', false):
		set_mode(Mode.VISUAL_LINE)
	else:
		set_mode(Mode.VISUAL)

func cmd_undo(_args: Dictionary):
	code_edit.undo()
	set_mode(Mode.NORMAL)

func cmd_redo(_args: Dictionary):
	code_edit.redo()
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

func cmd_command(_args: Dictionary):
	set_mode(Mode.COMMAND)
	command_line.set_command(':')

func cmd_search(_args: Dictionary):
	set_mode(Mode.COMMAND)
	command_line.set_command('/')

func cmd_join(_args: Dictionary):
	var line: int = code_edit.get_caret_line()
	code_edit.begin_complex_operation()
	code_edit.select(line, get_line_length(), line + 1, code_edit.get_first_non_whitespace_column(line + 1) )
	code_edit.delete_selection()
	code_edit.deselect()
	code_edit.insert_text_at_caret(' ')
	code_edit.end_complex_operation()

func cmd_center_caret(_args: Dictionary):
	code_edit.center_viewport_to_caret()

func cmd_replace(args: Dictionary):
	var char: String = args.get('selected_char', '')
	if char.begins_with('<CR>'):
		char = '\n'
	elif char.begins_with('<TAB>'):
		char = '\t'
	
	code_edit.begin_complex_operation()
	code_edit.delete_selection()
	code_edit.insert_text_at_caret(char)
	move_column(-1)
	code_edit.end_complex_operation()


# OPERATIONS ----------------------------------------------------------------------

func cmd_delete(args: Dictionary):
	if args.get('line_wise', false):
		var l0: int = code_edit.get_selection_from_line()
		var l1: int = code_edit.get_selection_to_line()
		code_edit.select( l0 - 1, get_line_length(l0 - 1), l1, get_line_length(l1) )
		call_deferred(&"move_line", +1)
	
	code_edit.cut()
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

func cmd_yank(args: Dictionary):
	if args.get('line_wise', false):
		var l0: int = code_edit.get_selection_from_line()
		var l1: int = code_edit.get_selection_to_line()
		code_edit.select( l0 - 1, get_line_length(l0 - 1), l1, get_line_length(l1) )
	
	code_edit.copy()
	code_edit.deselect()
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

func cmd_change(args: Dictionary):
	if args.get('line_wise', false):
		var l0: int = code_edit.get_selection_from_line()
		var l1: int = code_edit.get_selection_to_line()
		
		code_edit.select( l0, code_edit.get_first_non_whitespace_column(l0), l1, get_line_length(l1) )
	
	code_edit.cut()
	set_mode(Mode.INSERT)

func cmd_paste(_args: Dictionary):
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

func cmd_indent(args: Dictionary):
	if args.get('forward', false):
		code_edit.indent_lines()
	else:
		code_edit.unindent_lines()
	set_mode(Mode.NORMAL)

func cmd_comment(_args: Dictionary):
	var l0: int = code_edit.get_selection_from_line()
	var l1: int = code_edit.get_selection_to_line()
	var do_comment: bool = !is_line_commented( mini(l0, l1) )
	
	code_edit.begin_complex_operation()
	for line in range( mini(l0, l1), maxi(l0, l1) + 1 ):
		set_line_commented(line, do_comment)
	code_edit.end_complex_operation()
	
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

