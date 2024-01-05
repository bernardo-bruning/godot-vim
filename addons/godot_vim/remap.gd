class_name KeyRemap extends RefCounted

const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode

var inner: Dictionary = {}

# TODO allow the user to control the position of this remap inside `KeyMap.key_map`

func _init(keys: Array[String]):
	assert(!keys.is_empty(), "cmd_keys cannot be empty")
	inner = { "keys": keys }


## Returns self
func motion(motion_type: String, args: Dictionary = {}) -> KeyRemap:
	var m: Dictionary = { "type": motion_type }
	m.merge(args, true)
	inner.motion = m
	
	# Operator + Motion = OperatorMotion
	if inner.get("type") == KeyMap.Operator:
		inner.type = KeyMap.OperatorMotion
	else:
		inner.type = KeyMap.Motion
	return self

## Returns self
func operator(operator_type: String, args: Dictionary = {}) -> KeyRemap:
	var o: Dictionary = { "type": operator_type }
	o.merge(args, true)
	inner.operator = o
	
	# Motion + Operator = OperatorMotion
	if inner.get("type") == KeyMap.Motion:
		inner.type = KeyMap.OperatorMotion
	else:
		inner.type = KeyMap.Operator
	return self

## Returns self
func action(action_type: String, args: Dictionary = {}) -> KeyRemap:
	var a: Dictionary = { "type": action_type }
	a.merge(args, true)
	inner.action = a
	inner.type = KeyMap.Action
	return self


## Returns self
func with_context(mode: Mode) -> KeyRemap:
	inner["context"] = mode
	return self

func as_dict() -> Dictionary:
	return inner

