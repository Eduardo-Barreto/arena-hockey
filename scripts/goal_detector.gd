class_name GoalDetector
extends Area3D

signal goal_scored
signal goal_reset

const RESET_DELAY := 2.0

var _reset_timer := 0.0
var _scored := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Puck and not _scored:
		_scored = true
		_reset_timer = RESET_DELAY
		(body as Puck).hide_puck()
		goal_scored.emit()
		print("[GOAL] scored!")


func _physics_process(delta: float) -> void:
	if not _scored:
		return

	_reset_timer -= delta
	if _reset_timer > 0.0:
		return

	_scored = false
	var pucks := get_tree().current_scene.find_children("*", "Puck")
	if not pucks.is_empty():
		(pucks[0] as Puck).reset()
	goal_reset.emit()
	print("[GOAL] puck reset")
