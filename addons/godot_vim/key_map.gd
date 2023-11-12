class_name KeyMap extends RefCounted
## Hanldes input stream and key mapping


enum CmdType {
	Motion,
	Operator,
	Action,
	Incomplete, # Await input
}

enum MotionArgs {
	MoveByChars,
	MoveByLines,
}


# `static var` doesn't work
const key_map: Array[Dictionary] = [
	{ "keys": ["h"], "cmds": [ { "type": CmdType.Motion, MotionArgs.MoveByChars: -1 } ] },
	{ "keys": ["l"], "cmds": [ { "type": CmdType.Motion, MotionArgs.MoveByChars: 1 } ] },
	{ "keys": ["j"], "cmds": [ { "type": CmdType.Motion, MotionArgs.MoveByLines: 1 } ] },
	{ "keys": ["k"], "cmds": [ { "type": CmdType.Motion, MotionArgs.MoveByLines: -1 } ] },
]

# `static var` also doesn't work
const whitelist = [
	"<C-s>"
]


var input_stream: Array[String] = []


## Returns: Array[Dictionary]
func register_event(event: InputEventKey) -> Array:
	var ch: String = get_event_char(event)
	print("[KeyMap::register_event()] registered event: ", ch) # DEBUG
	input_stream.append(ch)
	
	for keymap in key_map:
		if !do_keys_match(input_stream, keymap.keys):	continue
		clear()
		return keymap.cmds
	return []


static func get_event_char(event: InputEventKey) -> String:
	if event.keycode == KEY_ENTER:
		return "<CR>"
	if event.keycode == KEY_TAB:
		return "<TAB>"
	if event.is_command_or_control_pressed():
		var c: String = char(event.keycode)
		return "<C-%s>" % [ c if event.shift_pressed else c.to_lower() ]
	return char(event.unicode)


static func do_keys_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():	return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func clear():
	input_stream = []


func get_input_stream_as_string() -> String:
	return ''.join(PackedStringArray(input_stream))

