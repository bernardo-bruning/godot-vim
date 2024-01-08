const Contants = preload("res://addons/godot_vim/constants.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Mode = Contants.Mode

const LINE_START_IDX: int = 8
const COL_START_IDX: int = 16
const FILE_START_IDX: int = 25

""" Display format:
(1) LINE_START_IDX
(2) COL_START_IDX
(3) FILE_START_IDX

List of all marks:
		(1)     (2)    (3)
		|       |      |
mark    line    col    file
a       123     456    res://some_file
...

"""

func row_string(mark: String, line: String, col: String, file: String) -> String:
	var text: String = mark
	text += " ".repeat(LINE_START_IDX - mark.length()) + line
	text += " ".repeat(COL_START_IDX - text.length()) + col
	text += " ".repeat(FILE_START_IDX - text.length()) + file
	return text

func mark_string(key: String, m: Dictionary) -> String:
	var pos: Vector2i = m.get('pos', Vector2i())
	var file: String = m.get('file', '')
	return row_string(key, str(pos.y), str(pos.x), file)


func execute(api, _args):
	var marks: Dictionary = api.get('marks', {})
	if marks.is_empty():
		api.status_bar.display_error("No marks set")
		api.cursor.set_mode(Mode.NORMAL)
		return

	var text: String = "[color=%s]List of all marks[/color]" % StatusBar.SPECIAL_COLOR
	text += "\n" + row_string("mark", "line", "col", "file")
	
	# Display user-defined marks first (alphabet)
	for key in marks.keys():
		if !is_key_alphabet(key):
			continue
		text += "\n" + mark_string(key, marks[key])
	
	# Then display 'number' marks
	for key in marks.keys():
		if is_key_alphabet(key) or key == "-1":
			continue
		text += "\n" + mark_string(key, marks[key])

	api.status_bar.display_text(text)


func is_key_alphabet(key: String) -> bool:
	var unicode: int = key.unicode_at(0)
	return (unicode >= 65 and unicode <= 90) or (unicode >= 97 and unicode <= 122)
