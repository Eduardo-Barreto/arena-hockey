extends CanvasLayer

var _red_team_container: VBoxContainer
var _blue_team_container: VBoxContainer
var _red_spinbox: SpinBox
var _blue_spinbox: SpinBox
var _rows: Array[RobotConfigRow] = []

var _rebinding_row: RobotConfigRow = null
var _rebinding_action := ""

const RED_COLOR := Color(1.0, 0.4, 0.4)
const BLUE_COLOR := Color(0.4, 0.5, 1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1300, 700)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.11)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_color = Color(0.2, 0.2, 0.28)
	panel_style.border_width_bottom = 1
	panel_style.border_width_top = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.content_margin_left = 32
	panel_style.content_margin_right = 32
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(outer_vbox)

	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	outer_vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(scroll_vbox)

	_red_team_container = _create_team_section(scroll_vbox, 0, "TIME VERMELHO", RED_COLOR)
	_blue_team_container = _create_team_section(scroll_vbox, 1, "TIME AZUL", BLUE_COLOR)

	var apply_btn := Button.new()
	apply_btn.text = "APLICAR E VOLTAR"
	apply_btn.custom_minimum_size = Vector2(240, 44)
	apply_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apply_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_style(apply_btn)
	apply_btn.pressed.connect(_on_apply)
	outer_vbox.add_child(apply_btn)

	_rebuild_rows()


func _create_team_section(parent: VBoxContainer, team: int,
		header_text: String, color: Color) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	section.add_child(header)

	var left_line := HSeparator.new()
	left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_line.modulate = Color(color, 0.3)
	header.add_child(left_line)

	var team_label := Label.new()
	team_label.text = header_text
	team_label.add_theme_color_override("font_color", color)
	team_label.add_theme_font_size_override("font_size", 15)
	header.add_child(team_label)

	var size_label := Label.new()
	size_label.text = "Jogadores:"
	size_label.add_theme_font_size_override("font_size", 13)
	size_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	header.add_child(size_label)

	var spinbox := SpinBox.new()
	spinbox.min_value = 1
	spinbox.max_value = 3
	spinbox.value = GameConfig.get_team_size(team)
	spinbox.custom_minimum_size.x = 70
	if team == 0:
		_red_spinbox = spinbox
		spinbox.value_changed.connect(_on_red_size_changed)
	else:
		_blue_spinbox = spinbox
		spinbox.value_changed.connect(_on_blue_size_changed)
	header.add_child(spinbox)

	var right_line := HSeparator.new()
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_line.modulate = Color(color, 0.3)
	header.add_child(right_line)

	var rows_container := VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 4)
	section.add_child(rows_container)

	return rows_container


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _rebinding_row:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return
		_toggle()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _rebinding_row:
		return

	var valid_event: InputEvent = null
	if event is InputEventKey and event.pressed:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			return
		valid_event = event
	elif event is InputEventJoypadButton and event.pressed:
		valid_event = event
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		valid_event = event

	if not valid_event:
		return

	GameConfig.robots[_rebinding_row.robot_index].bindings[_rebinding_action] = valid_event
	_rebinding_row.update_bind_label(_rebinding_action)
	_rebinding_row = null
	_rebinding_action = ""
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_red_spinbox.value = GameConfig.get_team_size(0)
		_blue_spinbox.value = GameConfig.get_team_size(1)
		_rebuild_rows()


func _rebuild_rows() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()

	for i in GameConfig.ROBOT_COUNT:
		if not GameConfig.robots[i].enabled:
			continue
		var row := RobotConfigRow.new()
		row.setup(i)
		row.rebind_requested.connect(_on_rebind_requested)
		var container := _red_team_container if i < 3 else _blue_team_container
		container.add_child(row)
		_rows.append(row)


func _on_red_size_changed(value: float) -> void:
	GameConfig.set_team_size(0, int(value))
	_rebuild_rows()


func _on_blue_size_changed(value: float) -> void:
	GameConfig.set_team_size(1, int(value))
	_rebuild_rows()


func _on_rebind_requested(row: RobotConfigRow, action: String) -> void:
	if _rebinding_row:
		_rebinding_row.update_bind_label(_rebinding_action)
	_rebinding_row = row
	_rebinding_action = action
	row.set_bind_waiting(action)


func _cancel_rebind() -> void:
	if _rebinding_row:
		_rebinding_row.update_bind_label(_rebinding_action)
		_rebinding_row = null
		_rebinding_action = ""


func _on_apply() -> void:
	_cancel_rebind()
	GameConfig.apply_input_map()
	GameConfig.save()
	GameConfig.config_changed.emit()
	_toggle()


func _apply_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.45, 0.28)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.55, 0.34)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.14, 0.35, 0.22)
	btn.add_theme_stylebox_override("pressed", pressed)
