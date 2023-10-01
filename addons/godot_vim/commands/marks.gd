const Contants = preload("res://addons/godot_vim/constants.gd")
const StatusBar = preload("res://addons/godot_vim/status_bar.gd")
const Mode = Contants.Mode

func execute(api, _args):
	var marks: Dictionary = api.get('marks', {})
	if marks.is_empty():
		api.status_bar.display_error("No marks set")
		api.cursor.set_mode(Mode.NORMAL)
		return

	var display_mark = func(key: String, m: Dictionary) -> String:
		var pos: Vector2i = m.get('pos', Vector2i())
		var file: String = m.get('file', '')
		return "\n%s\t\t%s \t%s \t\t %s" % [key, pos.y, pos.x, file]

	var text: String = "[color=%s]List of all marks[/color]\nmark\tline\tcol \t file" % StatusBar.SPECIAL_COLOR
	for key in marks.keys():
		var unicode: int = key.unicode_at(0)
		if (unicode < 65 or unicode > 90) and (unicode < 97 or unicode > 122):
			continue
		text += display_mark.call(key, marks[key])
	for key in marks.keys():
		var unicode: int = key.unicode_at(0)
		if (unicode >= 65 and unicode <= 90) or (unicode >= 97 and unicode <= 122) or key == "-1":
			continue
		text += display_mark.call(key, marks[key])

	api.status_bar.display_text(text, Control.TEXT_DIRECTION_LTR)
