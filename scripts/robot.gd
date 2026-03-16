class_name Robot
extends RigidBody3D

@export var max_engine_force := 8.0
@export var wheel_separation := 0.16

var _left_input := 0.0
var _right_input := 0.0


func receive_input(left: float, right: float) -> void:
	_left_input = clampf(left, -1.0, 1.0)
	_right_input = clampf(right, -1.0, 1.0)


func _physics_process(_delta: float) -> void:
	var left_force := _left_input * max_engine_force
	var right_force := _right_input * max_engine_force

	var forward := basis.z
	forward.y = 0.0
	var traction := forward.length()
	if traction < 0.001:
		return
	forward /= traction

	var net_force := (left_force + right_force) / 2.0
	apply_central_force(forward * net_force * traction)

	var yaw_torque := (right_force - left_force) * wheel_separation / 2.0
	apply_torque(Vector3.UP * yaw_torque * traction)
