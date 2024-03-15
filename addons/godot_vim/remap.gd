class_name KeyRemap extends RefCounted

const Constants = preload("res://addons/godot_vim/constants.gd")
const Mode = Constants.Mode

# (Man I wish we had enum structs in godot)
enum ApplyMode {
	## Append this keybind to the end of the list
	APPEND,
	
	## Insert this keybind at the start of the list
	PREPEND,
	
	## Insert this keybind at the specified index
	INSERT,
	
	## Remove the specified keybind
	REMOVE,
	
	## Replace a keybind with this one
	REPLACE,
}

# Inner cmd
var inner: Dictionary = {}
var options: Dictionary = {
	"apply_mode": ApplyMode.APPEND
}

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


# `key_map` = KeyMap::key_map
func apply(key_map: Array[Dictionary]):
	match options.get("apply_mode", ApplyMode.APPEND):
		ApplyMode.APPEND:
			key_map.append(inner)
		
		ApplyMode.PREPEND:
			var err: int = key_map.insert(0, inner)
			if err != OK:
				push_error("[Godot VIM] Failed to prepend keybind: %s" % error_string(err))
		
		ApplyMode.INSERT:
			var index: int = options.get("index", 0)
			var err: int = key_map.insert(index, inner)
			if err != OK:
				push_error("[Godot VIM] Failed to insert keybind at index %s: %s" % [ index, error_string(err) ])
		
		ApplyMode.REMOVE:
			var index: int = _find(key_map, inner)
			if index == -1:
				return
			key_map.remove_at(index)
		
		ApplyMode.REPLACE:
			var constraints: Dictionary = {
				"keys": inner.get("keys", [])
			}
			var index: int = _find(key_map, constraints)
			if index == -1:
				return
			
			# print('replacing at index ', index)
			key_map[index] = inner


#region Apply options

## Append this keybind to the end of the list
## Returns self
func append() -> KeyRemap:
	options = {
		"apply_mode": ApplyMode.APPEND
	}
	return self

## Insert this keybind at the start of the list
## Returns self
func prepend() -> KeyRemap:
	options = {
		"apply_mode": ApplyMode.PREPEND
	}
	return self

## Insert this keybind at the specified index
func insert_at(index: int) -> KeyRemap:
	options = {
		"apply_mode": ApplyMode.INSERT,
		"index": index,
	}
	return self

## Removes the keybind from the list
## Returns self
func remove() -> KeyRemap:
	options = {
		"apply_mode": ApplyMode.REMOVE
	}
	return self

## Replaces the keybind from the list with this new one
## Returns self
func replace():
	options = {
		"apply_mode": ApplyMode.REPLACE
	}
	return self


#endregion



func _find(key_map: Array[Dictionary], constraints: Dictionary) -> int:
	var keys: Array[String] = constraints.get("keys")
	if keys == null:
		push_error("[Godot VIM::KeyRemap::_find()] Failed to find keybind: keys not specified")
		return -1
	if keys.is_empty():
		push_error("[Godot VIM::KeyRemap::_find()] Failed to find keybind: keys cannot be empty")
		return -1
	
	for i in key_map.size():
		var cmd: Dictionary = key_map[i]
		# Check keys
		var m: KeyMap.KeyMatch = KeyMap.match_keys(cmd.keys, keys)
		if m != KeyMap.KeyMatch.Full:
			continue
		
		# If types DON'T match (if specified, ofc), skip
		if constraints.has("type") and constraints.type != cmd.type:
			continue
		
		# If contexts DON'T match (if specified, ofc), skip
		if constraints.get("context", -1) != cmd.get("context", -1):
			continue
		
		return i
	return -1


