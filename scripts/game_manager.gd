class_name GameManager
extends Node3D

const ROBOT_SCENE := preload("res://models/robot.tscn")
const INPUT_SCRIPT := preload("res://scripts/local_player_input.gd")

const TEAM_COLORS: Array[Color] = [Color.RED, Color(0.149, 0.251, 0.851)]
const TEAM_X := [-0.7, 0.7]
const TEAM_ROT_Y := [PI / 2.0, -PI / 2.0]
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

	for team in 2:
		var start := team * 3
		var enabled_indices: Array[int] = []
		for i in range(start, start + 3):
			if GameConfig.robots[i].enabled:
				enabled_indices.append(i)

		var positions: Array = Z_SPREAD[enabled_indices.size() - 1] if enabled_indices.size() > 0 else []
		for slot_idx in enabled_indices.size():
			var robot_idx: int = enabled_indices[slot_idx]
			var config: Dictionary = GameConfig.robots[robot_idx]

			var robot: Robot = ROBOT_SCENE.instantiate()
			robot.max_engine_force = config.max_engine_force
			robot.torque_multiplier = config.torque_multiplier
			robot.team_color = TEAM_COLORS[team]
			robot.transform.origin = Vector3(TEAM_X[team], 0.25, positions[slot_idx])
			robot.transform.basis = Basis(Vector3.UP, TEAM_ROT_Y[team])

			var input_node := Node.new()
			input_node.name = "Input"
			input_node.set_script(INPUT_SCRIPT)
			input_node.set("robot_index", robot_idx)
			robot.add_child(input_node)

			add_child(robot)
			_robots.append(robot)
