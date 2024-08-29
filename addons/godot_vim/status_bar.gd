extends HBoxContainer
const ERROR_COLOR: String = "#ff8866"
const SPECIAL_COLOR: String = "#fcba03"

const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode

var mode_label: Label
var main_label: RichTextLabel
var key_label: Label


func _ready():
	var font = load("res://addons/godot_vim/hack_regular.ttf")

	mode_label = Label.new()
	mode_label.text = ""
	mode_label.add_theme_color_override(&"font_color", Color.BLACK)
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = Color.GOLD
	stylebox.content_margin_left = 4.0
	stylebox.content_margin_right = 4.0
	stylebox.content_margin_top = 2.0
	stylebox.content_margin_bottom = 2.0
	mode_label.add_theme_stylebox_override(&"normal", stylebox)
	mode_label.add_theme_font_override(&"font", font)
	add_child(mode_label)

	main_label = RichTextLabel.new()
	main_label.bbcode_enabled = true
	main_label.text = ""
	main_label.fit_content = true
	main_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_label.add_theme_font_override(&"normal_font", font)
	add_child(main_label)

	key_label = Label.new()
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_label.text = ""
	key_label.add_theme_font_override(&"font", font)
	key_label.custom_minimum_size.x = 120
	add_child(key_label)


func display_text(text: String):
	main_label.text = text


func display_error(text: String):
	main_label.text = "[color=%s]%s" % [ERROR_COLOR, text]


func display_special(text: String):
	main_label.text = "[color=%s]%s" % [SPECIAL_COLOR, text]


func set_mode_text(mode: Mode):
	var stylebox: StyleBoxFlat = mode_label.get_theme_stylebox(&"normal")
	match mode:
		Mode.NORMAL:
			mode_label.text = "NORMAL"
			stylebox.bg_color = Color.LIGHT_SALMON
		Mode.INSERT:
			mode_label.text = "INSERT"
			stylebox.bg_color = Color.POWDER_BLUE
		Mode.VISUAL:
			mode_label.text = "VISUAL"
			stylebox.bg_color = Color.PLUM
		Mode.VISUAL_LINE:
			mode_label.text = "VISUAL LINE"
			stylebox.bg_color = Color.PLUM
		Mode.COMMAND:
			mode_label.text = "COMMAND"
			stylebox.bg_color = Color.TOMATO
		_:
			pass


func set_keys_text(text: String):
	key_label.text = text


func clear():
	main_label.text = ""


func clear_keys():
	key_label.text = ""
