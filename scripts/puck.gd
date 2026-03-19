class_name Puck
extends RigidBody3D

const SPAWN_SPREAD_X := 0.35
const SPAWN_SPREAD_Z := 0.60

var _spawn_position: Vector3
var _pending_reset := false
var _reset_target: Vector3


func _ready() -> void:
	_spawn_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_puck"):
		reset()


func hide_puck() -> void:
	visible = false
	freeze = true


func reset() -> void:
	_reset_target = _spawn_position + Vector3(
		randf_range(-SPAWN_SPREAD_X, SPAWN_SPREAD_X),
		0.0,
		randf_range(-SPAWN_SPREAD_Z, SPAWN_SPREAD_Z),
	)
	_pending_reset = true
	freeze = false
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _pending_reset:
		return
	state.transform = Transform3D(Basis.IDENTITY, _reset_target)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_pending_reset = false
	visible = true
