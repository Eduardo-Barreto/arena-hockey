class_name RobotConfigRow
extends PanelContainer

signal rebind_requested(row: RobotConfigRow, action: String)

const ACTION_LABELS := { forward = "Frente", back = "Trás", left = "Esq", right = "Dir" }
const TEAM_LETTERS := ["V", "A"]
const TEAM_COLORS: Array[Color] = [Color(1.0, 0.4, 0.4), Color(0.4, 0.5, 1.0)]

var robot_index := -1
var _auto_check: CheckBox
var _force_slider: HSlider
var _force_value: Label
var _torque_slider: HSlider
var _torque_value: Label
var _bind_buttons: Dictionary = {}
var _binds_box: HBoxContainer


func setup(idx: int) -> void:
	robot_index = idx
	var team := idx / GameConfig.ROBOTS_PER_TEAM
	var team_slot := idx % GameConfig.ROBOTS_PER_TEAM

	_apply_row_style()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	_add_robot_label(hbox, team, team_slot)
	hbox.add_child(_styled_separator())
	_add_auto_checkbox(hbox, idx)
	hbox.add_child(_styled_separator())
	_force_slider = _add_slider(hbox, "Vel", 1.0, 20.0, 0.5,
		GameConfig.robots[idx].max_engine_force, _on_force_changed)
	hbox.add_child(_styled_separator())
	_torque_slider = _add_slider(hbox, "Rot", 0.1, 5.0, 0.1,
		GameConfig.robots[idx].torque_multiplier, _on_torque_changed)
	hbox.add_child(_styled_separator())
	_add_bind_buttons(hbox, idx)
	hbox.add_child(_styled_separator())
	_add_reset_button(hbox)
	_update_binds_visibility()


func set_bind_waiting(action: String) -> void:
	(_bind_buttons[action] as Button).text = _format_bind_text(action, "...")


func update_bind_label(action: String) -> void:
	var event: InputEvent = GameConfig.robots[robot_index].bindings[action]
	(_bind_buttons[action] as Button).text = _format_bind_text(action, _event_label(event))


func _apply_row_style() -> void:
	var style := _create_stylebox(Color(1, 1, 1, 0.03), 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)


func _add_robot_label(parent: HBoxContainer, team: int, slot: int) -> void:
	var label := Label.new()
	label.text = "%s%d" % [TEAM_LETTERS[team], slot + 1]
	label.add_theme_color_override("font_color", TEAM_COLORS[team])
	label.add_theme_font_size_override("font_size", 20)
	label.custom_minimum_size.x = 36
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _add_slider(parent: HBoxContainer, label_text: String,
		min_val: float, max_val: float, step_val: float,
		initial: float, callback: Callable) -> HSlider:
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
	group.add_child(slider)

	var val_label := Label.new()
	val_label.text = str(initial)
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.custom_minimum_size.x = 32
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	group.add_child(val_label)

	slider.value_changed.connect(func(value: float) -> void:
		callback.call(value)
		val_label.text = str(value)
	)

	if label_text == "Vel":
		_force_value = val_label
	else:
		_torque_value = val_label

	return slider


func _add_auto_checkbox(parent: HBoxContainer, idx: int) -> void:
	_auto_check = CheckBox.new()
	_auto_check.text = "Auto"
	_auto_check.button_pressed = GameConfig.robots[idx].auto
	_auto_check.add_theme_font_size_override("font_size", 13)
	_auto_check.toggled.connect(_on_auto_toggled)
	parent.add_child(_auto_check)


func _update_binds_visibility() -> void:
	_binds_box.visible = not _auto_check.button_pressed


func _add_bind_buttons(parent: HBoxContainer, idx: int) -> void:
	_binds_box = HBoxContainer.new()
	_binds_box.add_theme_constant_override("separation", 6)
	parent.add_child(_binds_box)
	var binds_box := _binds_box

	for action in GameConfig.ACTIONS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 32)
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = _format_bind_text(action, _event_label(GameConfig.robots[idx].bindings[action]))
		btn.pressed.connect(_on_bind_pressed.bind(action))
		_apply_button_style(btn, Color(0.15, 0.15, 0.2), Color(0.2, 0.2, 0.28), Color(0.1, 0.1, 0.15),
			Color(0.3, 0.3, 0.4))
		binds_box.add_child(btn)
		_bind_buttons[action] = btn


func _add_reset_button(parent: HBoxContainer) -> void:
	var btn := Button.new()
	btn.text = "Reset"
	btn.custom_minimum_size = Vector2(60, 32)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(_on_reset)
	_apply_button_style(btn, Color(0.35, 0.15, 0.15), Color(0.45, 0.18, 0.18), Color(0.25, 0.1, 0.1))
	parent.add_child(btn)


func _on_reset() -> void:
	GameConfig.reset_robot(robot_index)
	var config: Dictionary = GameConfig.robots[robot_index]
	_auto_check.button_pressed = config.auto
	_force_slider.value = config.max_engine_force
	_torque_slider.value = config.torque_multiplier
	for action in GameConfig.ACTIONS:
		update_bind_label(action)
	_update_binds_visibility()


func _on_auto_toggled(enabled: bool) -> void:
	GameConfig.robots[robot_index].auto = enabled
	_update_binds_visibility()


func _on_force_changed(value: float) -> void:
	GameConfig.robots[robot_index].max_engine_force = value


func _on_torque_changed(value: float) -> void:
	GameConfig.robots[robot_index].torque_multiplier = value


func _on_bind_pressed(action: String) -> void:
	rebind_requested.emit(self, action)


func _format_bind_text(action: String, key_text: String) -> String:
	return "%s  %s" % [ACTION_LABELS.get(action, action), key_text]


func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode: Key = (event as InputEventKey).physical_keycode
		return OS.get_keycode_string(keycode) if keycode != KEY_NONE else "?"
	if event is InputEventJoypadButton:
		return "Joy%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "Ax%d%s" % [motion.axis, "+" if motion.axis_value > 0 else "-"]
	return "?"


func _styled_separator() -> VSeparator:
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 2
	sep.modulate = Color(1, 1, 1, 0.15)
	return sep


func _create_stylebox(bg: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border != Color.TRANSPARENT:
		style.border_color = border
		style.border_width_bottom = 1
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1
	return style


func _apply_button_style(btn: Button, normal_bg: Color, hover_bg: Color,
		pressed_bg: Color, border := Color.TRANSPARENT) -> void:
	var normal := _create_stylebox(normal_bg, 4, border)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = hover_bg
	if border != Color.TRANSPARENT:
		hover.border_color = Color(border, 1.3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = pressed_bg
	btn.add_theme_stylebox_override("pressed", pressed)
