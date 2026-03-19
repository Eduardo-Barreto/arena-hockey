class_name AIPlayerInput
extends Node

enum State { SEEK, ATTACK, REVERSE, REPOSITION, WAITING }

const TURN_GAIN := 2.5
const OPPONENT_GOAL_X: Array[float] = [1.2, -1.2]
const STUCK_THRESHOLD := 0.01
const STUCK_TIME := 0.3
const REVERSE_TIME := 0.4
const ATTACK_REVERSE_TIME := 0.2
const REPOSITION_REVERSE_TIME := 1.0
const REPOSITION_THRESHOLD := 0.1

@export var team := 1

var _state := State.SEEK
var _puck: Puck
var _goal_x: float
var _goal_dir: float
var _spawn_position := Vector3.ZERO
var _last_position := Vector3.ZERO
var _stuck_timer := 0.0
var _reverse_timer := 0.0
var _log_timer := 0.0


func _ready() -> void:
	_goal_x = OPPONENT_GOAL_X[team]
	_goal_dir = signf(_goal_x)
	_spawn_position = (get_parent() as Robot).global_position
	_find_puck.call_deferred()
	_connect_goal_detectors.call_deferred()


func _find_puck() -> void:
	var pucks := get_tree().current_scene.find_children("*", "Puck")
	if not pucks.is_empty():
		_puck = pucks[0] as Puck


func _connect_goal_detectors() -> void:
	for node in get_tree().current_scene.find_children("*", "GoalDetector"):
		var detector := node as GoalDetector
		detector.goal_scored.connect(_on_goal_scored)
		detector.goal_reset.connect(_on_goal_reset)


func _on_goal_scored() -> void:
	var robot := get_parent() as Robot
	_reverse_timer = REPOSITION_REVERSE_TIME
	_change_state(State.REPOSITION, robot)


func _on_goal_reset() -> void:
	var robot := get_parent() as Robot
	if _state == State.WAITING or _state == State.REPOSITION:
		_change_state(State.SEEK, robot)


func _physics_process(delta: float) -> void:
	if not _puck:
		return

	_log_timer += delta
	var robot := get_parent() as Robot

	_transition(robot, delta)

	match _state:
		State.SEEK:
			_process_seek(robot, delta)
		State.ATTACK:
			_process_attack(robot)
		State.REVERSE:
			_process_reverse(robot)
		State.REPOSITION:
			_process_reposition(robot, delta)
		State.WAITING:
			_process_waiting(robot)


func _transition(robot: Robot, delta: float) -> void:
	match _state:
		State.SEEK:
			if robot.has_puck:
				_change_state(State.ATTACK, robot)
			elif _is_stuck(robot, delta):
				_reverse_timer = REVERSE_TIME
				_change_state(State.REVERSE, robot)

		State.ATTACK:
			if not robot.has_puck:
				_change_state(State.SEEK, robot)
			elif _is_stuck(robot, delta):
				_reverse_timer = ATTACK_REVERSE_TIME
				_change_state(State.REVERSE, robot)

		State.REVERSE:
			_reverse_timer -= delta
			if _reverse_timer <= 0.0:
				_change_state(State.SEEK, robot)

		State.REPOSITION:
			var dist := Vector2(
				robot.global_position.x - _spawn_position.x,
				robot.global_position.z - _spawn_position.z,
			).length()
			if dist < REPOSITION_THRESHOLD:
				_change_state(State.WAITING, robot)


func _change_state(new_state: State, robot: Robot) -> void:
	_stuck_timer = 0.0
	_last_position = robot.global_position
	_state = new_state


func _is_stuck(robot: Robot, delta: float) -> bool:
	var pos := robot.global_position
	var moved := Vector2(pos.x - _last_position.x, pos.z - _last_position.z).length()
	var rotating := absf(robot.angular_velocity.y) > 0.5

	if moved < STUCK_THRESHOLD and not rotating:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0

	_last_position = pos
	return _stuck_timer > STUCK_TIME


func _process_seek(robot: Robot, _delta: float) -> void:
	if _should_log():
		print("[AI:SEEK] robot=(%0.2f,%0.2f) puck=(%0.2f,%0.2f) stuck=%0.1f" % [robot.global_position.x, robot.global_position.z, _puck.global_position.x, _puck.global_position.z, _stuck_timer])
	_steer_toward(robot, _puck.global_position)


func _process_attack(robot: Robot) -> void:
	var past_goal := (robot.global_position.x - _goal_x) * _goal_dir > 0
	var target: Vector3

	if past_goal:
		target = Vector3(robot.global_position.x + _goal_dir * 1.0, robot.global_position.y, robot.global_position.z)
	else:
		target = Vector3(_goal_x, robot.global_position.y, 0.0)

	if _should_log():
		print("[AI:ATTACK] robot=(%0.2f,%0.2f) past=%s → target=(%0.2f,%0.2f)" % [robot.global_position.x, robot.global_position.z, past_goal, target.x, target.z])
	_steer_toward(robot, target)


func _process_reverse(robot: Robot) -> void:
	if _should_log():
		print("[AI:REVERSE] timer=%0.2f" % _reverse_timer)
	robot.receive_input(-1.0, -0.9)


func _process_reposition(robot: Robot, delta: float) -> void:
	if _reverse_timer > 0.0:
		_reverse_timer -= delta
		robot.receive_input(-1.0, -0.8)
		if _should_log():
			print("[AI:REPOSITION] REVERSE timer=%0.2f" % _reverse_timer)
		return

	if _should_log():
		print("[AI:REPOSITION] robot=(%0.2f,%0.2f) → spawn=(%0.2f,%0.2f)" % [robot.global_position.x, robot.global_position.z, _spawn_position.x, _spawn_position.z])
	_steer_toward(robot, _spawn_position)


func _process_waiting(robot: Robot) -> void:
	var forward := robot.basis.z
	forward.y = 0.0
	var center_dir := Vector3(_goal_dir, 0.0, 0.0)

	if forward.length_squared() > 0.0001:
		var dot := forward.normalized().dot(center_dir)
		if dot < 0.95:
			var cross_y := forward.normalized().cross(center_dir).y
			var turn := clampf(cross_y * TURN_GAIN, -1.0, 1.0)
			robot.receive_input(-turn, turn)
			if _should_log():
				print("[AI:WAITING] aligning to center dot=%0.2f" % dot)
			return

	robot.receive_input(0.0, 0.0)
	if _should_log():
		print("[AI:WAITING] aligned, waiting for puck reset")


func _steer_toward(robot: Robot, target: Vector3) -> void:
	var forward := robot.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()

	var to_target := target - robot.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		robot.receive_input(1.0, 1.0)
		return
	to_target = to_target.normalized()

	var dot := forward.dot(to_target)
	var cross_y := forward.cross(to_target).y
	var turn := clampf(cross_y * TURN_GAIN, -1.0, 1.0)

	if dot < -0.2:
		robot.receive_input(-turn, turn)
		return

	var speed := clampf(dot, 0.0, 1.0) * (1.0 - absf(turn) * 0.6)
	robot.receive_input(
		clampf(speed - turn, -1.0, 1.0),
		clampf(speed + turn, -1.0, 1.0),
	)


func _should_log() -> bool:
	if _log_timer < 0.5:
		return false
	_log_timer = 0.0
	return true
