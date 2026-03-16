class_name RobotConfigRow
extends PanelContainer

signal rebind_requested(row: RobotConfigRow, action: String)

var robot_index := -1

var _force_slider: HSlider
var _force_value: Label
var _torque_slider: HSlider
var _torque_value: Label
var _bind_buttons: Dictionary = {}


func setup(idx: int) -> void:
	robot_index = idx
	var team := idx / 3
	var team_slot := idx % 3
	var team_letter := "V" if team == 0 else "A"
	var color := Color(1.0, 0.4, 0.4) if team == 0 else Color(0.4, 0.5, 1.0)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(1, 1, 1, 0.03)
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_left = 6
	row_style.corner_radius_bottom_right = 6
	row_style.content_margin_left = 12
	row_style.content_margin_right = 12
	row_style.content_margin_top = 8
	row_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	var label := Label.new()
	label.text = "%s%d" % [team_letter, team_slot + 1]
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 20)
	label.custom_minimum_size.x = 36
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	hbox.add_child(_styled_separator())

	_add_slider_group(hbox, "Vel", 1.0, 20.0, 0.5,
		GameConfig.robots[idx].max_engine_force, _on_force_changed)

	hbox.add_child(_styled_separator())

	_add_slider_group(hbox, "Rot", 0.1, 5.0, 0.1,
		GameConfig.robots[idx].torque_multiplier, _on_torque_changed)

	hbox.add_child(_styled_separator())

	var binds_box := HBoxContainer.new()
	binds_box.add_theme_constant_override("separation", 6)
	hbox.add_child(binds_box)

	for action in GameConfig.ACTIONS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 32)
		btn.add_theme_font_size_override("font_size", 13)
		_apply_bind_button_style(btn)
		btn.text = "%s  %s" % [_action_label(action), _event_label(GameConfig.robots[idx].bindings[action])]
		btn.pressed.connect(_on_bind_pressed.bind(action))
		binds_box.add_child(btn)
		_bind_buttons[action] = btn

	hbox.add_child(_styled_separator())

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(60, 32)
	reset_btn.add_theme_font_size_override("font_size", 12)
	_apply_reset_button_style(reset_btn)
	reset_btn.pressed.connect(_on_reset)
	hbox.add_child(reset_btn)


func set_bind_waiting(action: String) -> void:
	(_bind_buttons[action] as Button).text = "%s  ..." % _action_label(action)


func update_bind_label(action: String) -> void:
	var event: InputEvent = GameConfig.robots[robot_index].bindings[action]
	(_bind_buttons[action] as Button).text = "%s  %s" % [_action_label(action), _event_label(event)]


func _add_slider_group(parent: HBoxContainer, label_text: String,
		min_val: float, max_val: float, step_val: float,
		initial: float, callback: Callable) -> void:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 6)
	parent.add_child(group)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	group.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial
	slider.custom_minimum_size.x = 100
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(callback)
	group.add_child(slider)

	var val_label := Label.new()
	val_label.text = str(initial)
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.custom_minimum_size.x = 32
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	group.add_child(val_label)

	if label_text == "Vel":
		_force_slider = slider
		_force_value = val_label
	else:
		_torque_slider = slider
		_torque_value = val_label


func _on_reset() -> void:
	GameConfig.reset_robot(robot_index)
	var config: Dictionary = GameConfig.robots[robot_index]
	_force_slider.value = config.max_engine_force
	_torque_slider.value = config.torque_multiplier
	for action in GameConfig.ACTIONS:
		update_bind_label(action)


func _on_force_changed(value: float) -> void:
	GameConfig.robots[robot_index].max_engine_force = value
	_force_value.text = str(value)


func _on_torque_changed(value: float) -> void:
	GameConfig.robots[robot_index].torque_multiplier = value
	_torque_value.text = str(value)


func _on_bind_pressed(action: String) -> void:
	rebind_requested.emit(self, action)


func _action_label(action: String) -> String:
	var labels := { forward = "Frente", back = "Trás", left = "Esq", right = "Dir" }
	return labels.get(action, action)


func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode: Key = (event as InputEventKey).physical_keycode
		return OS.get_keycode_string(keycode) if keycode != KEY_NONE else "?"
	if event is InputEventJoypadButton:
		return "Joy%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var axis_event := event as InputEventJoypadMotion
		var sign_str := "+" if axis_event.axis_value > 0 else "-"
		return "Ax%d%s" % [axis_event.axis, sign_str]
	return "?"


func _styled_separator() -> VSeparator:
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	sep.modulate = Color(1, 1, 1, 0.15)
	return sep


func _apply_reset_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.35, 0.15, 0.15)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.45, 0.18, 0.18)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.25, 0.1, 0.1)
	btn.add_theme_stylebox_override("pressed", pressed)


func _apply_bind_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.border_color = Color(0.3, 0.3, 0.4)
	normal.border_width_bottom = 1
	normal.border_width_top = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.28)
	hover.border_color = Color(0.4, 0.4, 0.55)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.1, 0.1, 0.15)
	btn.add_theme_stylebox_override("pressed", pressed)
