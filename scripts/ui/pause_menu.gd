extends CanvasLayer

const RED_COLOR := Color(1.0, 0.4, 0.4)
const BLUE_COLOR := Color(0.4, 0.5, 1.0)
const TEAM_COUNT := 2

var _team_containers: Array[VBoxContainer] = []
var _team_spinboxes: Array[SpinBox] = []
var _rows: Array[RobotConfigRow] = []
var _rebinding_row: RobotConfigRow = null
var _rebinding_action := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false

	_build_background()
	var outer_vbox := _build_panel()
	_build_title(outer_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(scroll_vbox)

	_build_team_section(scroll_vbox, 0, "TIME VERMELHO", RED_COLOR)
	_build_team_section(scroll_vbox, 1, "TIME AZUL", BLUE_COLOR)

	_build_apply_button(outer_vbox)
	_rebuild_rows()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _rebinding_row:
		_cancel_rebind()
	else:
		_toggle()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _rebinding_row:
		return

	var valid_event := _extract_valid_event(event)
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
	if not visible:
		return
	for team in TEAM_COUNT:
		_team_spinboxes[team].value = GameConfig.get_team_size(team)
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
		_team_containers[i / GameConfig.ROBOTS_PER_TEAM].add_child(row)
		_rows.append(row)


func _on_team_size_changed(value: float, team: int) -> void:
	GameConfig.set_team_size(team, int(value))
	_rebuild_rows()


func _on_rebind_requested(row: RobotConfigRow, action: String) -> void:
	if _rebinding_row:
		_rebinding_row.update_bind_label(_rebinding_action)
	_rebinding_row = row
	_rebinding_action = action
	row.set_bind_waiting(action)


func _cancel_rebind() -> void:
	if not _rebinding_row:
		return
	_rebinding_row.update_bind_label(_rebinding_action)
	_rebinding_row = null
	_rebinding_action = ""


func _on_apply() -> void:
	_cancel_rebind()
	GameConfig.apply_input_map()
	GameConfig.save()
	GameConfig.config_changed.emit()
	_toggle()


func _extract_valid_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey and event.pressed:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			return null
		return event
	if event is InputEventJoypadButton and event.pressed:
		return event
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		return event
	return null


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_panel() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1300, 700)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_color = Color(0.2, 0.2, 0.28)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	return vbox


func _build_title(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	parent.add_child(title)


func _build_team_section(parent: VBoxContainer, team: int,
		header_text: String, color: Color) -> void:
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
	spinbox.max_value = GameConfig.ROBOTS_PER_TEAM
	spinbox.value = GameConfig.get_team_size(team)
	spinbox.custom_minimum_size.x = 70
	spinbox.value_changed.connect(_on_team_size_changed.bind(team))
	header.add_child(spinbox)
	_team_spinboxes.append(spinbox)

	var right_line := HSeparator.new()
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_line.modulate = Color(color, 0.3)
	header.add_child(right_line)

	var rows_container := VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 4)
	section.add_child(rows_container)
	_team_containers.append(rows_container)


func _build_apply_button(parent: VBoxContainer) -> void:
	var btn := Button.new()
	btn.text = "APLICAR E VOLTAR"
	btn.custom_minimum_size = Vector2(240, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_apply)

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

	parent.add_child(btn)
