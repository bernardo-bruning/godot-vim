class_name KeyMap extends RefCounted
## Hanldes input stream and key mapping
##
## You may also set your keybindings in the [method map] function

## * SET YOUR KEYBINDINGS HERE *
## Also see the "COMMANDS" section at the bottom of cursor.gd
##  E.g. the command for
##    KeyRemap.new(...) .motion("foo", { "bar": 1 })
##  is handled in Cursor::cmd_foo(args: Dictionary)
##  where `args` is  `{ "type": "foo", "bar": 1 }`
## Example:
## [codeblock]
## return [
## 	# Move 5 characters to the right with "L"
## 	KeyRemap.new([ "L" ])
## 		.motion("move_by_chars", { "move_by": 5 }),
## 	
## 	# Let's remove "d" (the delete operator) and replace it with "q"
## 	# You may additionally specify the type and context of the cmd to remove
##  # using .operator() (or .motion() or .action() etc...) and .with_context()
## 	KeyRemap.new([ "d" ])
##      .remove(),
##  # "q" is now the new delete operator
## 	KeyRemap.new([ "q" ])
## 		.operator("delete"),
## 	
## 	# Delete this line along with the next two with "Z"
## 	# .operator() and .motion() automatically merge together
## 	KeyRemap.new([ "Z" ])
## 		.operator("delete")
## 		.motion("move_by_lines", { "move_by": 2, "line_wise": true }),
## 	
## 	# In Insert mode, return to Normal mode with "jk"
## 	KeyRemap.new([ "j", "k" ])
## 		.action("normal", { "backspaces": 1, "offset": 1 })
## 		.with_context(Mode.INSERT),
## ]
## [/codeblock]
static func map() -> Array[KeyRemap]:
	# Example:
	return [
		# In Insert mode, return to Normal mode with "jk"
		KeyRemap.new([ "j", "i" ])
			.action("normal", { "backspaces": 1, "offset": 0 })
			.with_context(Mode.INSERT),
		
		# Make "/" search in case insensitive mode
		KeyRemap.new([ "/" ])
			.action("command", { "command": "/(?i)" })
			.replace(),
		
		# In Insert mode, return to Normal mode with "Ctrl-["
		# KeyRemap.new([ "<C-[>" ])
			# .action("normal")
			# .with_context(Mode.INSERT),
	]


const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode

const INSERT_MODE_TIMEOUT_MS: int = 700


enum {
	## Moves the cursor. Can be used in tandem with Operator
	Motion,
	
	## Operators (like delete, change, yank) work on selections
	## In Normal mode, they need a Motion or another Operator bound to them (e.g. dj, yy)
	Operator,
	
	## Operator but with a motion already bound to it
	## Can only be executed in Normal mode
	OperatorMotion,
	
	## A single action (e.g. i, o, v, J, u)
	## Cannot be executed in Visual mode unless specified with "context": Mode.VISUAL
	Action,
	
	Incomplete, ## Incomplete command
	NotFound, ## Command not found
}



# Also see the "COMMANDS" section at the bottom of cursor.gd
#  Command for     { "type": "foo", ... }   is handled in Cursor::cmd_foo(args: Dictionary)
#  where `args` is ^^^^^ this Dict ^^^^^^
var key_map: Array[Dictionary] = [
	# MOTIONS
	{ "keys": ["h"], "type": Motion, "motion": { "type": "move_by_chars", "move_by": -1 } },
	{ "keys": ["l"], "type": Motion, "motion": { "type": "move_by_chars", "move_by": 1 } },
	{ "keys": ["j"], "type": Motion, "motion": { "type": "move_by_lines", "move_by": 1, "line_wise": true } },
	{ "keys": ["k"], "type": Motion, "motion": { "type": "move_by_lines", "move_by": -1, "line_wise": true } },
	
	# About motions: the argument `inclusive` is used with Operators (see execute_operator_motion())
	{ "keys": ["w"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": false } },
	{ "keys": ["e"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": true, "inclusive": true } },
	{ "keys": ["b"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": false } },
	{ "keys": ["g", "e"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": true } },
	{ "keys": ["W"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": false, "big_word": true } },
	{ "keys": ["E"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": true, "big_word": true, "inclusive": true } },
	{ "keys": ["B"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": false, "big_word": true } },
	{ "keys": ["g", "E"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": true, "big_word": true } },
	
	{ "keys": ["f", "{char}"], "type": Motion, "motion": { "type": "find_in_line", "forward": true, "inclusive": true } },
	{ "keys": ["t", "{char}"], "type": Motion, "motion": { "type": "find_in_line", "forward": true, "stop_before": true, "inclusive": true } },
	{ "keys": ["F", "{char}"], "type": Motion, "motion": { "type": "find_in_line", "forward": false } },
	{ "keys": ["T", "{char}"], "type": Motion, "motion": { "type": "find_in_line", "forward": false, "stop_before": true } },
	{ "keys": [";"], "type": Motion, "motion": { "type": "find_in_line_again", "invert": false } },
	{ "keys": [","], "type": Motion, "motion": { "type": "find_in_line_again", "invert": true } },
	
	{ "keys": ["0"], "type": Motion, "motion": { "type": "move_to_bol" } },
	{ "keys": ["$"], "type": Motion, "motion": { "type": "move_to_eol" } },
	{ "keys": ["^"], "type": Motion, "motion": { "type": "move_to_first_non_whitespace_char" } },
	{ "keys": ["{"], "type": Motion, "motion": { "type": "move_by_paragraph", "forward": false, "line_wise": true } },
	{ "keys": ["}"], "type": Motion, "motion": { "type": "move_by_paragraph", "forward": true, "line_wise": true } },
	{ "keys": ["[", "["], "type": Motion, "motion": { "type": "move_by_section", "forward": false, "line_wise": true } },
	{ "keys": ["]", "]"], "type": Motion, "motion": { "type": "move_by_section", "forward": true, "line_wise": true } },
	{ "keys": ["g", "g"], "type": Motion, "motion": { "type": "move_to_bof", "line_wise": true } },
	{ "keys": ["G"], "type": Motion, "motion": { "type": "move_to_eof", "line_wise": true } },
	{ "keys": ["g", "m"], "type": Motion, "motion": { "type": "move_to_center_of_line" } },
	{ "keys": ["n"], "type": Motion, "motion": { "type": "find_again", "forward": true } },
	{ "keys": ["N"], "type": Motion, "motion": { "type": "find_again", "forward": false } },
	
	# TEXT OBJECTS
	{ "keys": ["a", "w"], "type": Motion, "motion": { "type": "text_object_word", "inner": false, "inclusive": false } }, # TODO
	{ "keys": ["a", "W"], "type": Motion, "motion": { "type": "text_object_word", "inner": false, "inclusive": false } }, # TODO
	{ "keys": ["i", "w"], "type": Motion, "motion": { "type": "text_object_word", "inner": true, "inclusive": true } },
	{ "keys": ["i", "W"], "type": Motion, "motion": { "type": "text_object_word", "inner": true, "big_word": true, "inclusive": true } },
	{ "keys": ["a", "p"], "type": Motion, "motion": { "type": "text_object_paragraph", "inner": false, "line_wise": true } }, # TODO
	{ "keys": ["i", "p"], "type": Motion, "motion": { "type": "text_object_paragraph", "inner": true, "line_wise": true } },
	
	# OPERATORS
	{ "keys": ["d"], "type": Operator, "operator": { "type": "delete" } },
	{ "keys": ["D"], "type": OperatorMotion,
		"operator": { "type": "delete" },
		"motion": { "type": "move_to_eol" }
	},
	{ "keys": ["x"], "type": OperatorMotion,
		"operator": { "type": "delete" },
		"motion": { "type": "move_by_chars", "move_by": 1 }
	},
	{ "keys": ["x"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "delete" } },
	
	{ "keys": ["y"], "type": Operator, "operator": { "type": "yank" } },
	{ "keys": ["Y"], "type": OperatorMotion,
		"operator": { "type": "yank", "line_wise": true }, # No motion. Same as yy
	},
	
	{ "keys": ["c"], "type": Operator, "operator": { "type": "change" } },
	{ "keys": ["C"], "type": OperatorMotion,
		"operator": { "type": "change" },
		"motion": { "type": "move_to_eol" }
	},
	{ "keys": ["s"], "type": OperatorMotion,
		"operator": { "type": "change" },
		"motion": { "type": "move_by_chars", "move_by": 1 }
	},
	{ "keys": ["s"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "change" } },
	
	{ "keys": ["p"], "type": OperatorMotion,
		"operator": { "type": "paste" },
		"motion": { "type": "move_by_chars", "move_by": 1 }
	},
	{ "keys": ["p"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "paste" } },
	
	{ "keys": [">"], "type": Operator, "operator": { "type": "indent", "forward": true } },
	{ "keys": ["<"], "type": Operator, "operator": { "type": "indent", "forward": false } },
	
	{ "keys": ["g", "c", "c"], "type": OperatorMotion,
		"operator": { "type": "comment" },
		"motion": { "type": "move_by_chars", "move_by": 1 }
	},
	{ "keys": ["g", "c"], "type": Operator, "operator": { "type": "comment" } },
	{ "keys": ["~"], "type": OperatorMotion,
		"operator": { "type": "toggle_uppercase" },
		"motion": { "type": "move_by_chars", "move_by": 1 }
	},
	{ "keys": ["~"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "toggle_uppercase" } },
	{ "keys": ["u"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "set_uppercase", "uppercase": false } },
	{ "keys": ["U"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "set_uppercase", "uppercase": true } },
	{ "keys": ["V"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "visual", "line_wise": true } },
	{ "keys": ["v"], "type": Operator, "context": Mode.VISUAL_LINE, "operator": { "type": "visual", "line_wise": false } },
	
	# ACTIONS
	{ "keys": ["i"], "type": Action, "action": { "type": "insert" } },
	{ "keys": ["a"], "type": Action, "action": { "type": "insert", "offset": "after" } },
	{ "keys": ["I"], "type": Action, "action": { "type": "insert", "offset": "bol" } },
	{ "keys": ["A"], "type": Action, "action": { "type": "insert", "offset": "eol" } },
	{ "keys": ["o"], "type": Action, "action": { "type": "insert", "offset": "new_line_below" } },
	{ "keys": ["O"], "type": Action, "action": { "type": "insert", "offset": "new_line_above" } },
	{ "keys": ["v"], "type": Action, "action": { "type": "visual" } },
	{ "keys": ["V"], "type": Action, "action": { "type": "visual", "line_wise": true } },
	{ "keys": ["u"], "type": Action, "action": { "type": "undo" } },
	{ "keys": ["<C-r>"], "type": Action, "action": { "type": "redo" } },
	{ "keys": ["r", "{char}"], "type": Action, "action": { "type": "replace" } },
	{ "keys": [":"], "type": Action, "action": { "type": "command" } },
	{ "keys": ["/"], "type": Action, "action": { "type": "command", "command": "/" } },
	{ "keys": ["J"], "type": Action, "action": { "type": "join" } },
	{ "keys": ["z", "z"], "type": Action, "action": { "type": "center_caret" } },
	{ "keys": ["m", "{char}"], "type": Action, "action": { "type": "mark" } },
	{ "keys": ["`", "{char}"], "type": Action, "action": { "type": "jump_to_mark" } },
	
	# MISCELLANEOUS
	{ "keys": ["o"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "visual_jump_to_other_end" } },
	{ "keys": ["o"], "type": Operator, "context": Mode.VISUAL_LINE, "operator": { "type": "visual_jump_to_other_end" } },
]

# Keys we won't handle
const BLACKLIST: Array[String] = [
	"<C-s>", # Save
	"<C-b>", # Bookmark
]

enum KeyMatch {
	None = 0, # Keys don't match
	Partial = 1, # Keys match partially
	Full = 2, # Keys match totally
}


var input_stream: Array[String] = []
var cursor: Control
var last_insert_mode_input_ms: int = 0


func _init(cursor_: Control):
	cursor = cursor_
	apply_remaps( KeyMap.map() )


## Returns: Dictionary with the found command: { "type": Motion or Operator or OperatorMotion or Action or Incomplete or NotFound, ... }
## Warning: the returned Dict can be empty in if the event wasn't processed
func register_event(event: InputEventKey, with_context: Mode) -> Dictionary:
	# Stringify event
	var ch: String = event_to_string(event)
	if ch.is_empty():	return {} # Invalid
	if BLACKLIST.has(ch):	return {}
	
	# Handle Insert mode timeout
	if with_context == Mode.INSERT:
		if handle_insert_mode_timeout():
			clear()
			return {}
	
	# Process input stream
	# print("[KeyMap::register_event()] ch = ", ch) # DEBUG
	input_stream.append(ch)
	var cmd: Dictionary = parse_keys(input_stream, with_context)
	if !is_cmd_valid(cmd):
		return { 'type': NotFound }
	
	execute(cmd)
	return cmd


func parse_keys(keys: Array[String], with_context: Mode) -> Dictionary:
	var blacklist: Array = get_blacklist_types_in_context(with_context)
	var cmd: Dictionary = find_cmd(keys, with_context, blacklist)
	if cmd.is_empty() or cmd.type == NotFound:
		call_deferred(&"clear")
		return cmd
	if cmd.type == Incomplete:
		# print(cmd)
		return cmd
	
	# Execute the operation as-is if in VISUAL mode
	# If in NORMAL mode, await further input
	if cmd.type == Operator and with_context == Mode.NORMAL:
		var op_args: Array[String] = keys.slice( cmd.keys.size() ) # Get the rest of keys for motion
		if op_args.is_empty(): # Incomplete; await further input
			return { 'type': Incomplete }
		
		var next: Dictionary = find_cmd(op_args, with_context, [ Action, OperatorMotion ])
		
		if next.is_empty() or next.type == NotFound: # Invalid sequence
			call_deferred(&"clear")
			return { 'type': NotFound }
		elif next.type == Incomplete:
			return { 'type': Incomplete }
		
		cmd.modifier = next
	
	call_deferred(&"clear")
	return cmd

## The returned cmd will always have a 'type' key
# TODO use bitmask instead of Array
func find_cmd(keys: Array[String], with_context: Mode, blacklist: Array = []) -> Dictionary:
	var partial: bool = false # In case none were found
	var is_visual: bool = with_context == Mode.VISUAL or with_context == Mode.VISUAL_LINE
	
	for cmd in key_map:
		# FILTERS
		# Don't allow anything in Insert mode unless specified
		if with_context == Mode.INSERT and cmd.get("context", -1) != Mode.INSERT:
			continue
		
		if blacklist.has(cmd.type):
			continue
		
		# Skip if contexts don't match
		if cmd.has("context") and with_context != cmd.context:
			continue
		
		# CHECK KEYS
		var m: KeyMatch = match_keys(cmd.keys, keys)
		partial = partial or m == KeyMatch.Partial # Set/keep partial = true if it was a partial match
		
		if m != KeyMatch.Full:
			continue
		
		var cmd_mut: Dictionary = cmd.duplicate(true) # 'mut' ('mutable') because key_map is read-only
		# Keep track of selected character, which will later be copied into the fucntion call for the command
		# (See execute() where we check if cmd.has('selected_char'))
		if cmd.keys[-1] == '{char}':
			cmd_mut.selected_char = keys.back()
		return cmd_mut
	
	return { "type": Incomplete if partial else NotFound }


# TODO use bitmask instead of Array
func get_blacklist_types_in_context(context: Mode) -> Array:
	match context:
		Mode.VISUAL, Mode.VISUAL_LINE:
			return [ OperatorMotion, Action ]
		_:
			return []


func execute_operator_motion(cmd: Dictionary):
	if cmd.has('motion'):
		if cmd.has('selected_char'):
			cmd.motion.selected_char = cmd.selected_char
		operator_motion(cmd.operator, cmd.motion)
	else:
		call_cmd(cmd.operator)

func execute_operator(cmd: Dictionary):
	# print("[KeyMay::execute()] op: ", cmd) # DEBUG
	if !cmd.has("modifier"): # Execute as-is
		call_cmd(cmd.operator)
		return
	
	var mod: Dictionary = cmd.modifier
	# Execute with motion
	if mod.type == Motion:
		if mod.has('selected_char'):
			mod.motion.selected_char = mod.selected_char
		operator_motion(cmd.operator, mod.motion)
	
	# Execute with `line_wise = true` if repeating operations (e.g. dd, yy)
	elif mod.type == Operator and mod.operator.type == cmd.operator.type:
		var op_cmd: Dictionary = cmd.operator.duplicate()
		op_cmd.line_wise = true
		call_cmd(op_cmd)

func execute_action(cmd: Dictionary):
	if cmd.has('selected_char'):
		cmd.action.selected_char = cmd.selected_char
	call_cmd(cmd.action)

func execute_motion(cmd: Dictionary):
	if cmd.has('selected_char'):
		cmd.motion.selected_char = cmd.selected_char
	var pos = call_cmd(cmd.motion) # Vector2i for normal motion, or [Vector2i, Vector2i] for text object
	
	if pos is Vector2i:
		cursor.set_caret_pos(pos.y, pos.x)
	elif pos is Array:
		assert(pos.size() == 2)
		# print("[execute_motion() -> text obj] pos = ", pos)
		cursor.select(pos[0].y, pos[0].x, pos[1].y, pos[1].x)

func execute(cmd: Dictionary):
	if !is_cmd_valid(cmd):
		return
	
	match cmd.type:
		Motion:
			execute_motion(cmd)
		OperatorMotion:
			execute_operator_motion(cmd)
		Operator:
			execute_operator(cmd)
		Action:
			execute_action(cmd)
		_ :
			push_error("[KeyMap::execute()] Unknown command type: %s" % cmd.type)


func operator_motion(operator: Dictionary, motion: Dictionary):
	# print("[KeyMay::execute_operator_motion()] op = ", operator, ", motion = ", motion) # DEBUG

	# Execute motion before operation
	var p = call_cmd(motion) # Vector2i for normal motion, or [Vector2i, Vector2i] for text object
	if p is Vector2i:
		var p0: Vector2i = cursor.get_caret_pos()
		if motion.get('inclusive', false):
			p.x += 1
		cursor.code_edit.select(p0.y, p0.x, p.y, p.x)
	elif p is Array:
		assert(p.size() == 2)
		if motion.get('inclusive', false):
			p[1].x += 1
		cursor.code_edit.select(p[0].y, p[0].x, p[1].y, p[1].x)
	
	# Add line_wise flag if line wise motion
	var op: Dictionary = operator.duplicate()
	op.line_wise = motion.get('line_wise', false)
	call_cmd(op)


## Unsafe: does not check if the function exists
func call_cmd(cmd: Dictionary) -> Variant:
	var func_name: StringName = StringName("cmd_" + cmd.type)
	return cursor.call(func_name, cmd)


static func is_cmd_valid(cmd: Dictionary):
	return !cmd.is_empty() and cmd.type != Incomplete and cmd.type != NotFound

static func event_to_string(event: InputEventKey) -> String:
	# Special chars
	if event.keycode == KEY_ENTER:
		return "<CR>"
	if event.keycode == KEY_TAB:
		return "<TAB>"
	if event.keycode == KEY_ESCAPE:
		return "<ESC>"
	
	# Ctrl + key
	if event.is_command_or_control_pressed():
		if !OS.is_keycode_unicode(event.keycode):
			return ''
		var c: String = char(event.keycode)
		return "<C-%s>" % [ c if event.shift_pressed else c.to_lower() ]
	
	# You're not special.
	return char(event.unicode)


# Matches single command keys
static func match_keys(expected_keys: Array, input_keys: Array) -> KeyMatch:
	if expected_keys[-1] == "{char}":
		# If everything + {char} matches
		if input_keys.slice(0, -1) == expected_keys.slice(0, -1) and input_keys.size() == expected_keys.size():
			return KeyMatch.Full
		
		# If everything up until {char} matches
		elif expected_keys.slice(0, input_keys.size()) == input_keys:
			return KeyMatch.Partial
	
	else:
		# Check for full match
		if input_keys == expected_keys:
			return KeyMatch.Full
		# Check for incomplete command (e.g. "ge", "gcc")
		elif expected_keys.slice(0, input_keys.size()) == input_keys:
			return KeyMatch.Partial
		# Cases with operators like "dj", "ce"
		elif input_keys.slice(0, expected_keys.size()) == expected_keys and input_keys.size() > expected_keys.size():
			return KeyMatch.Full
	
	return KeyMatch.None

## Clears the input stream
func clear():
	input_stream = []

func get_input_stream_as_string() -> String:
	return ''.join(PackedStringArray(input_stream))

## Returns whether the Insert mode input has timed out, in which case we
## don't want to process it
func handle_insert_mode_timeout() -> bool:
	var current_tick_ms: int = Time.get_ticks_msec()
	
	if input_stream.is_empty():
		last_insert_mode_input_ms = current_tick_ms
		return false
	
	if current_tick_ms - last_insert_mode_input_ms > INSERT_MODE_TIMEOUT_MS:
		last_insert_mode_input_ms = current_tick_ms
		return true
	last_insert_mode_input_ms = current_tick_ms
	return false


func apply_remaps(map: Array[KeyRemap]):
	if map.is_empty():
		return
	print('[Godot VIM] Applying keybind remaps...')
	for remap in map:
		remap.apply(key_map)


