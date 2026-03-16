class_name DriveController
extends RefCounted

enum Mode { TANK, TWIN_STICK }

var mode: Mode = Mode.TWIN_STICK


func process(axis_a: float, axis_b: float) -> Vector2:
	match mode:
		Mode.TANK:
			return Vector2(axis_a, axis_b)
		Mode.TWIN_STICK:
			return Vector2(
				clampf(axis_a + axis_b, -1.0, 1.0),
				clampf(axis_a - axis_b, -1.0, 1.0),
			)
		_:
			return Vector2.ZERO
