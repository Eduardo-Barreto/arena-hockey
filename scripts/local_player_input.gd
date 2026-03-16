class_name LocalPlayerInput
extends Node

@export var robot_index := 0

var _drive := DriveController.new()


func _physics_process(_delta: float) -> void:
	var prefix := "r%d_" % robot_index
	var axis_a := Input.get_axis(prefix + "back", prefix + "forward")
	var axis_b := Input.get_axis(prefix + "left", prefix + "right")
	var wheels := _drive.process(axis_a, axis_b)
	(get_parent() as Robot).receive_input(wheels.x, wheels.y)
