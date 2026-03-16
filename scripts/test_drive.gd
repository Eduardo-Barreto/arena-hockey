extends Node3D

@onready var robot: Robot = $Robot

var _drive := DriveController.new()


func _physics_process(_delta: float) -> void:
	var axis_a := Input.get_axis("drive_back", "drive_forward")
	var axis_b := Input.get_axis("drive_left", "drive_right")
	var wheels := _drive.process(axis_a, axis_b)
	robot.receive_input(wheels.x, wheels.y)
