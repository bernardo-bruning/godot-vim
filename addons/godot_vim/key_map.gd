class_name KeyMap extends RefCounted
## Hanldes input stream and key mapping

const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode


enum {
	## Moves the cursor. Can be used in tandem with Operator
	Motion,
	
	## Commands like delete, yank
	## Can be executed as-is in Visual mode (e.g. d, c). In Normal mode, they need a Motion or another
	##  Operator bound to them (e.g. dj, yy)
	Operator,
	
	## Operator but with a motion already bound to it
	## Cannot be executed in Visual mode
	OperatorMotion,
	
	## A single action (e.g. i, o, v, J, u)
	Action,
}

#enum OperatorType {
#	Delete,
#	Change,
#	Yank,
#	Paste,
#}


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
	{ "keys": ["e"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": true } },
	{ "keys": ["b"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": false } },
	{ "keys": ["g", "e"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": true } },
	{ "keys": ["W"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": false, "big_word": true } },
	{ "keys": ["E"], "type": Motion, "motion": { "type": "move_by_word", "forward": true, "word_end": true, "big_word": true } },
	{ "keys": ["B"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": false, "big_word": true } },
	{ "keys": ["g", "E"], "type": Motion, "motion": { "type": "move_by_word", "forward": false, "word_end": true, "big_word": true } },
	{ "keys": ["0"], "type": Motion, "motion": { "type": "move_to_bol" } },
	{ "keys": ["$"], "type": Motion, "motion": { "type": "move_to_eol" } },
	{ "keys": ["^"], "type": Motion, "motion": { "type": "move_to_first_non_whitespace_char" } },
	
	# OPERATORS
	{ "keys": ["x"], "type": OperatorMotion,
		"operator": { "type": "delete" },
		"motion": { "type": "move_by_chars", "move_by": 1 }
	},
	{ "keys": ["d"], "type": Operator, "operator": { "type": "delete" } },
	{ "keys": ["x"], "type": Operator, "context": Mode.VISUAL, "operator": { "type": "delete" } },

	{ "keys": ["D"], "type": OperatorMotion, "context": Mode.NORMAL,
		"operator": { "type": "delete" },
		"motion": { "type": "move_to_eol", "inclusive": true }
	},
	
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


## Returns: Array[Dictionary]
func register_event(event: InputEventKey, with_context: Mode) -> Dictionary:
	var ch: String = get_event_char(event)
	if ch.is_empty():	return {} # Invalid
	if whitelist.has(ch):	return {}
	
	# print("[KeyMap::register_event()] ch = ", ch) # DEBUG
	input_stream.append(ch)
	var cmd: Dictionary = parse_keys(input_stream, with_context)
	if cmd.is_empty():
		return {}
	
	execute(cmd)
	return cmd


func parse_keys(keys: Array[String], with_context: Mode) -> Dictionary:
	var cmd: Dictionary = find_cmd(keys, with_context)
	# print('cmd: ', cmd)
	if cmd.is_empty():
		call_deferred(&"clear")
		return {}
	
	# Execute the operation as-is if in VISUAL mode
	# If in NORMAL mode, await further input
	if cmd.type == Operator and with_context == Mode.NORMAL:
		var op_args: Array[String] = keys.slice( cmd.keys.size() ) # Get the rest of keys
		# print('op_args: ', op_args)
		if op_args.is_empty(): # Incomplete; await further input
			return {}
		
		var next: Dictionary = find_cmd(op_args, with_context)
		if next.is_empty(): # Invalid sequence
			call_deferred(&"clear")
			return {}
		
		cmd = cmd.duplicate()
		cmd.modifier = next
	
	call_deferred(&"clear")
	return cmd


# TODO clean up
func find_cmd(keys: Array[String], with_context: Mode) -> Dictionary:
	for cmd in key_map:
		# OperatorMotions in visual mode aren't allowed
		if cmd.type == OperatorMotion and with_context != Mode.NORMAL:
			continue
		
		# Allow Operators to be executed as-is in visual mode
		var skip_ctxcheck: bool = false
		if cmd.type == Operator and with_context != Mode.NORMAL:
			skip_ctxcheck = true
		
		if !skip_ctxcheck and cmd.has("context") and with_context != cmd.context: # Check context
			continue
		
		if !do_keys_contain(cmd.keys, keys):
			continue
		return cmd
	return {}

	# TODO try this:
	# for cmd in key_map.filter( check for context... ):
	# 	check for keys...
	# 	return cmd
	# return {}


func execute(cmd: Dictionary):
	# `if else` is faster than `match` (especially with small sets)
	if cmd.type == Motion:
		var pos: Vector2i = call_cmd(cmd.motion)
		cursor.set_caret_pos(pos.y, pos.x)
		return
	
	if cmd.type == OperatorMotion:
		execute_operator_motion(cmd.operator, cmd.motion)
		return
	
	if cmd.type == Operator:
		print("[KeyMay::execute()] op: ", cmd)
		if !cmd.has("modifier"): # Execute as-is
			call_cmd(cmd.operator)
			return
		
		if cmd.modifier.type == Motion:
			execute_operator_motion(cmd.operator, cmd.modifier.motion)
		
		return
	
	if cmd.type == Action:
		call_cmd(cmd.action)
		return
	
	push_error("[KeyMap::execute()] Unknown command type: %s" % cmd.type)


func execute_operator_motion(operator: Dictionary, motion: Dictionary):
	print("[KeyMay::execute_operator_motion()] op = ", operator, ", motion = ", motion)

	# Execute motion before operation
	# TODO line-wise motions (j, k, {, }, gg, G, etc)
	var p0: Vector2i = cursor.get_caret_pos()
	var p1: Vector2i = call_cmd(motion)
	cursor.code_edit.select(p0.y, p0.x, p1.y, p1.x)
	
	call_cmd(operator)


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


static func do_keys_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():	return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

## Check whether keys [param a] is contained in keys [param b]
static func do_keys_contain(a: Array, b: Array) -> bool:
	if b.size() < a.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func clear():
	input_stream = []


func get_input_stream_as_string() -> String:
	return ''.join(PackedStringArray(input_stream))


