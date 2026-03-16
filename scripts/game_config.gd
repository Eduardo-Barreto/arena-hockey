extends Node

signal config_changed

const SAVE_PATH := "user://settings.cfg"
const ACTIONS := ["forward", "back", "left", "right"]
const ROBOT_COUNT := 6

var robots: Array[Dictionary] = []

var _default_bindings := [
	{ forward = KEY_W, back = KEY_S, left = KEY_A, right = KEY_D },
	{ forward = KEY_T, back = KEY_G, left = KEY_F, right = KEY_H },
	{ forward = KEY_I, back = KEY_K, left = KEY_J, right = KEY_L },
	{ forward = KEY_UP, back = KEY_DOWN, left = KEY_LEFT, right = KEY_RIGHT },
	{ forward = KEY_KP_8, back = KEY_KP_5, left = KEY_KP_4, right = KEY_KP_6 },
	{ forward = KEY_HOME, back = KEY_END, left = KEY_DELETE, right = KEY_PAGEDOWN },
]


func _ready() -> void:
	_init_defaults()
	_load()
	apply_input_map()


func _init_defaults() -> void:
	robots.clear()
	for i in ROBOT_COUNT:
		var bindings := {}
		var defaults: Dictionary = _default_bindings[i]
		for action in ACTIONS:
			var event := InputEventKey.new()
			event.physical_keycode = defaults[action]
			bindings[action] = event
		robots.append({
			enabled = (i == 0 or i == 3),
			max_engine_force = 8.0,
			torque_multiplier = 1.0,
			bindings = bindings,
		})


func get_team_size(team: int) -> int:
	var start := team * 3
	var count := 0
	for i in range(start, start + 3):
		if robots[i].enabled:
			count += 1
	return count


func set_team_size(team: int, size: int) -> void:
	var start := team * 3
	for i in range(start, start + 3):
		robots[i].enabled = (i - start) < size


func reset_robot(idx: int) -> void:
	var defaults: Dictionary = _default_bindings[idx]
	var bindings := {}
	for action in ACTIONS:
		var event := InputEventKey.new()
		event.physical_keycode = defaults[action]
		bindings[action] = event
	robots[idx].max_engine_force = 8.0
	robots[idx].torque_multiplier = 1.0
	robots[idx].bindings = bindings


func apply_input_map() -> void:
	for i in ROBOT_COUNT:
		for action in ACTIONS:
			var action_name := "r%d_%s" % [i, action]
			if InputMap.has_action(action_name):
				InputMap.action_erase_events(action_name)
			else:
				InputMap.add_action(action_name, 0.2)
			InputMap.action_add_event(action_name, robots[i].bindings[action])


func save() -> void:
	var config := ConfigFile.new()
	for i in ROBOT_COUNT:
		var section := "robot_%d" % i
		var robot: Dictionary = robots[i]
		config.set_value(section, "enabled", robot.enabled)
		config.set_value(section, "max_engine_force", robot.max_engine_force)
		config.set_value(section, "torque_multiplier", robot.torque_multiplier)
		for action in ACTIONS:
			var event: InputEvent = robot.bindings[action]
			if event is InputEventKey:
				config.set_value(section, "bind_%s_keycode" % action, (event as InputEventKey).physical_keycode)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for i in ROBOT_COUNT:
		var section := "robot_%d" % i
		if not config.has_section(section):
			continue
		var robot: Dictionary = robots[i]
		robot.enabled = config.get_value(section, "enabled", robot.enabled)
		robot.max_engine_force = config.get_value(section, "max_engine_force", robot.max_engine_force)
		robot.torque_multiplier = config.get_value(section, "torque_multiplier", robot.torque_multiplier)
		for action in ACTIONS:
			var key := "bind_%s_keycode" % action
			if config.has_section_key(section, key):
				var event := InputEventKey.new()
				event.physical_keycode = config.get_value(section, key) as Key
				robot.bindings[action] = event
