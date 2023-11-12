class_name KeyMap extends RefCounted
## Hanldes input stream and key mapping

const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode


enum {
	Motion,
	Operator,
	OperatorMotion,
	Action,
}

enum MotionType {
	MoveByChars,
	MoveByLines,
	ToLineStart,
	ToLineEnd,
	MoveByWord,
	StartOfLine,
	EndOfLine,
	FirstNonWhitespaceChar,
}

enum ActionType {
	Insert,
	Visual,
	Undo,
	Redo,
	Join,
}

enum OperatorType {
	Delete,
	Change,
	Yank,
	Paste,
}


# `static var` doesn't work
const key_map: Array[Dictionary] = [
	{ "keys": ["h"], "type": Motion, "motion": { "type": MotionType.MoveByChars, "move_by": -1 } },
	{ "keys": ["l"], "type": Motion, "motion": { "type": MotionType.MoveByChars, "move_by": 1 } },
	{ "keys": ["j"], "type": Motion, "motion": { "type": MotionType.MoveByLines, "move_by": 1 } },
	{ "keys": ["k"], "type": Motion, "motion": { "type": MotionType.MoveByLines, "move_by": -1 } },
	{ "keys": ["w"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": true, "word_end": false } },
	{ "keys": ["e"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": true, "word_end": true } },
	{ "keys": ["b"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": false, "word_end": false } },
	{ "keys": ["g", "e"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": false, "word_end": true } },
	{ "keys": ["W"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": true, "word_end": false, "big_word": true } },
	{ "keys": ["E"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": true, "word_end": true, "big_word": true } },
	{ "keys": ["B"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": false, "word_end": false, "big_word": true } },
	{ "keys": ["g", "E"], "type": Motion, "motion": { "type": MotionType.MoveByWord, "forward": false, "word_end": true, "big_word": true } },
	{ "keys": ["0"], "type": Motion, "motion": { "type": MotionType.StartOfLine } },
	{ "keys": ["$"], "type": Motion, "motion": { "type": MotionType.EndOfLine } },
	{ "keys": ["^"], "type": Motion, "motion": { "type": MotionType.FirstNonWhitespaceChar } },
	
	{ "keys": ["x"], "type": OperatorMotion, "context": Mode.NORMAL,
		"operator": { "type": OperatorType.Delete },
		"motion": { "type": MotionType.MoveByChars, "move_by": 1 }
	},
	{ "keys": ["x"], "type": OperatorMotion, "context": Mode.VISUAL,
		"operator": { "type": OperatorType.Delete },
		"motion": { "type": MotionType.MoveByChars, "move_by": 1 }
	},
	{ "keys": ["D"], "type": OperatorMotion, "context": Mode.NORMAL,
		"operator": { "type": OperatorType.Delete },
		"motion": { "type": MotionType.EndOfLine, "inclusive": true }
	},
	{ "keys": ["p"], "type": OperatorMotion,
		"operator": { "type": OperatorType.Paste },
		"motion": { "type": MotionType.MoveByChars, "move_by": 1 }
	},
	
	{ "keys": ["i"], "type": Action, "action": { "type": ActionType.Insert } },
	{ "keys": ["a"], "type": Action, "action": { "type": ActionType.Insert, "offset": "after" } },
	{ "keys": ["I"], "type": Action, "action": { "type": ActionType.Insert, "offset": "bol" } },
	{ "keys": ["A"], "type": Action, "action": { "type": ActionType.Insert, "offset": "eol" } },
	{ "keys": ["o"], "type": Action, "action": { "type": ActionType.Insert, "offset": "new_line_below" } },
	{ "keys": ["O"], "type": Action, "action": { "type": ActionType.Insert, "offset": "new_line_above" } },
	{ "keys": ["v"], "type": Action, "action": { "type": ActionType.Visual } },
	{ "keys": ["u"], "type": Action, "action": { "type": ActionType.Undo } },
	{ "keys": ["<C-r>"], "type": Action, "action": { "type": ActionType.Redo } },
	{ "keys": ["J"], "type": Action, "action": { "type": ActionType.Join } },
]

# `static var` also doesn't work
const whitelist = [
	"<C-s>"
]


var input_stream: Array[String] = []


## Returns: Array[Dictionary]
func register_event(event: InputEventKey, with_context: Mode) -> Dictionary:
	var ch: String = get_event_char(event)
	if ch.is_empty():	return {} # Invalid
	if whitelist.has(ch):	return {}
	
	# print("[KeyMap] registering event: ", ch) # DEBUG
	input_stream.append(ch)
	
	# Find command
	for keymap in key_map:
		if keymap.has("context") and with_context != keymap.context:	continue
		
		if !do_keys_match(input_stream, keymap.keys):	continue
		
		call_deferred(&"clear")
		# print("[KeyMap] registered cmd: ", keymap) # DEBUG
		return keymap
	return {}


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


func clear():
	input_stream = []


func get_input_stream_as_string() -> String:
	return ''.join(PackedStringArray(input_stream))

