@tool
class_name PaintingTransformPanel
extends Node

var generator: Node3D
var painting_mount: Node3D

var _gizmo_root: Node3D
var _dragging: String = ""
var _drag_initial_pos: Vector3
var _drag_plane: Plane
var _drag_plane_origin: Vector3
var _hovered_axis: String = ""
var _canvas: CanvasLayer
var _ui_panel: Panel
var _tex_grid_canvas: CanvasLayer
var _is_visible: bool = false
var _character_body_script
var _saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _arrow_nodes: Dictionary = {}
var _known_textures: Array[Texture2D] = []
var _original_position: Vector3
var _original_rotation: Vector3
var _original_scale: Vector3

const ARROW_LEN: float = 0.9
const SHAFT_R: float = 0.02
const HEAD_R: float = 0.08
const HEAD_LEN: float = 0.2
const GIZMO_OFFSET: float = 0.25
const MOVE_STEP: float = 0.25
const ROTATE_DEG: float = 15.0
const SCALE_STEP: float = 0.1


func setup(gen: Node3D) -> void:
	generator = gen
	name = "PaintingTransformPanel"


func show_panel(mount: Node3D) -> void:
	painting_mount = mount
	_original_position = mount.position
	_original_rotation = mount.rotation
	_original_scale = mount.scale
	if not _character_body_script:
		_character_body_script = load("res://SCENES/PLAYER/character_body_3d.gd")
	_character_body_script.ignore_clicks = true
	_saved_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_is_visible = true
	_hovered_axis = ""
	_create_gizmo()
	_create_ui()


func hide_panel() -> void:
	_is_visible = false
	_dragging = ""
	_hovered_axis = ""
	_hide_texture_grid()
	_free_gizmo()
	_free_ui()
	if _character_body_script:
		_character_body_script.ignore_clicks = false
	Input.set_mouse_mode(_saved_mouse_mode)


func is_visible() -> bool:
	return _is_visible


func update_cursor() -> void:
	pass


func _free_gizmo() -> void:
	if _gizmo_root:
		_gizmo_root.queue_free()
		_gizmo_root = null
	_arrow_nodes.clear()


func _free_ui() -> void:
	if _canvas:
		_canvas.queue_free()
		_canvas = null
	_ui_panel = null


func _create_gizmo() -> void:
	_free_gizmo()
	if not painting_mount:
		return
	_gizmo_root = Node3D.new()
	_gizmo_root.name = "TransformGizmo"
	generator.add_child(_gizmo_root)
	var gizmo_offset := -painting_mount.global_transform.basis.z * GIZMO_OFFSET
	_gizmo_root.global_position = painting_mount.global_position + gizmo_offset
	for cfg in [{"ax": "x", "color": Color(1, 0.2, 0.2), "rot": Vector3(0, 0, -90)},
				{"ax": "y", "color": Color(0.2, 1, 0.2), "rot": Vector3(0, 0, 0)},
				{"ax": "z", "color": Color(0.2, 0.2, 1), "rot": Vector3(90, 0, 0)}]:
		_create_arrow(cfg.ax, cfg.color, cfg.rot)


func _create_arrow(axis: String, color: Color, rot: Vector3) -> void:
	var arrow := Node3D.new()
	arrow.name = "Arrow_" + axis
	_gizmo_root.add_child(arrow)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	mat.no_depth_test = true

	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = SHAFT_R
	cyl.bottom_radius = SHAFT_R
	cyl.height = ARROW_LEN - HEAD_LEN
	cyl.material = mat
	shaft.mesh = cyl
	shaft.position.y = (ARROW_LEN - HEAD_LEN) * 0.5
	arrow.add_child(shaft)

	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = HEAD_R
	cone.height = HEAD_LEN
	cone.material = mat
	head.mesh = cone
	head.position.y = ARROW_LEN - HEAD_LEN * 0.5
	arrow.add_child(head)

	arrow.rotation_degrees = rot
	_arrow_nodes[axis] = arrow


func _make_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	return lbl


func _make_transform_btn(text: String, action: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_stylebox_override("normal", _make_btn_style(
		Color(0.15, 0.15, 0.2, 0.9), Color(0.3, 0.5, 0.8, 0.6)))
	btn.add_theme_stylebox_override("hover", _make_btn_style(
		Color(0.25, 0.25, 0.35, 0.9), Color(0.4, 0.7, 1.0, 0.8)))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(
		Color(0.35, 0.35, 0.5, 0.9), Color(0.5, 0.8, 1.0, 1.0)))
	btn.pressed.connect(_on_action.bind(action))
	return btn


func _create_ui() -> void:
	_free_ui()
	_canvas = CanvasLayer.new()
	_canvas.name = "GizmoUI"
	_canvas.layer = 132
	generator.add_child(_canvas)

	_ui_panel = Panel.new()
	_ui_panel.anchor_left = 0.6
	_ui_panel.anchor_right = 1.0
	_ui_panel.anchor_top = 0.0
	_ui_panel.anchor_bottom = 1.0
	var pnl_style := StyleBoxFlat.new()
	pnl_style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	pnl_style.border_color = Color(0.2, 0.3, 0.5, 0.5)
	pnl_style.border_width_left = 1
	_ui_panel.add_theme_stylebox_override("panel", pnl_style)
	_canvas.add_child(_ui_panel)

	var margin := MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_right = 1.0
	margin.anchor_top = 0.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_ui_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	vbox.add_child(_make_section_label("— MOVE —"))

	var hb1 := HBoxContainer.new()
	hb1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb1.add_child(_make_transform_btn("Left", "move_left"))
	hb1.add_child(_make_transform_btn("Right", "move_right"))
	vbox.add_child(hb1)

	var hb2 := HBoxContainer.new()
	hb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb2.add_child(_make_transform_btn("Up", "move_up"))
	hb2.add_child(_make_transform_btn("Down", "move_down"))
	vbox.add_child(hb2)

	var hb3 := HBoxContainer.new()
	hb3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb3.add_child(_make_transform_btn("Front", "move_front"))
	hb3.add_child(_make_transform_btn("Back", "move_back"))
	vbox.add_child(hb3)

	vbox.add_child(_make_section_label("— ROTATE —"))

	var hb4 := HBoxContainer.new()
	hb4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb4.add_child(_make_transform_btn("Rot X", "rot_x"))
	hb4.add_child(_make_transform_btn("Rot Y", "rot_y"))
	vbox.add_child(hb4)

	var hb5 := HBoxContainer.new()
	hb5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb5.add_child(_make_transform_btn("Rot Z", "rot_z"))
	vbox.add_child(hb5)

	vbox.add_child(_make_section_label("— SCALE —"))

	var hb6 := HBoxContainer.new()
	hb6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb6.add_child(_make_transform_btn("Scale +", "scale_up"))
	hb6.add_child(_make_transform_btn("Scale −", "scale_down"))
	vbox.add_child(hb6)

	vbox.add_child(_make_section_label("— TEXTURE —"))

	var hb7 := HBoxContainer.new()
	hb7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb7.add_child(_make_transform_btn("Change", "change_tex"))
	vbox.add_child(hb7)

	vbox.add_child(_make_section_label("— RESET —"))

	var hb8 := HBoxContainer.new()
	hb8.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb8.add_child(_make_transform_btn("Reset", "reset"))
	vbox.add_child(hb8)

	vbox.add_spacer(true)

	var hb_done := HBoxContainer.new()
	hb_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_done.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_done.add_theme_constant_override("separation", 12)
	vbox.add_child(hb_done)

	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.custom_minimum_size = Vector2(0, 80)
	save_btn.add_theme_font_size_override("font_size", 26)
	var save_sb := StyleBoxFlat.new()
	save_sb.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	save_sb.border_color = Color(0.2, 0.9, 0.2, 0.9)
	save_sb.border_width_left = 2
	save_sb.border_width_right = 2
	save_sb.border_width_top = 2
	save_sb.border_width_bottom = 2
	save_sb.corner_radius_top_left = 8
	save_sb.corner_radius_top_right = 8
	save_sb.corner_radius_bottom_left = 8
	save_sb.corner_radius_bottom_right = 8
	save_btn.add_theme_stylebox_override("normal", save_sb)
	save_btn.pressed.connect(_save_transform)
	hb_done.add_child(save_btn)

	var done_btn := Button.new()
	done_btn.text = "DONE"
	done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_btn.custom_minimum_size = Vector2(0, 80)
	done_btn.add_theme_font_size_override("font_size", 26)
	var done_sb := StyleBoxFlat.new()
	done_sb.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	done_sb.border_color = Color(0.3, 0.7, 1.0, 0.9)
	done_sb.border_width_left = 2
	done_sb.border_width_right = 2
	done_sb.border_width_top = 2
	done_sb.border_width_bottom = 2
	done_sb.corner_radius_top_left = 8
	done_sb.corner_radius_top_right = 8
	done_sb.corner_radius_bottom_left = 8
	done_sb.corner_radius_bottom_right = 8
	done_btn.add_theme_stylebox_override("normal", done_sb)
	done_btn.pressed.connect(hide_panel)
	hb_done.add_child(done_btn)


func _on_action(action: String) -> void:
	if not painting_mount:
		return
	match action:
		"move_left":
			_move_relative(-1)
		"move_right":
			_move_relative(1)
		"move_up":
			painting_mount.position.y += MOVE_STEP
		"move_down":
			painting_mount.position.y -= MOVE_STEP
		"move_front":
			painting_mount.position.z -= MOVE_STEP
		"move_back":
			painting_mount.position.z += MOVE_STEP
		"rot_x":
			painting_mount.rotate_object_local(Vector3.RIGHT, deg_to_rad(ROTATE_DEG))
		"rot_y":
			painting_mount.rotate_object_local(Vector3.UP, deg_to_rad(ROTATE_DEG))
		"rot_z":
			painting_mount.rotate_object_local(Vector3.FORWARD, deg_to_rad(ROTATE_DEG))
		"scale_up":
			var s := painting_mount.scale + Vector3.ONE * SCALE_STEP
			painting_mount.scale = s
		"scale_down":
			var s := painting_mount.scale - Vector3.ONE * SCALE_STEP
			painting_mount.scale = s.max(Vector3.ONE * 0.1)
		"change_tex":
			_show_texture_grid()
		"reset":
			painting_mount.position = _original_position
			painting_mount.rotation = _original_rotation
			painting_mount.scale = _original_scale


func _show_texture_grid() -> void:
	_hide_texture_grid()
	var textures: Array[Texture2D] = []
	textures.append_array(_known_textures)
	for entry in generator._paintings:
		var tex := entry.get("texture") as Texture2D
		if tex and tex not in textures:
			textures.append(tex)
	if textures.is_empty():
		return

	_tex_grid_canvas = CanvasLayer.new()
	_tex_grid_canvas.name = "TextureGrid"
	_tex_grid_canvas.layer = 133
	generator.add_child(_tex_grid_canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.anchor_left = 0.0
	bg.anchor_right = 1.0
	bg.anchor_top = 0.0
	bg.anchor_bottom = 1.0
	_tex_grid_canvas.add_child(bg)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.anchor_left = 0.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_top = 8
	close_btn.offset_bottom = 56
	close_btn.offset_left = 12
	close_btn.offset_right = -12
	close_btn.add_theme_font_size_override("font_size", 20)
	_tex_grid_canvas.add_child(close_btn)
	close_btn.pressed.connect(_hide_texture_grid)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 64
	_tex_grid_canvas.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for tex in textures:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(0, 100)
		cell.icon = tex
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.expand_icon = true
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.pressed.connect(_on_texture_selected.bind(tex))
		grid.add_child(cell)


func _on_texture_selected(tex: Texture2D) -> void:
	_apply_texture(tex)
	call_deferred("_hide_texture_grid")


func _apply_texture(tex: Texture2D) -> void:
	if not painting_mount:
		return
	var target_mount: Node3D = null
	for entry in generator._paintings:
		var entry_tex: Texture2D = entry.get("texture")
		if entry_tex == tex:
			target_mount = entry.get("mount")
			break
	if not target_mount or target_mount == painting_mount:
		return
	var tmp_pos := painting_mount.global_position
	var tmp_rot := painting_mount.global_rotation
	var tmp_scale := painting_mount.scale
	painting_mount.global_position = target_mount.global_position
	painting_mount.global_rotation = target_mount.global_rotation
	painting_mount.scale = target_mount.scale
	target_mount.global_position = tmp_pos
	target_mount.global_rotation = tmp_rot
	target_mount.scale = tmp_scale
	_save_transform_for(painting_mount)
	_save_transform_for(target_mount)


func _save_transform_for(mount: Node3D) -> void:
	if not mount:
		return
	var url := str(generator.transforms_sheets_url) if "transforms_sheets_url" in generator else ""
	if url.is_empty():
		return
	var idx := -1
	for i in range(generator._paintings.size()):
		if generator._paintings[i].get("mount") == mount:
			idx = i
			break
	var data := JSON.stringify({
		"index": idx,
		"painting": mount.name,
		"position": {"x": mount.global_position.x, "y": mount.global_position.y, "z": mount.global_position.z},
		"rotation": {"x": mount.global_rotation.x, "y": mount.global_rotation.y, "z": mount.global_rotation.z},
		"scale": {"x": mount.scale.x, "y": mount.scale.y, "z": mount.scale.z},
	})
	var headers := PackedStringArray(["Content-Type: text/plain;charset=utf-8"])
	var http := HTTPRequest.new()
	http.name = "TransformSaveHTTP"
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(url, headers, HTTPClient.METHOD_POST, data)


func _save_transform() -> void:
	_save_transform_for(painting_mount)


func _hide_texture_grid() -> void:
	if _tex_grid_canvas:
		_tex_grid_canvas.queue_free()
		_tex_grid_canvas = null


func _highlight_arrow(axis: String, hovered: bool) -> void:
	if not _gizmo_root:
		return
	var arrow := _arrow_nodes.get(axis) as Node3D
	if not arrow:
		return
	var mul: float = 1.3 if hovered else 1.0
	arrow.scale = Vector3(mul, mul, mul)


func _move_relative(sign_dir: int) -> void:
	var cam := _get_camera()
	if not cam:
		return
	var cam_right := cam.global_transform.basis.x
	cam_right.y = 0.0
	var len_sq := cam_right.length_squared()
	if len_sq < 0.001:
		return
	cam_right /= sqrt(len_sq)
	var painting_x := painting_mount.global_transform.basis.x
	painting_x.y = 0.0
	len_sq = painting_x.length_squared()
	if len_sq < 0.001:
		return
	painting_x /= sqrt(len_sq)
	var dot := cam_right.dot(painting_x)
	var s: float = 1.0 if (dot >= 0.0) == (sign_dir > 0) else -1.0
	painting_mount.global_position += painting_x * s * MOVE_STEP


func _start_drag(axis: String) -> void:
	_dragging = axis
	_highlight_arrow(axis, true)
	_drag_initial_pos = painting_mount.position
	var cam := _get_camera()
	if not cam:
		_dragging = ""
		return
	var plane_normal := -cam.global_transform.basis.z
	_drag_plane = Plane(plane_normal, painting_mount.global_position)
	var mouse_pos := _get_mouse_pos()
	if mouse_pos == null:
		_dragging = ""
		return
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var intersect = _drag_plane.intersects_ray(origin, dir)
	if intersect == null:
		_dragging = ""
		return
	_drag_plane_origin = intersect


func _end_drag() -> void:
	var prev_axis := _dragging
	_dragging = ""
	if not prev_axis.is_empty():
		_highlight_arrow(prev_axis, false)


func _pick_arrow(cam: Camera3D, mouse_pos: Vector2) -> String:
	var closest: String = ""
	var closest_dist: float = 40.0
	for axis in _arrow_nodes:
		var arrow := _arrow_nodes[axis] as Node3D
		var tip_pos := arrow.global_position + arrow.global_transform.basis.y * ARROW_LEN
		var screen_pos := cam.unproject_position(tip_pos)
		var dist := screen_pos.distance_to(mouse_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = axis
	return closest if closest_dist <= 40.0 else ""


func _get_axis_dir(axis: String) -> Vector3:
	var arrow := _arrow_nodes.get(axis) as Node3D
	if not arrow:
		return Vector3.ZERO
	return arrow.global_transform.basis.y.normalized()


func _input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = (event as InputEventMouseMotion).global_position
		if not _dragging.is_empty():
			_update_drag(mouse_pos)
		else:
			var cam := _get_camera()
			if cam:
				var picked := _pick_arrow(cam, mouse_pos)
				if picked != _hovered_axis:
					if not _hovered_axis.is_empty():
						_highlight_arrow(_hovered_axis, false)
					_hovered_axis = picked
					if not picked.is_empty():
						_highlight_arrow(picked, true)
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not _dragging.is_empty():
				return
			var cam := _get_camera()
			if cam:
				var picked := _pick_arrow(cam, event.global_position)
				if not picked.is_empty():
					_start_drag(picked)
				elif _tex_grid_canvas:
					pass
				elif _ui_panel and _ui_panel.get_global_rect().has_point(event.position):
					pass
				else:
					hide_panel()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not _dragging.is_empty():
				_end_drag()


func _process(_delta: float) -> void:
	if not _is_visible:
		return
	if not painting_mount:
		hide_panel()
		return
	if _gizmo_root:
		var gizmo_offset := -painting_mount.global_transform.basis.z * GIZMO_OFFSET
		_gizmo_root.global_position = painting_mount.global_position + gizmo_offset


func _update_drag(mouse_pos: Vector2) -> void:
	var cam := _get_camera()
	if not cam:
		return
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var intersect = _drag_plane.intersects_ray(origin, dir)
	if intersect == null:
		return
	var global_delta: Vector3 = intersect - _drag_plane_origin
	var axis_dir := _get_axis_dir(_dragging)
	var projection := global_delta.dot(axis_dir)
	match _dragging:
		"x":
			painting_mount.position.x = _drag_initial_pos.x + projection
		"y":
			painting_mount.position.y = _drag_initial_pos.y + projection
		"z":
			painting_mount.position.z = _drag_initial_pos.z + projection


func _get_camera() -> Camera3D:
	var player := generator.get_node_or_null("PLAYER") as Node3D
	if not player:
		return null
	return player.get_node_or_null("CameraArm/Camera3D") as Camera3D


func _get_mouse_pos() -> Vector2:
	var vp := get_viewport()
	if not vp:
		return Vector2.ZERO
	return vp.get_mouse_position()
