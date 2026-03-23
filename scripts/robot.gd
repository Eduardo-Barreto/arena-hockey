class_name Robot
extends RigidBody3D

@export var max_engine_force := 8.0
@export var torque_multiplier := 1.0
@export var max_speed := 2.0
@export var wheel_separation := 0.16
@export var team_color := Color.RED

const PUCK_GRACE_TIME := 0.3

var has_puck := false
var _left_input := 0.0
var _right_input := 0.0
var _puck_grace := 0.0


func _ready() -> void:
	var scoop_mat := StandardMaterial3D.new()
	scoop_mat.albedo_color = team_color
	$RightScoop.material_override = scoop_mat
	$LeftScoop.material_override = scoop_mat
	$PuckDetector.body_entered.connect(_on_puck_detector_entered)
	$PuckDetector.body_exited.connect(_on_puck_detector_exited)


func _on_puck_detector_entered(body: Node3D) -> void:
	if body is Puck:
		has_puck = true
		_puck_grace = 0.0


func _on_puck_detector_exited(body: Node3D) -> void:
	if body is Puck:
		_puck_grace = PUCK_GRACE_TIME


func receive_input(left: float, right: float) -> void:
	_left_input = clampf(left, -1.0, 1.0)
	_right_input = clampf(right, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	if _puck_grace > 0.0:
		_puck_grace -= delta
		if _puck_grace <= 0.0:
			has_puck = false

	var left_force := _left_input * max_engine_force
	var right_force := _right_input * max_engine_force

	var forward := basis.z
	forward.y = 0.0
	var traction := forward.length()
	if traction < 0.001:
		return
	forward /= traction

	var net_force := (left_force + right_force) / 2.0
	var speed := linear_velocity.length()
	if speed < max_speed or net_force * linear_velocity.dot(forward) <= 0.0:
		apply_central_force(forward * net_force * traction)

	var yaw_torque := (right_force - left_force) * wheel_separation / 2.0 * torque_multiplier
	apply_torque(Vector3.UP * yaw_torque * traction)
