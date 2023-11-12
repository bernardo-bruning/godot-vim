class_name KeyMap
## Hanldes input stream and key mapping


enum Type {
	Motion,
	Operator,
	Action,
	Incomplete, # Await input
}

enum Motion {
	MoveX,
	MoveY,
}


static var key_map: Array[Dictionary] = [
	{ "keys": ["j"], "type": Type.Motion, "motion": Motion.MoveX }
]

static var whitelist = [
	"<C-s>"
]


static var input_stream: String = ""


static func register_event(event: InputEventKey) -> Dictionary:
	var ch: String = get_event_char(event)
	# print("[KeyMap::register_event()] registered event: ", ch) # DEBUG
	input_stream += ch
	
	var a: Array = split_count(input_stream)
	if a.is_empty():	return {}
	
	var count: int = a[0]
	var cmd: String = a[1]
	return {
		'count' : count,
		'cmd' : cmd,
	}


static func get_event_char(event: InputEventKey) -> String:
	if event.keycode == KEY_ENTER:
		return "<CR>"
	if event.keycode == KEY_TAB:
		return "<TAB>"
	if event.is_command_or_control_pressed():
		var c: String = char(event.keycode)
		return "<C-%s>" % [ c if event.shift_pressed else c.to_lower() ]
	return char(event.unicode)


static func clear_input_stream():
	input_stream = ""



# returns:
#  [] if invalid / incomplete
#  [ count: int, rest of the string: String ]
static func split_count(str: String) -> Array:
	if str.is_empty():	return []
	if str[0] == '0':	return [] # Those that start with '0' is are exceptions
	for i in str.length():
		if !'0123456789'.contains(str[i]):
			return [ maxi(str.left(i).to_int(), 1), str.substr(i) ]
	return [] # All digits


