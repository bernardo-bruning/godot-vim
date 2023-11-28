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
		
	# ACTIONS
	{ "keys": ["i"], "type": Action, "action": { "type": "insert" } },
	{ "keys": ["a"], "type": Action, "action": { "type": "insert", "offset": "after" } },
	{ "keys": ["I"], "type": Action, "action": { "type": "insert", "offset": "bol" } },
	{ "keys": ["A"], "type": Action, "action": { "type": "insert", "offset": "eol" } },
	{ "keys": ["o"], "type": Action, "action": { "type": "insert", "offset": "new_line_below" } },
	{ "keys": ["O"], "type": Action, "action": { "type": "insert", "offset": "new_line_above" } },
	{ "keys": ["v"], "type": Action, "action": { "type": "visual" } },
	{ "keys": ["V"], "type": Action, "action": { "type": "visual_line" } },
	{ "keys": ["u"], "type": Action, "action": { "type": "undo" } },
	{ "keys": ["<C-r>"], "type": Action, "action": { "type": "redo" } },
	{ "keys": [":"], "type": Action, "action": { "type": "command" } },
	{ "keys": ["/"], "type": Action, "action": { "type": "search" } },
	{ "keys": ["J"], "type": Action, "action": { "type": "join" } },
]

# `static var` also doesn't work
const whitelist = [
	"<C-s>"
]


var input_stream: Array[String] = []
var cursor: Control


func _init(cursor_: Control):
	cursor = cursor_


## Returns: Dictionary with the found command: { "type": Motion or Operator or OperatorMotion or Action or Incomplete or NotFound, ... }
## Warning: the returned Dict can be empty in some cases
func register_event(event: InputEventKey, with_context: Mode) -> Dictionary:
	var ch: String = get_event_char(event)
	if ch.is_empty():	return {} # Invalid
	if whitelist.has(ch):	return {}
	
	# print("[KeyMap::register_event()] ch = ", ch) # DEBUG
	input_stream.append(ch)
	var cmd: Dictionary = parse_keys(input_stream, with_context)
	if cmd.is_empty():
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
		
		cmd = cmd.duplicate()
		cmd.modifier = next
	
	call_deferred(&"clear")
	return cmd


## The returned cmd will always have a 'type' key
func find_cmd(keys: Array[String], with_context: Mode) -> Dictionary:
	var partial: bool = false # In case none were found
	
	for cmd in key_map:
		# OperatorMotions in visual mode aren't allowed
		if cmd.type == OperatorMotion and with_context != Mode.NORMAL:
			continue
		
		# Allow Operators to be executed as-is in visual mode
		if !(cmd.type == Operator and with_context != Mode.NORMAL)\
			# Check context
			and (cmd.has("context") and with_context != cmd.context):
			continue
		
		var m: KeyMatch = match_keys(cmd.keys, keys)
		partial = partial or m == KeyMatch.Partial # Set/keep partial = true if it was a partial match
		if m != KeyMatch.Absolute:
			continue
		
		return cmd
	# return { "type": Incomplete if partial else NotFound }
	return { "type": Incomplete*int(partial) + NotFound*int(!partial) }


func execute(cmd: Dictionary):
	if cmd.type == Incomplete or cmd.type == NotFound:
		return
	
	# `if else` is faster than `match` (especially with small sets)
	if cmd.type == Motion:
		# print("[KeyMay::execute()] motion: ", cmd) # DEBUG
		var pos: Vector2i = call_cmd(cmd.motion)
		cursor.set_caret_pos(pos.y, pos.x)
		return
	
	if cmd.type == OperatorMotion:
		if cmd.has('motion'):
			execute_operator_motion(cmd.operator, cmd.motion)
		else:
			call_cmd(cmd.operator)
		return
	
	if cmd.type == Operator:
		# print("[KeyMay::execute()] op: ", cmd) # DEBUG
		if !cmd.has("modifier"): # Execute as-is
			call_cmd(cmd.operator)
		
		# Execute with motion
		elif cmd.modifier.type == Motion:
			execute_operator_motion(cmd.operator, cmd.modifier.motion)
		
		# Execute with `line_wise = true` if repeating operations (e.g. dd, yy)
		elif cmd.modifier.type == Operator and cmd.modifier.operator.type == cmd.operator.type:
			var op_cmd: Dictionary = cmd.operator.duplicate()
			op_cmd.line_wise = true
			call_cmd(op_cmd)
		
		return
	
	if cmd.type == Action:
		call_cmd(cmd.action)
		return
	
	push_error("[KeyMap::execute()] Unknown command type: %s" % cmd.type)


func execute_operator_motion(operator: Dictionary, motion: Dictionary):
	# print("[KeyMay::execute_operator_motion()] op = ", operator, ", motion = ", motion) # DEBUG

	# Execute motion before operation
	var p0: Vector2i = cursor.get_caret_pos()
	var p1: Vector2i = call_cmd(motion)    + Vector2i(int(motion.get('inclusive', false)), 0)
	cursor.code_edit.select(p0.y, p0.x, p1.y, p1.x)
	
	# Add line_wise flag if line wise motion
	var op: Dictionary = operator.duplicate()
	op.line_wise = motion.get('line_wise', false)
	call_cmd(op)


## Unsafe: does not check if the function exists
func call_cmd(cmd: Dictionary) -> Variant:
	var func_name: StringName = StringName("cmd_" + cmd.type)
	return cursor.call(func_name, cmd)


static func get_event_char(event: InputEventKey) -> String:
	if event.keycode == KEY_ENTER:
		return "<CR>"
	if event.keycode == KEY_TAB:
		return "<TAB>"
	if event.is_command_or_control_pressed():
		if !OS.is_keycode_unicode(event.keycode):
			return ''
		var c: String = char(event.keycode)
		return "<C-%s>" % [ c if event.shift_pressed else c.to_lower() ]
	return char(event.unicode)


enum KeyMatch {
	None = 0, # Keys don't match
	Partial = 1, # Keys match partially
	Absolute = 2, # Keys match totally
}

## Check whether keys [param a] is contained in keys [param b]
static func match_keys(a: Array, b: Array) -> KeyMatch:
	var partial: bool = false
	
	for i in mini(a.size(), b.size()):
		if a[i] == b[i]:
			partial = true
			continue
		
		# Partial if there was at least one match, else None
		return KeyMatch.Partial * int(partial)
	
	return KeyMatch.Partial if b.size() < a.size() else KeyMatch.Absolute


func clear():
	input_stream = []


func get_input_stream_as_string() -> String:
	return ''.join(PackedStringArray(input_stream))


