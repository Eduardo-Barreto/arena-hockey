class_name GameManager
extends Node3D

const ROBOT_SCENE := preload("res://models/robot.tscn")
const INPUT_SCRIPT := preload("res://scripts/local_player_input.gd")
const AI_SCRIPT := preload("res://scripts/ai_player_input.gd")

const TEAM_COLORS: Array[Color] = [Color.RED, Color(0.149, 0.251, 0.851)]
const TEAM_X := [-0.7, 0.7]
const TEAM_ROT_Y := [PI / 2.0, -PI / 2.0]
const SPAWN_Y := 0.25
const Z_SPREAD: Array[Array] = [
	[0.0],
	[-0.3, 0.3],
	[0.0, -0.3, 0.3],
]

var _robots: Array[Robot] = []


func _ready() -> void:
	GameConfig.config_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for robot in _robots:
		robot.queue_free()
	_robots.clear()

	for team in TEAM_COLORS.size():
		var enabled_indices := _get_enabled_indices(team)
		if enabled_indices.is_empty():
			continue
		var positions: Array = Z_SPREAD[enabled_indices.size() - 1]
		for slot_idx in enabled_indices.size():
			_spawn_robot(enabled_indices[slot_idx], team, positions[slot_idx])


func _get_enabled_indices(team: int) -> Array[int]:
	var start := team * GameConfig.ROBOTS_PER_TEAM
	var indices: Array[int] = []
	for i in range(start, start + GameConfig.ROBOTS_PER_TEAM):
		if GameConfig.robots[i].enabled:
			indices.append(i)
	return indices


func _spawn_robot(robot_idx: int, team: int, z_pos: float) -> void:
	var config: Dictionary = GameConfig.robots[robot_idx]

	var robot: Robot = ROBOT_SCENE.instantiate()
	robot.max_engine_force = config.max_engine_force
	robot.torque_multiplier = config.torque_multiplier
	robot.team_color = TEAM_COLORS[team]
	robot.transform.origin = Vector3(TEAM_X[team], SPAWN_Y, z_pos)
	robot.transform.basis = Basis(Vector3.UP, TEAM_ROT_Y[team])

	var input_node := Node.new()
	input_node.name = "Input"
	if config.auto:
		input_node.set_script(AI_SCRIPT)
		input_node.set("team", team)
	else:
		input_node.set_script(INPUT_SCRIPT)
		input_node.set("robot_index", robot_idx)
	robot.add_child(input_node)

	add_child(robot)
	_robots.append(robot)
