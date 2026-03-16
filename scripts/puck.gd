class_name Puck
extends RigidBody3D

var _spawn_position: Vector3


func _ready() -> void:
	_spawn_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_puck"):
		reset()


func reset() -> void:
	global_position = _spawn_position
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
