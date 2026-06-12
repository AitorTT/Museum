@tool
class_name RoomSettingsPanel
extends Node

var generator: Node3D
var panel_visible: bool = false
var _canvas: CanvasLayer
var _root: Control
var _bg: ColorRect
var _pos_sb: Array[SpinBox] = []
var _rot_sb: Array[SpinBox] = []
var _scale_sb: Array[SpinBox] = []
var _color_pickers: Dictionary = {}
var _intensity_slider: HSlider
var _intensity_spin: SpinBox
var _cursor: Control
var _saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _CharacterBodyScript


func setup(gen: Node3D) -> void:
	generator = gen
	name = "RoomSettingsPanel"


func toggle() -> void:
	if Engine.is_editor_hint():
		return
	panel_visible = not panel_visible
	if panel_visible:
		if not _CharacterBodyScript:
			_CharacterBodyScript = load("res://SCENES/PLAYER/character_body_3d.gd")
		_CharacterBodyScript.ignore_clicks = true
		if generator.has_method("_highlight_settings"):
			generator._highlight_settings(false)
		_saved_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if not _canvas:
			_build_panel()
		_canvas.visible = true
		_sync_ui()
	elif _canvas:
		if _CharacterBodyScript:
			_CharacterBodyScript.ignore_clicks = false
		if generator.has_method("_highlight_settings"):
			generator._highlight_settings(false)
		_canvas.visible = false
		Input.set_mouse_mode(_saved_mouse_mode)


func is_visible() -> bool:
	return panel_visible and _canvas and _canvas.visible


func get_canvas() -> CanvasLayer:
	return _canvas if is_visible() else null


func update_cursor() -> void:
	if is_visible() and _cursor:
		_cursor.position = get_viewport().get_mouse_position() - _cursor.size * 0.5


func sync_ui() -> void:
	_sync_ui()


func _build_panel() -> void:
	var ui := CanvasLayer.new()
	ui.name = "SettingsPanel"
	ui.layer = 130
	add_child(ui)
	_canvas = ui

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(_root)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_bg)

	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.anchor_left = 0.05
	sc.anchor_right = 0.95
	sc.anchor_top = 0.02
	sc.anchor_bottom = 0.98
	_root.add_child(sc)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	sc.add_child(vb)

	var title := Label.new()
	title.text = "ROOM SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	vb.add_child(title)

	_add_separator(vb)

	_add_label(vb, "TRANSFORM")
	_pos_sb = _add_spin_row(vb, "Position", -100.0, 100.0, 0.1, _on_pos_changed)
	_rot_sb = _add_spin_row(vb, "Rotation", -360.0, 360.0, 1.0, _on_rot_changed)
	_scale_sb = _add_spin_row(vb, "Scale", 0.01, 10.0, 0.1, _on_scale_changed)

	_add_separator(vb)
	_add_label(vb, "COLORS")
	_color_pickers["floor"] = _add_color_row(vb, "Floor")
	_color_pickers["walls"] = _add_color_row(vb, "Walls")
	_color_pickers["ceiling"] = _add_color_row(vb, "Ceiling")

	_add_separator(vb)
	_add_label(vb, "LIGHT")
	_intensity_slider = _add_slider_row(vb, "Intensity", 0.0, 50.0, 0.1, _on_intensity_changed)

	_add_separator(vb)
	_add_label(vb, "DUPLICATE ROOM")
	_add_dup_buttons(vb)

	var cursor := Panel.new()
	cursor.name = "Cursor"
	cursor.size = Vector2(18, 18)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cstyle := StyleBoxFlat.new()
	cstyle.corner_radius_top_left = 9
	cstyle.corner_radius_top_right = 9
	cstyle.corner_radius_bottom_left = 9
	cstyle.corner_radius_bottom_right = 9
	cstyle.bg_color = Color(1, 1, 1, 0.15)
	cstyle.border_color = Color(1, 1, 1, 0.85)
	cstyle.border_width_left = 2
	cstyle.border_width_right = 2
	cstyle.border_width_top = 2
	cstyle.border_width_bottom = 2
	cursor.add_theme_stylebox_override("panel", cstyle)
	cursor.position = _root.get_viewport_rect().size * 0.5 - cursor.size * 0.5
	_root.add_child(cursor)
	_cursor = cursor

	_add_separator(vb)
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.add_theme_font_size_override("font_size", 36)
	close_btn.custom_minimum_size = Vector2(0, 56)
	close_btn.pressed.connect(toggle)
	vb.add_child(close_btn)


func _add_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.custom_minimum_size = Vector2(0, 36)
	parent.add_child(lbl)


func _add_separator(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())


func _add_spin_row(parent: VBoxContainer, label: String, min_v: float, max_v: float, step_v: float, cb: Callable) -> Array[SpinBox]:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.custom_minimum_size = Vector2(120, 40)
	h.add_child(lbl)
	var sbs: Array[SpinBox] = []
	for _i in 3:
		var sb := SpinBox.new()
		sb.min_value = min_v
		sb.max_value = max_v
		sb.step = step_v
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size = Vector2(0, 44)
		sb.add_theme_font_size_override("font_size", 22)
		sb.value_changed.connect(cb)
		h.add_child(sb)
		sbs.append(sb)
	parent.add_child(h)
	return sbs


func _add_color_row(parent: VBoxContainer, label: String) -> ColorPickerButton:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.custom_minimum_size = Vector2(120, 44)
	h.add_child(lbl)
	var cpb := ColorPickerButton.new()
	cpb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cpb.custom_minimum_size = Vector2(0, 44)
	cpb.add_theme_font_size_override("font_size", 22)
	cpb.color_changed.connect(_on_color_changed.bind(label.to_lower()))
	h.add_child(cpb)
	parent.add_child(h)
	return cpb


func _add_slider_row(parent: VBoxContainer, label: String, min_v: float, max_v: float, step_v: float, cb: Callable) -> HSlider:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.custom_minimum_size = Vector2(120, 44)
	h.add_child(lbl)
	var hs := HSlider.new()
	hs.min_value = min_v
	hs.max_value = max_v
	hs.step = step_v
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.custom_minimum_size = Vector2(0, 44)
	hs.value_changed.connect(cb)
	h.add_child(hs)
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step_v
	sb.custom_minimum_size = Vector2(100, 44)
	sb.add_theme_font_size_override("font_size", 22)
	sb.value_changed.connect(cb)
	h.add_child(sb)
	hs.value_changed.connect(sb.set_value.bind())
	sb.value_changed.connect(hs.set_value.bind())
	parent.add_child(h)
	if label == "Intensity":
		_intensity_spin = sb
	return hs


func _add_dup_buttons(parent: VBoxContainer) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	var dirs := [["Front", "front"], ["Back", "back"], ["Left", "left"], ["Right", "right"], ["Up", "up"], ["Down", "down"]]
	for d in dirs:
		var btn := Button.new()
		btn.text = d[0]
		btn.add_theme_font_size_override("font_size", 22)
		btn.custom_minimum_size = Vector2(100, 48)
		btn.pressed.connect(_duplicate_room_dir.bind(d[1]))
		h.add_child(btn)
	parent.add_child(h)


func _sync_ui() -> void:
	var room := _get_room()
	if not room:
		return
	_pos_sb[0].set_value_no_signal(room.position.x)
	_pos_sb[1].set_value_no_signal(room.position.y)
	_pos_sb[2].set_value_no_signal(room.position.z)
	_rot_sb[0].set_value_no_signal(room.rotation_degrees.x)
	_rot_sb[1].set_value_no_signal(room.rotation_degrees.y)
	_rot_sb[2].set_value_no_signal(room.rotation_degrees.z)
	_scale_sb[0].set_value_no_signal(room.scale.x)
	_scale_sb[1].set_value_no_signal(room.scale.y)
	_scale_sb[2].set_value_no_signal(room.scale.z)
	for child in room.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh or mi.mesh.get_surface_count() == 0:
			continue
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if not mat:
			continue
		if child.name == "Floor" and _color_pickers.has("floor"):
			_color_pickers["floor"].set_block_signals(true)
			_color_pickers["floor"].color = mat.albedo_color
			_color_pickers["floor"].set_block_signals(false)
		elif child.name == "Ceiling" and _color_pickers.has("ceiling"):
			_color_pickers["ceiling"].set_block_signals(true)
			_color_pickers["ceiling"].color = mat.albedo_color
			_color_pickers["ceiling"].set_block_signals(false)
		elif child.name.begins_with("Wall_") and _color_pickers.has("walls"):
			_color_pickers["walls"].set_block_signals(true)
			_color_pickers["walls"].color = mat.albedo_color
			_color_pickers["walls"].set_block_signals(false)
	for child in room.get_children():
		if child is Light3D:
			_intensity_slider.set_value_no_signal(child.light_energy)
			if _intensity_spin:
				_intensity_spin.set_value_no_signal(child.light_energy)
			break


func _on_pos_changed(_val: float) -> void:
	var room := _get_room()
	if not room:
		return
	room.position = Vector3(_pos_sb[0].value, _pos_sb[1].value, _pos_sb[2].value)


func _on_rot_changed(_val: float) -> void:
	var room := _get_room()
	if not room:
		return
	room.rotation_degrees = Vector3(_rot_sb[0].value, _rot_sb[1].value, _rot_sb[2].value)


func _on_scale_changed(_val: float) -> void:
	var room := _get_room()
	if not room:
		return
	room.scale = Vector3(_scale_sb[0].value, _scale_sb[1].value, _scale_sb[2].value)


func _on_color_changed(color: Color, section: String) -> void:
	var room := _get_room()
	if not room:
		return
	for child in room.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh or mi.mesh.get_surface_count() == 0:
			continue
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if not mat:
			continue
		match section:
			"floor":
				if child.name == "Floor":
					mat.albedo_color = color
			"walls":
				if child.name.begins_with("Wall_"):
					mat.albedo_color = color
			"ceiling":
				if child.name == "Ceiling":
					mat.albedo_color = color


func _on_intensity_changed(val: float) -> void:
	var room := _get_room()
	if not room:
		return
	for child in room.get_children():
		if child is Light3D:
			child.light_energy = val


func _duplicate_room_dir(dir: String) -> void:
	if generator and generator.has_method("_duplicate_room_dir"):
		generator._duplicate_room_dir(dir)
		sync_ui()


func _get_room() -> Node3D:
	if generator and generator.has_method("_get_room"):
		return generator._get_room()
	return null
