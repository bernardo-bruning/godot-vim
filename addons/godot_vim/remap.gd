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
	# REPLACE,
}

# Inner cmd
var inner: Dictionary = {}
var options: Dictionary = {
	"apply_mode": ApplyMode.APPEND
}

# TODO allow the user to control the position of this remap inside `KeyMap.key_map`
# TODO allow the user to remove certain keybinds

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
			var err: Error = key_map.insert(0, inner)
			if err != OK:
				push_error("[Godot VIM] Failed to prepend keybind: %s" % error_string(err))
		
		ApplyMode.INSERT:
			var index: int = options.get("index", 0)
			var err: Error = key_map.insert(index, inner)
			if err != OK:
				push_error("[Godot VIM] Failed to insert keybind at index %s: %s" % [ index, error_string(err) ])
		
		ApplyMode.REMOVE:
			var inner_keys: Array[String] = inner.get("keys")
			if inner_keys == null:
				push_error("[Godot VIM] Failed to remove keybind: keys not specified")
				return
			if inner_keys.is_empty():
				push_error("[Godot VIM] Failed to remove keybind: keys cannot be empty")
				return
			
			# Find the specified keybind
			for i in key_map.size():
				var cmd: Dictionary = key_map[i]
				# Check keys
				var m: KeyMap.KeyMatch = KeyMap.match_keys(cmd.keys, inner_keys)
				if m != KeyMap.KeyMatch.Full:
					continue
				
				# If types DON'T match (if specified, ofc), skip
				if inner.has("type") and inner.type != cmd.type:
					continue
				
				# If contexts DON'T match (if specified, ofc), skip
				if inner.get("context", -1) != cmd.get("context", -1):
					continue
				
				key_map.remove_at(i)
				return
		
		_: # Unreachable
			pass


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


#endregion
