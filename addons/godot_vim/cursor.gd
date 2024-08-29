extends Control

const CommandLine = preload("res://addons/godot_vim/command_line.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode
const KEYWORDS = Constants.KEYWORDS
const SPACES = Constants.SPACES
const LANGUAGE = Constants.Language

var code_edit: CodeEdit
var language: LANGUAGE = LANGUAGE.GDSCRIPT
var command_line: CommandLine
var status_bar: StatusBar
var key_map: KeyMap

var mode: Mode = Mode.NORMAL
# For visual modes:
# `selection_from` is the origin point of the selection
# code_edit's caret pos is the end point of the selection (the one the user can move)
var selection_from: Vector2i = Vector2i()

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


func reset_normal():
	set_mode(Mode.NORMAL)
	selection_from = Vector2i.ZERO
	set_column(code_edit.get_caret_column())


func _input(event: InputEvent):
	if Input.is_key_pressed(KEY_ESCAPE):
		reset_normal()
		status_bar.clear()
		return
	
	draw_cursor()
	if !has_focus() and mode != Mode.INSERT:	return
	if !event is InputEventKey:	return
	if !event.pressed:	return
	if mode == Mode.COMMAND:
		return
	
	# See KeyMap.key_map, KeyMap.register_event()
	var registered_cmd: Dictionary = key_map.register_event(event, mode)
	
	# Display keys in status bar
	if mode == Mode.NORMAL or is_mode_visual(mode):
		status_bar.set_keys_text(key_map.get_input_stream_as_string())
	else:
		status_bar.clear_keys()
	
	if KeyMap.is_cmd_valid(registered_cmd):
		code_edit.cancel_code_completion()
		get_viewport().set_input_as_handled()




# Mostly used for commands like "w", "b", and "e"
func get_word_edge_pos(from_line: int, from_col: int, forward: bool, word_end: bool, big_word: bool) -> Vector2i:
	var search_dir: int = int(forward) - int(!forward) # 1 if forward else -1
	var line: int = from_line
	# Think of `col` as the place in between the two chars we're testing
	var col: int = from_col + search_dir\
		+ int(word_end) # Also nudge it once if checking word ends ("e" or "ge")
	# Char groups:  0 = char is normal char, 1 = char is keyword, 2 = char is space
	# Cancel 1st bit (keywords) if big word so that keywords and normal chars are treated the same
	var big_word_mask: int = 0b10 if big_word else 0b11
	
	var text: String = get_line_text(line)
	while line >= 0 and line < code_edit.get_line_count():
		while col >= 0 and col <= text.length():
			# Get "group" of chars to the left and right of `col`
			var left_char: String = ' ' if col == 0 else text[col - 1]
			var right_char: String = ' ' if col == text.length() else text[col] # ' ' if eol; else, the char to the right
			var lg: int = (int(KEYWORDS.contains(left_char)) | (int(SPACES.contains(left_char)) << 1)) & big_word_mask
			var rg: int = (int(KEYWORDS.contains(right_char)) | (int(SPACES.contains(right_char)) << 1)) & big_word_mask
			
			# Same as:	if lg != rg and (lg if word_end else rg) != 2	but without branching
			# (is different group) and (spaces don't count in the wrong direction)
			if lg != rg            and lg*int(word_end) + rg*int(!word_end) != 0b10:
				return Vector2i(col - int(word_end), line)
			
			col += search_dir
		line += search_dir
		text = get_line_text(line)
		col = (text.length() - 1) * int(search_dir < 0)
	
	return Vector2i(from_col, from_line)


""" Rough explanation:
forward and end		->	criteria = current_empty and !previous_empty, no offset
!forward and end	->	criteria = !current_empty and previous_empty, +1 offset
forward and !end	->	criteria = !current_empty and previous_empty, -1 offset
!forward and !end	->	criteria = current_empty and !previous_empty, no offset

criteria = (current_empty and !previous_empty)
	if forward == end
	else ( !(current_empty and !previous_empty) - search_dir )
"""
## Get the 'edge' or a paragraph (like with { or } motions)
func get_paragraph_edge_pos(from_line: int, forward: bool, paragraph_end: bool) -> int:
	var search_dir: int = int(forward) - int(!forward) # 1 if forward else -1
	var line: int = from_line
	var prev_empty: bool = code_edit.get_line(line) .strip_edges().is_empty()
	var f_eq_end: bool = forward == paragraph_end
	line += search_dir
	
	while line >= 0 and line < code_edit.get_line_count():
		var current_empty: bool = code_edit.get_line(line) .strip_edges().is_empty()
		if f_eq_end:
			if current_empty and !prev_empty:
				return line
		elif !current_empty and prev_empty:
			return line - search_dir
		
		prev_empty = current_empty
		line += search_dir
	return line


# Get the 'edge' or a section (like with [[ or ]] motions)
# See is_line_section()
func get_section_edge_pos(from_line: int, forward: bool) -> Vector2i:
	var search_dir: int = int(forward) - int(!forward)
	var line: int = from_line
	var is_prev_section: bool = is_line_section( code_edit.get_line(line) )
	
	line += search_dir
	while line >= 0 and line < code_edit.get_line_count():
		var text: String = code_edit.get_line(line)
		if is_line_section(text) and !is_prev_section:
			return Vector2i(text.length(), line)
		
		is_prev_section = is_line_section( code_edit.get_line(line) )
		line += search_dir
	return Vector2i(0, line)



## Finds the next -- or previous is `forward = false` -- occurence of `char` in the line `line`,
##  starting from col `from_col`
## Additionally, it can stop before the occurence with `stop_before = true`
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


## Finds the next -- or previous if `forward = false` -- occurence of any character in `chars`
## if `chars` has only one character, it will look for that one
func find_next_occurence_of_chars(
	from_line: int,
	from_col: int,
	chars: String,
	forward: bool,
) -> Vector2i:
	var p: Vector2i = Vector2i(from_col, from_line)
	var line_count: int = code_edit.get_line_count()
	var search_dir: int = int(forward) - int(!forward) # 1 if forward, -1 if backwards
	
	var text: String = get_line_text(p.y)
	while p.y >= 0 and p.y < line_count:
		while p.x >= 0 and p.x < text.length():
			if chars.contains(text[p.x]):
				return p
			p.x += search_dir
		p.y += search_dir
		text = get_line_text(p.y)
		p.x = (text.length() - 1) * int(!forward) # 0 if forwards, EOL if backwards
	# Not found
	# i want optional typing to be in godot so bad
	return Vector2i(-1, -1)


## Finds the next / previous brace specified by `brace` and its closing `counterpart`
## `force_inline` forces to look only in the line `from_line` (See constants.gd::INLINE_BRACKETS)
## E.g.
##  brace = "(", counterpart = ")", forward = false, from_line and from_col = in between the brackets
##  will find the start of the set of parantheses the cursor is inside of
func find_brace(
	from_line: int,
	from_col: int,
	brace: String,
	counterpart: String,
	forward: bool,
	force_inline: bool = false,
) -> Vector2i:
	var line_count: int = code_edit.get_line_count()
	var d: int = int(forward) - int(!forward)
	
	var p: Vector2i = Vector2i(from_col + d, from_line)
	var stack: int = 0
	
	var text: String = get_line_text(p.y)
	while p.y >= 0 and p.y < line_count:
		while p.x >= 0 and p.x < text.length():
			var char: String = text[p.x]
			
			if char == counterpart:
				if stack == 0:
					return p
				stack -= 1
			elif char == brace:
				stack += 1
			p.x += d
		
		if force_inline:
			return Vector2i(-1, -1)
		
		p.y += d
		text = get_line_text(p.y)
		p.x = (text.length() - 1) * int(!forward) # 0 if forwards, EOL if backwards
	
	# i want optional typing to be in godot so bad rn
	return Vector2i(-1, -1)


func get_comment_char() -> String:
	match language:
		LANGUAGE.SHADER:
			return "//"
		LANGUAGE.GDSCRIPT:
			return "#"
		_:
			return "#"

func set_line_commented(line: int, is_commented: bool):
	var text: String = get_line_text(line)
	# Don't comment if empty
	if text.strip_edges().is_empty():
		return
	
	var ind: int = code_edit.get_first_non_whitespace_column(line)
	if is_commented:
		code_edit.set_line(line, text.insert(ind, get_comment_char() + " " ))
		return
	# We use get_word_edge_pos() in case there's multiple '#'s
	var start_col: int = get_word_edge_pos(line, ind, true, false, true).x
	code_edit.select(line, ind, line, start_col)
	code_edit.delete_selection()

func is_line_commented(line: int) -> bool:
	var text: String = get_line_text(line).strip_edges(true, false)
	return text.begins_with( get_comment_char() )


func set_mode(m: int):
	var old_mode: int = mode
	mode = m
	command_line.close()
	
	match mode:
		Mode.NORMAL:
			code_edit.call_deferred("cancel_code_completion")
			key_map.clear()
			
			code_edit.remove_secondary_carets() # Secondary carets are used when searching with '/' (See command_line.gd)
			code_edit.release_focus()
			code_edit.deselect()
			self.grab_focus()
			status_bar.set_mode_text(Mode.NORMAL)
			
			# Insert -> Normal
			if old_mode == Mode.INSERT:
				# code_edit.end_complex_operation() # See Mode.INSERT match arm below
				move_column(-1)
		
		Mode.VISUAL:
			if old_mode != Mode.VISUAL_LINE:
				selection_from = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
			status_bar.set_mode_text(Mode.VISUAL)
			update_visual_selection()
		
		Mode.VISUAL_LINE:
			if old_mode != Mode.VISUAL:
				selection_from = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
			status_bar.set_mode_text(Mode.VISUAL_LINE)
			update_visual_selection()
		
		Mode.COMMAND:
			command_line.show()
			command_line.call_deferred("grab_focus")
			status_bar.set_mode_text(Mode.COMMAND)
		
		Mode.INSERT:
			code_edit.call_deferred("grab_focus")
			status_bar.set_mode_text(Mode.INSERT)
			
			# if old_mode == Mode.NORMAL:
				# Complex operation so that entire insert mode actions can be undone
				# with one undo
				# code_edit.begin_complex_operation()
		
		_:
			push_error("[vim::cursor::set_mode()] Unknown mode %s" % mode)

func move_line(offset:int):
	set_line(get_line() + offset)

func get_line() -> int:
	return code_edit.get_caret_line()

func get_line_text(line: int = -1) -> String:
	if line == -1:
		return code_edit.get_line(get_line())
	return code_edit.get_line(line)

func get_char_at(line: int, col: int) -> String:
	var text: String = code_edit.get_line(line)
	if col > 0 and col < text.length():
		return text[col]
	return ""

func get_line_length(line: int = -1) -> int:
	return get_line_text(line).length()

func set_caret_pos(line: int, column: int):
	set_line(line) # line has to be set before column
	set_column(column)

func get_caret_pos() -> Vector2i:
	return Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())

func set_line(position:int):
	code_edit.set_caret_line(min(position, code_edit.get_line_count()-1))
	
	if is_mode_visual(mode):
		update_visual_selection()


func move_column(offset: int):
	set_column(get_column()+offset)
	
func get_column():
	return code_edit.get_caret_column()

func set_column(position: int):
	code_edit.set_caret_column(min(get_line_length(), position))
	
	if is_mode_visual(mode):
		update_visual_selection()

func select(from_line: int, from_col: int, to_line: int, to_col: int):
	code_edit.select(from_line, from_col, to_line, to_col + 1)
	selection_from = Vector2i(from_col, from_line)
	set_caret_pos(to_line, to_col)
	# status_bar.set_mode_text(Mode.VISUAL)

func update_visual_selection():
	var selection_to: Vector2i = Vector2i(code_edit.get_caret_column(), code_edit.get_caret_line())
	if mode == Mode.VISUAL:
		var backwards: bool = selection_to.x < selection_from.x if selection_to.y == selection_from.y else selection_to.y < selection_from.y
		code_edit.select(selection_from.y, selection_from.x + int(backwards), selection_to.y, selection_to.x + int(!backwards))
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

func is_line_section(text: String) -> bool:
	var t: String = text.strip_edges()
	
	match language:
		LANGUAGE.SHADER:
			return t.ends_with("{") and !SPACES.contains(text.left(1))
		LANGUAGE.GDSCRIPT:
			return t.begins_with("func")\
				or t.begins_with("static func")\
				or t.begins_with("class")\
				or t.begins_with("#region")
		_:
			return false


func get_stream_char(stream: String, idx: int) -> String:
	return stream[idx] if stream.length() > idx else ''

func draw_cursor():
	
	if code_edit.is_dragging_cursor() and code_edit.get_selected_text() != "":
		selection_from = Vector2i(code_edit.get_selection_from_column(), code_edit.get_selection_from_line())
	
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


#region COMMANDS

#region MOTIONS
# Motion commands must return a Vector2i with the cursor's new position

## Moves the cursor horizontally
## Args:
## - "move_by": int
##		How many characters to move by
func cmd_move_by_chars(args: Dictionary) -> Vector2i:
	return Vector2i(get_column() + args.get("move_by", 0), get_line())

## Moves the cursor vertically
## Args:
## - "move_by": int
##		How many lines to move by
func cmd_move_by_lines(args: Dictionary) -> Vector2i:
	return Vector2i(get_column(), get_line() + args.get("move_by", 0))

## Moves the cursor vertically by a certain percentage of the screen / page
## Args:
## - "percentage": float
##		How much to move by
##		E.g. percentage = 0.5 will move down half a screen, 
##		percentage = -1.0 will move up a full screen
func cmd_move_by_screen(args: Dictionary) -> Vector2i:
	var h: int = code_edit.get_visible_line_count()
	var amt: int = int( h * args.get("percentage", 0.0) )
	return Vector2i(get_column(), get_line() + amt)

## Moves the cursor by word
## Args:
## - "forward": bool
##		Whether to move forwards (right) or backwards (left)
## - "word_end": bool
##		Whether to move to the end of a word
## - "big_word": bool
##		Whether to ignore keywords like ";", ",", "." (See KEYWORDS in constants.gd)
func cmd_move_by_word(args: Dictionary) -> Vector2i:
	return get_word_edge_pos(
		get_line(),
		get_column(),
		args.get("forward", true),
		args.get("word_end", false),
		args.get("big_word", false)
	)

## Moves the cursor by paragraph
## Args:
## - "forward": bool
##		Whether to move forward (down) or backward (up)
func cmd_move_by_paragraph(args: Dictionary) -> Vector2i:
	var forward: bool = args.get('forward', false)
	var line: int = get_paragraph_edge_pos(get_line(), forward, forward)
	return Vector2i(0, line)

## Moves the cursor to the start of the line
## This is the VIM equivalent of "0"
func cmd_move_to_bol(_args: Dictionary) -> Vector2i:
	return Vector2i(0, get_line())

## Moves the cursor to the end of the line
## This is the VIM equivalent of "$"
func cmd_move_to_eol(args: Dictionary) -> Vector2i:
	return Vector2i(get_line_length(), get_line())

## Moves the cursor to the first non-whitespace character in the current line
## This is the VIM equivalent of "^"
func cmd_move_to_first_non_whitespace_char(args: Dictionary) -> Vector2i:
	return Vector2i(code_edit.get_first_non_whitespace_column(get_line()), get_line())

## Moves the cursor to the start of the file
## This is the VIM equivalent of "gg"
func cmd_move_to_bof(args: Dictionary) -> Vector2i:
	return Vector2i(0, 0)

## Moves the cursor to the end of the file
## This is the VIM equivalent of "G"
func cmd_move_to_eof(args: Dictionary) -> Vector2i:
	return Vector2i(0, code_edit.get_line_count())

func cmd_move_to_center_of_line(_args: Dictionary) -> Vector2i:
	var l: int = get_line()
	return Vector2i( get_line_length(l) / 2 , l)

## Repeats the last '/' search
## This is the VIM equivalent of "n" and "N"
## Args:
## - "forward": bool
##		Whether to search down (true) or up (false)
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

## Jumps to a character in the current line
## This is the VIM equivalent of f, F, t, ant T
## Args:
## - "selected_char": String
##		The character to look for
## - "forward": bool
##		Whether to search right (true) or left (false)
## - "stop_before": bool
##		Whether to stop before [selected_char]
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

## Repeats the last inline search
## This is the VIM equivalent of ";" and ","
## Args:
## - "invert": bool
##		Whether search in the opposite direction of the last search
func cmd_find_in_line_again(args_mut: Dictionary) -> Vector2i:
	# 'mut' ('mutable') because 'args' will be changed
	# The reason for that is because the arg 'inclusive' is dependant on the last search
	# and will be used with Operators
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


## Moves the cursor by section (VIM equivalent of [[ and ]])
## Sections are defined by the following keywords:
## - "func"
## - "class"
## - "#region"
## See also is_line_section()
##
## Args:
## - "forward": bool
##		Whether to move forward (down) or backward (up)
func cmd_move_by_section(args: Dictionary) -> Vector2i:
	var section_edge: Vector2i = get_section_edge_pos(get_line(), args.get('forward', false))
	return section_edge


## Corresponds to the % motion in VIM
func cmd_jump_to_next_brace_pair(_args: Dictionary) -> Vector2i:
	const PAIRS = Constants.PAIRS
	var p: Vector2i = get_caret_pos()
	
	var p0: Vector2i = find_next_occurence_of_chars(p.y, p.x, Constants.BRACES, true)
	# Not found
	if p0.x < 0 or p0.y < 0:
		return p
	
	var brace: String = code_edit.get_line(p0.y)[p0.x]
	# Whether this brace is an opening or closing brace. i.e. ([{ or }])
	var is_closing_brace: bool = PAIRS.values().has(brace)
	var closing_counterpart: String = ""
	if is_closing_brace:
		var idx: int = PAIRS.values().find(brace)
		if idx != -1:
			closing_counterpart = brace
			brace = PAIRS.keys()[idx]
	else:
		closing_counterpart = PAIRS.get(brace, "")
	if closing_counterpart.is_empty():
		push_error("[GodotVIM] Failed to get counterpart for brace: ", brace)
		return p
	
	var p1: Vector2i = find_brace(p0.y, p0.x, closing_counterpart, brace, false)\
		if is_closing_brace\
		else find_brace(p0.y, p0.x, brace, closing_counterpart, true)
	
	if p1 == Vector2i(-1, -1):
		return p0
	
	return p1


#region TEXT OBJECTS
# Text Object commands must return two Vector2is with the cursor start and end position

## Get the bounds of the text object specified in args
## Args:
## - "object": String
##		The text object to select. Should ideally be a key in constants.gd::PAIRS but doesn't have to
##		If "object" is not in constants.gd::PAIRS, then "counterpart" must be specified
## - "counterpart": String (optional)
##		The end key of the text object
## - "inline": bool (default = false)
##		Forces the search to occur only in the current line
## - "around": bool (default = false)
##		Whether to select around (e.g. ab, aB, a[, a] in VIM)
func cmd_text_object(args: Dictionary) -> Array[Vector2i]:
	var p: Vector2i = get_caret_pos()
	
	# Get start and end keys
	if !args.has("object"):
		push_error("[GodotVim] Error on cmd_text_object: No object selected")
		return [ p, p ]
	
	var obj: String = args.object
	var counterpart: String
	if args.has("counterpart"):
		counterpart = args.counterpart
	elif Constants.PAIRS.has(obj):
		counterpart = Constants.PAIRS[obj]
	else:
		push_error("[GodotVim] Error on cmd_text_object: Invalid brace pair: \"", obj, "\". You can specify an end key with the argument `counterpart: String`")
		return [ p, p ]
	
	var inline: bool = args.get("inline", false)
	
	# Deal with edge case where the cursor is already on the end
	var p0x = p.x - 1 if get_char_at(p.y, p.x) == counterpart else p.x
	# Look backwards to find start
	var p0: Vector2i = find_brace(p.y, p0x, counterpart, obj, false, inline)
	
	# Not found; try to look forward then
	if p0.x == -1:
		if inline:
			var col: int = find_char_in_line(p.y, p0x, true, false, obj)
			p0 = Vector2i(col, p.y)
		else:
			p0 = find_next_occurence_of_chars(p.y, p0x, obj, true)
		
		if p0.x == -1:
			return [ p, p ]
	
	# Look forwards to find end
	var p1: Vector2i = find_brace(p0.y, p0.x, obj, counterpart, true, inline)
	
	if p1 == Vector2i(-1, -1):
		return [ p, p ]
	
	if args.get("around", false):
		return [ p0, p1 ]
	return [ p0 + Vector2i.RIGHT, p1 + Vector2i.LEFT ]


## Corresponds to the  iw, iW, aw, aW  motions in regular VIM
## Args:
## - "around": bool (default = false)
##		Whether to select around words (aw, aW in VIM)
## - "big_word": bool (default = false)
##		Whether this is a big word motion (iW, aW in VIM)
func cmd_text_object_word(args: Dictionary) -> Array[Vector2i]:
	var is_big_word: bool = args.get("big_word", false)
	
	var p: Vector2i = get_caret_pos()
	var p0 = get_word_edge_pos(p.y, p.x + 1, false, false, is_big_word)
	var p1 = get_word_edge_pos(p.y, p.x - 1, true, true, is_big_word)
	
	if !args.get("around", false):
		# Inner word (iw, iW)
		return [ p0, p1 ]
	
	# Around word (aw, aW)
	var text: String = get_line_text(p.y)
	# Whether char to the RIGHT is a space
	var next_char_is_space: bool = SPACES.contains(
		text[ mini(p1.x + 1, text.length() - 1) ]
	)
	if next_char_is_space:
		p1.x = get_word_edge_pos(p1.y, p1.x, true, false, false).x - 1
		return [ p0, p1 ]
	
	# Whether char to the LEFT is a space
	next_char_is_space = SPACES.contains(
		text[ maxi(p0.x - 1, 0) ]
	)
	if next_char_is_space:
		p0.x = get_word_edge_pos(p0.y, p0.x, false, true, false).x + 1
		return [ p0, p1 ]
	
	return [ p0, p1 ]

## Warning: changes the current mode to VISUAL_LINE
## Args:
## - "around": bool (default = false)
##		Whether to select around paragraphs (ap in VIM)
func cmd_text_object_paragraph(args: Dictionary) -> Array[Vector2i]:
	var p: Vector2i = get_caret_pos()
	var p0: Vector2i = Vector2i(0, get_paragraph_edge_pos(p.y, false, false) + 1)
	var p1: Vector2i = Vector2i(0, get_paragraph_edge_pos(p.y, true, true) - 1)
	
	if !args.get("around", false):
		# Inner paragraph (ip)
		set_mode(Mode.VISUAL_LINE)
		return [ p0, p1 ]
	
	# Extend downwards
	if p1.y < code_edit.get_line_count() - 1:
		p1.y = get_paragraph_edge_pos(p1.y, true, false)
	# Extend upwards
	elif p0.y > 0:
		p0.y = get_paragraph_edge_pos(p0.y - 1, false, true)
	
	set_mode(Mode.VISUAL_LINE)
	return [ p0, p1 ]




#endregion TEXT OBJECTS



#endregion MOTIONS

#region ACTIONS

## Enters Insert mode
## Args:
## - (optional) "offset": String
##		Either of:
##		"after": Enter insert mode after the selected character (VIM equivalent: a)
##		"bol": Enter insert mode at the beginning of this line (VIM equivalent: I)
##		"eol": Enter insert mode at the end of this line (VIM equivalent: A)
##		"new_line_below": Insert at a new line below (VIM equivalent: o)
##		"new_line_above": Insert at a new line above (VIM equivalent: O)
##	defaults to "in_place": Enter insert mode before the selected character (VIM equivalent: i)
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

## Switches to Normal mode
## Args:
## - (optional) "backspaces" : int
##		Number of times to backspace (e.g. once with 'jk')
## - (optional) "offset" : int
##		How many colums to move the caret
func cmd_normal(args: Dictionary):
	for __ in args.get("backspaces", 0):
		code_edit.backspace()
	reset_normal()
	if args.has("offset"):
		move_column( args.offset )

## Switches to Visual mode
## if "line_wise": bool (optional) is true, it will switch to VisualLine instead
func cmd_visual(args: Dictionary):
	if args.get('line_wise', false):
		set_mode(Mode.VISUAL_LINE)
	else:
		set_mode(Mode.VISUAL)

## Switches the current mode to COMMAND mode
## Args:
## - Empty -> Enter command mode normally
## - { "command" : "[cmd]" } -> Enter command mode with the command "[cmd]" already typed in
func cmd_command(args: Dictionary):
	set_mode(Mode.COMMAND)
	if args.has("command"):
		command_line.set_command(args.command)
	else:
		command_line.set_command(":")

func cmd_undo(_args: Dictionary):
	code_edit.undo()
	set_mode(Mode.NORMAL)

func cmd_redo(_args: Dictionary):
	code_edit.redo()
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

## Join the current line with the next one
func cmd_join(_args: Dictionary):
	var line: int = code_edit.get_caret_line()
	code_edit.begin_complex_operation()
	code_edit.select(line, get_line_length(), line + 1, code_edit.get_first_non_whitespace_column(line + 1) )
	code_edit.delete_selection()
	code_edit.deselect()
	code_edit.insert_text_at_caret(' ')
	code_edit.end_complex_operation()

## Centers the cursor on the screen
func cmd_center_caret(_args: Dictionary):
	code_edit.center_viewport_to_caret()

## Replace the current character with [selected_char]
## Args:
## - "selected_char": String
##		as is processed in KeyMap::event_to_string()
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

## For now, all marks are global
func cmd_mark(args: Dictionary):
	if !args.has("selected_char"):
		push_error("[GodotVIM] Error on cmd_mark(): No char selected")
		return
	
	if !globals.has("marks"):
		globals.marks = {}
	var m: String = args.selected_char
	var unicode: int = m.unicode_at(0)
	if (unicode < 65 or unicode > 90) and (unicode < 97 or unicode > 122):
		# We use call_deferred because otherwise, the error gets overwritten at the end of _input()
		status_bar.call_deferred(&"display_error", "Marks must be between a-z or A-Z")
		return
	globals.marks[m] = {
		"file": globals.script_editor.get_current_script().resource_path,
		"pos": get_caret_pos()
	}
	status_bar.call_deferred(&"display_text", 'Mark "%s" set' % m)

func cmd_jump_to_mark(args: Dictionary):
	if !args.has("selected_char"):
		push_error("[GodotVIM] Error on cmd_jump_to_mark(): No char selected")
		return
	if !globals.has('marks'):
		globals.marks = {}
	
	var m: String = args.selected_char
	if !globals.marks.has(m):
		status_bar.display_error('Mark "%s" not set' % m)
		return
	var mark: Dictionary = globals.marks[m]
	globals.vim_plugin.edit_script(mark.file, mark.pos + Vector2i(0, 1))
	code_edit.call_deferred(&"center_viewport_to_caret")


#endregion ACTIONS

#region OPERATIONS

## Delete a selection
## Corresponds to "d" in regular VIM
func cmd_delete(args: Dictionary):
	if args.get('line_wise', false):
		var l0: int = code_edit.get_selection_from_line()
		var l1: int = code_edit.get_selection_to_line()
		code_edit.select( l0 - 1, get_line_length(l0 - 1), l1, get_line_length(l1) )
		call_deferred(&"move_line", +1)
	
	code_edit.cut()
	
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

## Copies (yanks) a selection
## Corresponds to "y" in regular VIM
func cmd_yank(args: Dictionary):
	if args.get('line_wise', false):
		var l0: int = code_edit.get_selection_from_line()
		var l1: int = code_edit.get_selection_to_line()
		code_edit.select( l0 - 1, get_line_length(l0 - 1), l1, get_line_length(l1) )
	
	code_edit.copy()
	code_edit.deselect()
	if mode != Mode.NORMAL:
		set_mode(Mode.NORMAL)

## Changes a selection
## Corresponds to "c" in regular VIM
func cmd_change(args: Dictionary):
	if args.get('line_wise', false):
		var l0: int = code_edit.get_selection_from_line()
		var l1: int = code_edit.get_selection_to_line()
		
		code_edit.select( l0, code_edit.get_first_non_whitespace_column(l0), l1, get_line_length(l1) )
	
	code_edit.cut()
	set_mode(Mode.INSERT)

func cmd_paste(_args: Dictionary):
	code_edit.begin_complex_operation()
	
	if !is_mode_visual(mode):
		if DisplayServer.clipboard_get().begins_with('\r\n'):
			set_column(get_line_length())
		else:
			move_column(+1)
		code_edit.deselect()
	
	code_edit.paste()
	move_column(-1)
	code_edit.end_complex_operation()
	set_mode(Mode.NORMAL)

## Indents or unindents the selected line(s) by 1 level
## Corresponds to >> or << in regular VIM
## Args:
## - (optional) "forward": whether to indent *in*. Defaults to false
func cmd_indent(args: Dictionary):
	if args.get('forward', false):
		code_edit.indent_lines()
	else:
		code_edit.unindent_lines()
	set_mode(Mode.NORMAL)

## Toggles whether the selected line(s) are commented
func cmd_comment(_args: Dictionary):
	var l0: int = code_edit.get_selection_from_line()
	var l1: int = code_edit.get_selection_to_line()
	var do_comment: bool = !is_line_commented( mini(l0, l1) )
	
	code_edit.begin_complex_operation()
	for line in range( mini(l0, l1), maxi(l0, l1) + 1 ):
		set_line_commented(line, do_comment)
	code_edit.end_complex_operation()
	
	set_mode(Mode.NORMAL)


## Sets the selected text to uppercase or lowercase
## Args:
## - "uppercase": bool (default: false)
## 		Whether to toggle uppercase or lowercase
func cmd_set_uppercase(args: Dictionary):
	var text: String = code_edit.get_selected_text()
	if args.get("uppercase", false):
		code_edit.insert_text_at_caret( text.to_upper() )
	else:
		code_edit.insert_text_at_caret( text.to_lower() )
	
	set_mode(Mode.NORMAL)


## Toggles the case of the selectex text
func cmd_toggle_uppercase(_args: Dictionary):
	var text: String = code_edit.get_selected_text()
	for i in text.length():
		var char: String = text[i]
		if is_uppercase(char):
			text[i] = char.to_lower()
		else:
			text[i] = char.to_upper()
	code_edit.insert_text_at_caret(text)
	
	set_mode(Mode.NORMAL)


#endregion OPERATIONS

## Corresponds to 'o' in Visual mode in regular Vim
func cmd_visual_jump_to_other_end(args: Dictionary):
	if !is_mode_visual(mode):
		push_warning("[GodotVim] Attempting to jump to other end of selection while not in VISUAL mode. Ignoring...")
		return
	
	var p: Vector2i = selection_from
	selection_from = get_caret_pos()
	set_caret_pos(p.y, p.x)
#endregion COMMANDS
