class_name KeyMap extends RefCounted
## Hanldes input stream and key mapping

const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode


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



# `static var` doesn't work
# Also see the "COMMANDS" section at the bottom of cursor.gd
#  Command for     { "type": "foo", ... }   is handled in Cursor::cmd_foo(args: Dictionary)
#  where `args` is ^^^^^ this Dict ^^^^^^
const key_map: Array[Dictionary] = [
	# MOTIONS
	{ "keys": ["h"], "type": Motion, "motion": { "type": "move_by_chars", "move_by": -1 } },
	{ "keys": ["l"], "type": Motion, "motion": { "type": "move_by_chars", "move_by": 1 } },
	{ "keys": ["j"], "type": Motion, "motion": { "type": "move_by_lines", "move_by": 1, "line_wise": true } },
	{ "keys": ["k"], "type": Motion, "motion": { "type": "move_by_lines", "move_by": -1, "line_wise": true } },
	
	{ "keys": ["w"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": false } },
	{ "keys": ["e"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": true, "inclusive": true } }, # `inclusive` is used with Operators (see execute_operator_motion())
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
	{ "keys": ["g", "g"], "type": Motion, "motion": { "type": "move_to_bof" } },
	{ "keys": ["G"], "type": Motion, "motion": { "type": "move_to_eof" } },
	{ "keys": ["n"], "type": Motion, "motion": { "type": "find_again", "forward": true } },
	{ "keys": ["N"], "type": Motion, "motion": { "type": "find_again", "forward": false } },
	
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
	{ "keys": ["g", "c"], "type": Operator, "operator": { "type": "comment" } },
	
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
	{ "keys": ["/"], "type": Action, "action": { "type": "search" } },
	{ "keys": ["J"], "type": Action, "action": { "type": "join" } },
	{ "keys": ["z", "z"], "type": Action, "action": { "type": "center_caret" } },
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


func _init(cursor_: Control):
	cursor = cursor_
	# key_map.make_read_only()


## Returns: Dictionary with the found command: { "type": Motion or Operator or OperatorMotion or Action or Incomplete or NotFound, ... }
## Warning: the returned Dict can be empty in if the event wasn't processed
func register_event(event: InputEventKey, with_context: Mode) -> Dictionary:
	var ch: String = event_to_char(event)
	if ch.is_empty():	return {} # Invalid
	if BLACKLIST.has(ch):	return {}
	
	# print("[KeyMap::register_event()] ch = ", ch) # DEBUG
	input_stream.append(ch)
	var cmd: Dictionary = parse_keys(input_stream, with_context)
	if cmd.is_empty() or cmd.type in [Incomplete, NotFound]:
		return { 'type': NotFound }
	
	execute(cmd)
	return cmd


func parse_keys(keys: Array[String], with_context: Mode) -> Dictionary:
	var cmd: Dictionary = find_cmd(keys, with_context)
	if cmd.is_empty() or cmd.type == NotFound:
		call_deferred(&"clear")
		return cmd
	if cmd.type == Incomplete:
		return cmd
	
	# Execute the operation as-is if in VISUAL mode
	# If in NORMAL mode, await further input
	if cmd.type == Operator and with_context == Mode.NORMAL:
		var op_args: Array[String] = keys.slice( cmd.keys.size() ) # Get the rest of keys for motion
		if op_args.is_empty(): # Incomplete; await further input
			return { 'type': Incomplete }
		
		var next: Dictionary = find_cmd(op_args, with_context)
		if next.is_empty() or next.type == NotFound: # Invalid sequence
			call_deferred(&"clear")
			return { 'type': NotFound }
		elif next.type == Incomplete:
			return { 'type': Incomplete }
		
		cmd.modifier = next
	
	call_deferred(&"clear")
	return cmd


## The returned cmd will always have a 'type' key
func find_cmd(keys: Array[String], with_context: Mode) -> Dictionary:
	var partial: bool = false # In case none were found
	var is_visual: bool = with_context == Mode.VISUAL or with_context == Mode.VISUAL_LINE
	
	for cmd in key_map:
		# OperatorMotions in visual mode aren't allowed
		if cmd.type == OperatorMotion and is_visual:
			continue
		
		# Don't allow Actions in Visual mode unless specified
		if cmd.type == Action and is_visual\
			and !(cmd.has("context") and cursor.is_mode_visual(cmd.context)):
			continue
		
		# Allow Operators to be executed as-is in visual mode
		if !(cmd.type == Operator and is_visual):
			# Check context for other commands
			if cmd.has("context") and with_context != cmd.context:
				continue
		
		# Check keys
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
	# return { "type": Incomplete if partial else NotFound }
	return { "type": Incomplete*int(partial) + NotFound*int(!partial) }

func check(cmd: Dictionary):
	return cmd.type == Incomplete or cmd.type == NotFound

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
	var pos: Vector2i = call_cmd(cmd.motion)
	cursor.set_caret_pos(pos.y, pos.x)

func execute(cmd: Dictionary):
	if check(cmd):
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
	var p0: Vector2i = cursor.get_caret_pos()
	var p1: Vector2i = call_cmd(motion)
	if motion.get('inclusive', false):
		p1.x += 1
	cursor.code_edit.select(p0.y, p0.x, p1.y, p1.x)
	
	# Add line_wise flag if line wise motion
	var op: Dictionary = operator.duplicate()
	op.line_wise = motion.get('line_wise', false)
	call_cmd(op)


## Unsafe: does not check if the function exists
func call_cmd(cmd: Dictionary) -> Variant:
	var func_name: StringName = StringName("cmd_" + cmd.type)
	return cursor.call(func_name, cmd)


static func event_to_char(event: InputEventKey) -> String:
	# Special chars
	if event.keycode == KEY_ENTER:
		return "<CR>"
	if event.keycode == KEY_TAB:
		return "<TAB>"
	
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
		elif expected_keys.slice(0, input_keys.size()-1) == input_keys.slice(0, -1):
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

func clear():
	input_stream = []


func get_input_stream_as_string() -> String:
	return ''.join(PackedStringArray(input_stream))


