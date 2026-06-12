@tool
extends Node3D
class_name ElevatorGenerator

@export_category("Elevator Dimensions")
@export var elevator_width: float = 2.0
@export var elevator_height: float = 2.5
@export var elevator_depth: float = 2.0
@export var wall_thickness: float = 0.1

@export_category("Materials")
@export var wall_material: Material
@export var floor_material: Material
@export var ceiling_material: Material

@export_category("Movement")
@export var elevator_speed: float = 0.8

@export_category("Doors")
@export var door_width: float = 0.9
@export var door_height: float = 2.0
@export var door_speed: float = 1.0

@export_category("Back Door")
@export var door_back: bool = false

@export_category("Windows")
@export var window_left: bool = false
@export var window_right: bool = false
@export var window_width: float = 0.6
@export var window_height: float = 0.6
@export var window_bottom: float = 1.0

@export_category("Floors")
@export var num_floors: int = 2:
	set(v):
		num_floors = maxi(1, v)
@export var floor_height: float = 3.0

@export_category("Button Panel")
@export var button_material: Material
@export var button_active_color: Color = Color(1, 0.85, 0)
@export var button_inactive_color: Color = Color(0.25, 0.25, 0.25)
@export var button_highlight_color: Color = Color(0, 0.6, 1)

@export_category("Generation")
@export var generate: bool = false:
	set(v):
		if v:
			_generate_elevator()
			generate = false
@export var clear: bool = false:
	set(v):
		if v:
			_clear()
			clear = false


var _cur_floor: int = 0
var _target_floor: int = 0
var _is_moving: bool = false
var _hovered_button: int = -1
var _elevator: Node3D
var _door_left: MeshInstance3D
var _door_right: MeshInstance3D
var _door_back_left: MeshInstance3D
var _door_back_right: MeshInstance3D
var _buttons: Array[MeshInstance3D] = []
var _player_inside: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_setup_runtime()


func _generate_elevator() -> void:
	_clear()
	
	if not wall_material:
		wall_material = StandardMaterial3D.new()
	if not floor_material:
		floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color(0.5, 0.5, 0.5)
	if not ceiling_material:
		ceiling_material = StandardMaterial3D.new()
		ceiling_material.albedo_color = Color(0.8, 0.8, 0.8)

	var car := Node3D.new()
	car.name = "Elevator"
	add_child(car, true)
	_set_owner(car)
	_elevator = car

	var hw: float = float(elevator_width) * 0.5
	var hd: float = float(elevator_depth) * 0.5
	var hh: float = float(elevator_height) * 0.5
	var t: float = float(wall_thickness)
	var fw: float = float(elevator_width) + t * 2.0

	# Walls (door takes priority over window on same face)
	_add_z_wall(car, "Wall_Back",  Vector3(0, 0, -hd + t * 0.5), fw, bool(door_back), false)
	_add_z_wall(car, "Wall_Front", Vector3(0, 0,  hd - t * 0.5), fw, true, false)
	_add_x_wall(car, "Wall_Left",  Vector3(-hw + t * 0.5, 0, 0), float(elevator_depth), false, bool(window_left))
	_add_x_wall(car, "Wall_Right", Vector3( hw - t * 0.5, 0, 0), float(elevator_depth), false, bool(window_right))

	# Floor / ceiling
	_add_segment(car, "Floor",   Vector3(0, -hh + t * 0.5, 0), Vector3(float(elevator_width), t, float(elevator_depth)), floor_material)
	_add_segment(car, "Ceiling", Vector3(0,  hh - t * 0.5, 0), Vector3(float(elevator_width), t, float(elevator_depth)), ceiling_material)

	# Front sliding door
	var dw: float = min(float(door_width), fw - 0.2)
	var dh: float = min(float(door_height), float(elevator_height) - 0.1)
	_add_sliding_door(car, "Front", Vector3(0, 0, hd - t - 0.01), fw, dw, dh, t)

	# Back sliding door
	if bool(door_back):
		_add_sliding_door(car, "Back", Vector3(0, 0, -hd + t + 0.01), fw, dw, dh, t)

	# Button panel
	_add_button_panel(car, hw, hh, t)

	# Player detector
	_add_player_detector(car, hw, hd, hh)


# ---------------------------------------------------------------------------
# Z‑axis wall (face in XY, thickness along Z)
# ---------------------------------------------------------------------------
func _add_z_wall(parent: Node, seg_name: String, pos: Vector3, face_w: float, has_door: bool, has_window: bool) -> void:
	var fh: float = float(elevator_height)
	var t: float = float(wall_thickness)
	var mat: Material = wall_material

	if has_door:
		var dw: float = min(float(door_width), face_w - 0.2)
		var dh: float = min(float(door_height), fh - 0.1)
		var lw: float = (face_w - dw) * 0.5
		var th: float = fh - dh
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x - (face_w - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x + (face_w - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
		if th > 0.01:
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + (fh - th) * 0.5, pos.z), Vector3(dw, th, t), mat)
		return

	if has_window:
		var ww: float = min(float(window_width), face_w - 0.2)
		var wh: float = min(float(window_height), fh - 0.1)
		var wcy: float = -fh * 0.5 + float(window_bottom) + wh * 0.5
		var lw: float = (face_w - ww) * 0.5
		var th: float = fh * 0.5 - (wcy + wh * 0.5)
		var bh: float = (wcy - wh * 0.5) - (-fh * 0.5)
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x - (face_w - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x + (face_w - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
		if th > 0.01:
			var cy: float = (fh * 0.5 + wcy + wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + cy, pos.z), Vector3(ww, th, t), mat)
		if bh > 0.01:
			var cy: float = (-fh * 0.5 + wcy - wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_B", Vector3(pos.x, pos.y + cy, pos.z), Vector3(ww, bh, t), mat)
		return

	_add_segment(parent, seg_name, pos, Vector3(face_w, fh, t), mat)


# ---------------------------------------------------------------------------
# X‑axis wall (face in ZY, thickness along X)
# ---------------------------------------------------------------------------
func _add_x_wall(parent: Node, seg_name: String, pos: Vector3, face_w: float, has_door: bool, has_window: bool) -> void:
	var fh: float = float(elevator_height)
	var t: float = float(wall_thickness)
	var mat: Material = wall_material

	if has_door:
		var dw: float = min(float(door_width), face_w - 0.2)
		var dh: float = min(float(door_height), fh - 0.1)
		var lw: float = (face_w - dw) * 0.5
		var th: float = fh - dh
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x, pos.y, pos.z - (face_w - lw) * 0.5), Vector3(t, fh, lw), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x, pos.y, pos.z + (face_w - lw) * 0.5), Vector3(t, fh, lw), mat)
		if th > 0.01:
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + (fh - th) * 0.5, pos.z), Vector3(t, th, dw), mat)
		return

	if has_window:
		var ww: float = min(float(window_width), face_w - 0.2)
		var wh: float = min(float(window_height), fh - 0.1)
		var wcy: float = -fh * 0.5 + float(window_bottom) + wh * 0.5
		var lw: float = (face_w - ww) * 0.5
		var th: float = fh * 0.5 - (wcy + wh * 0.5)
		var bh: float = (wcy - wh * 0.5) - (-fh * 0.5)
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x, pos.y, pos.z - (face_w - lw) * 0.5), Vector3(t, fh, lw), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x, pos.y, pos.z + (face_w - lw) * 0.5), Vector3(t, fh, lw), mat)
		if th > 0.01:
			var cy: float = (fh * 0.5 + wcy + wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + cy, pos.z), Vector3(t, th, ww), mat)
		if bh > 0.01:
			var cy: float = (-fh * 0.5 + wcy - wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_B", Vector3(pos.x, pos.y + cy, pos.z), Vector3(t, bh, ww), mat)
		return

	_add_segment(parent, seg_name, pos, Vector3(t, fh, face_w), mat)


# ---------------------------------------------------------------------------
# Box segment mesh + collision
# ---------------------------------------------------------------------------
func _add_segment(parent: Node, seg_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = seg_name
	var box := BoxMesh.new()
	box.size = size
	if mat:
		var mat_copy := mat.duplicate() as StandardMaterial3D
		if mat_copy:
			mat_copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material = mat_copy if mat_copy else mat
	else:
		var d := StandardMaterial3D.new()
		d.albedo_color = Color(0.7, 0.7, 0.7)
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material = d
	mi.mesh = box
	mi.position = pos
	parent.add_child(mi, true)
	_set_owner(mi)

	var sb := _get_collision(parent)
	var cs := CollisionShape3D.new()
	cs.name = seg_name + "_col"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	sb.add_child(cs, true)
	_set_owner(cs)


func _get_collision(parent: Node) -> AnimatableBody3D:
	var sb := parent.get_node_or_null("Collision") as AnimatableBody3D
	if not sb:
		sb = AnimatableBody3D.new()
		sb.name = "Collision"
		sb.sync_to_physics = false
		parent.add_child(sb, true)
		_set_owner(sb)
	return sb


# ---------------------------------------------------------------------------
# Sliding door — two halves that part at runtime
# ---------------------------------------------------------------------------
func _add_sliding_door(parent: Node, side: String, pos: Vector3, _face_w: float, dw: float, dh: float, t: float) -> void:
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.35, 0.35, 0.38)
	door_mat.metallic = 0.6
	door_mat.roughness = 0.3

	var half_w: float = dw * 0.5
	var dd: float = t * 0.5
	var sz := Vector3(half_w - 0.01, dh - 0.01, dd)

	var hl := MeshInstance3D.new()
	hl.name = "Door_" + side + "_L"
	var bl := BoxMesh.new()
	bl.size = sz
	bl.material = door_mat
	hl.mesh = bl
	hl.position = Vector3(pos.x - half_w * 0.5 - 0.005, pos.y, pos.z)
	parent.add_child(hl, true)
	_set_owner(hl)
	_add_door_col(parent, hl, sz)

	var hr := MeshInstance3D.new()
	hr.name = "Door_" + side + "_R"
	var br := BoxMesh.new()
	br.size = sz
	br.material = door_mat
	hr.mesh = br
	hr.position = Vector3(pos.x + half_w * 0.5 + 0.005, pos.y, pos.z)
	parent.add_child(hr, true)
	_set_owner(hr)
	_add_door_col(parent, hr, sz)

	if side == "Front":
		_door_left = hl
		_door_right = hr
	else:
		_door_back_left = hl
		_door_back_right = hr


func _add_door_col(parent: Node, door: MeshInstance3D, size: Vector3) -> void:
	var body := AnimatableBody3D.new()
	body.name = door.name + "_col"
	body.sync_to_physics = true
	body.position = door.position
	parent.add_child(body, true)
	_set_owner(body)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs, true)
	_set_owner(cs)


# ---------------------------------------------------------------------------
# Floor button panel
# ---------------------------------------------------------------------------
func _add_button_panel(parent: Node, hw: float, hh: float, t: float) -> void:
	var n: int = int(num_floors)
	if n < 1:
		return

	var panel := Node3D.new()
	panel.name = "ButtonPanel"
	var px: float = hw - t - 0.03
	var py_start: float = -hh * 0.25
	panel.position = Vector3(px, 0, 0)
	panel.rotation.y = PI * 1.5
	parent.add_child(panel, true)
	_set_owner(panel)

	var cols: int = clampi(ceili(n) / 2, 1, 4)
	var rows: int = ceil(float(n) / float(cols))
	var spacing_v: float = min(0.22, (float(elevator_height) * 0.4) / float(rows))
	var spacing_h: float = spacing_v

	var bmat := button_material
	if not bmat:
		bmat = StandardMaterial3D.new()
		bmat.albedo_color = Color(0.2, 0.2, 0.2)
		bmat.emission_enabled = true
		bmat.emission = Color.BLACK

	for i in n:
		var col: int = i % cols
		var row: int = i / cols
		var btn := MeshInstance3D.new()
		btn.name = "Button_" + str(i + 1)
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.12, 0.02)
		btn.mesh = box
		var mat_copy := bmat.duplicate() as StandardMaterial3D
		mat_copy.emission = Color.BLACK
		btn.material_override = mat_copy
		btn.position = Vector3((float(col) - float(cols - 1) * 0.5) * spacing_h, py_start + float(row) * spacing_v, -0.02)
		panel.add_child(btn, true)
		_set_owner(btn)
		_buttons.append(btn)

		# Label3D
		var lbl := Label3D.new()
		lbl.name = "Label"
		lbl.text = str(i + 1)
		lbl.font_size = 36
		lbl.pixel_size = 0.004
		lbl.modulate = Color(1, 1, 1)
		lbl.position = Vector3(0, 0, 0.015)
		btn.add_child(lbl, true)
		_set_owner(lbl)

		# Area3D for click
		var area := Area3D.new()
		area.name = "ClickArea"
		area.collision_layer = 8
		area.set_meta("interact_type", "button")
		area.set_meta("interact_index", i)
		area.input_event.connect(_on_button_input.bind(i))
		btn.add_child(area, true)
		_set_owner(area)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.16, 0.16, 0.06)
		cs.shape = shape
		area.add_child(cs, true)
		_set_owner(cs)


# ---------------------------------------------------------------------------
# Player detector Area3D
# ---------------------------------------------------------------------------
func _add_player_detector(parent: Node, _hw: float, _hd: float, _hh: float) -> void:
	var area := Area3D.new()
	area.name = "PlayerDetector"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(float(elevator_width) * 0.9, float(elevator_height) * 0.8, float(elevator_depth) * 0.9)
	cs.shape = shape
	area.add_child(cs, true)
	_set_owner(cs)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_player_entered)
		area.body_exited.connect(_on_player_exited)
	parent.add_child(area, true)
	_set_owner(area)


# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
func _setup_runtime() -> void:
	_elevator = get_node_or_null("Elevator") as Node3D
	if not _elevator:
		return
	_door_left = _elevator.get_node_or_null("Door_Front_L") as MeshInstance3D
	_door_right = _elevator.get_node_or_null("Door_Front_R") as MeshInstance3D
	_door_back_left = _elevator.get_node_or_null("Door_Back_L") as MeshInstance3D
	_door_back_right = _elevator.get_node_or_null("Door_Back_R") as MeshInstance3D
	_buttons.clear()
	var panel := _elevator.get_node_or_null("ButtonPanel") as Node3D
	if panel:
		for i in int(num_floors):
			var btn := panel.get_node_or_null("Button_" + str(i + 1)) as MeshInstance3D
			if btn:
				_buttons.append(btn)
				var area := btn.get_node_or_null("ClickArea") as Area3D
				if not area:
					area = Area3D.new()
					area.name = "ClickArea"
					btn.add_child(area)
				area.collision_layer = 8
				area.set_meta("interact_type", "button")
				area.set_meta("interact_index", i)
				if area.get_child_count() == 0:
					var cs := CollisionShape3D.new()
					var shape := BoxShape3D.new()
					shape.size = Vector3(0.16, 0.16, 0.06)
					cs.shape = shape
					area.add_child(cs)
	_update_button_colors()
	_open_doors()


func _on_player_entered(_body: Node) -> void:
	_player_inside = true


func _on_player_exited(_body: Node) -> void:
	_player_inside = false


func _on_button_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, floor_idx: int) -> void:
	if not _player_inside:
		return
	if _is_moving:
		return
	if floor_idx == _cur_floor:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_go_to_floor(floor_idx)


func _go_to_floor(target: int) -> void:
	if _is_moving or target == _cur_floor:
		return
	_is_moving = true
	_target_floor = target
	_close_doors()
	await get_tree().create_timer(0.5).timeout
	_move_elevator(target)
	await get_tree().create_timer(1.0).timeout
	_open_doors()
	_cur_floor = target
	_is_moving = false
	_update_button_colors()


func _move_elevator(target: int) -> void:
	if not _elevator:
		return
	var target_y: float = float(target) * float(floor_height)
	var tween := create_tween()
	tween.tween_property(_elevator, "position:y", target_y, float(elevator_speed)).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _close_doors() -> void:
	var hw: float = float(door_width) * 0.5
	var dur: float = 1.0 / maxf(float(door_speed), 0.01)
	_animate_door(_door_left, _door_right, hw, -hw, dur)
	if _door_back_left and _door_back_right:
		_animate_door(_door_back_left, _door_back_right, hw, -hw, dur)


func _open_doors() -> void:
	var hw: float = float(door_width) * 0.5
	var dur: float = 1.0 / maxf(float(door_speed), 0.01)
	_animate_door(_door_left, _door_right, -hw, hw, dur)
	if _door_back_left and _door_back_right:
		_animate_door(_door_back_left, _door_back_right, -hw, hw, dur)


func _animate_door(left: MeshInstance3D, right: MeshInstance3D, left_target_x: float, right_target_x: float, duration: float = 0.3) -> void:
	if not left or not right:
		return
	var parent_node := left.get_parent()
	var left_col := parent_node.get_node_or_null(left.name + "_col") as AnimatableBody3D
	var right_col := parent_node.get_node_or_null(right.name + "_col") as AnimatableBody3D
	var base_l := left.position.x
	var base_r := right.position.x
	var tween := create_tween().set_parallel(true)
	tween.tween_property(left, "position:x", base_l + left_target_x, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(right, "position:x", base_r + right_target_x, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if left_col:
		tween.tween_property(left_col, "position:x", base_l + left_target_x, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if right_col:
		tween.tween_property(right_col, "position:x", base_r + right_target_x, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _animate_door_back(left_target_x: float, right_target_x: float, duration: float = 0.3) -> void:
	_animate_door(_door_back_left, _door_back_right, left_target_x, right_target_x, duration)


func press_button(index: int) -> void:
	if _is_moving or index == _cur_floor:
		return
	_go_to_floor(index)

func hover_button(index: int) -> void:
	_hovered_button = index
	_update_button_colors()

func unhover_button() -> void:
	_hovered_button = -1
	_update_button_colors()

func _update_button_colors() -> void:
	for i in _buttons.size():
		var btn := _buttons[i] as MeshInstance3D
		if not btn:
			continue
		var mat := btn.material_override as StandardMaterial3D
		if not mat:
			continue
		if i == _hovered_button and i != _cur_floor:
			mat.emission = button_highlight_color
			mat.emission_energy = 1.0
		elif i == _cur_floor:
			mat.emission = button_active_color
			mat.emission_energy = 1.0
		else:
			mat.emission = Color.BLACK
			mat.emission_energy = 0.0


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
func _clear() -> void:
	for child in get_children():
		if child is Node3D and child.name == "Elevator":
			child.free()
	_buttons.clear()
	_door_left = null
	_door_right = null
	_door_back_left = null
	_door_back_right = null


func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root and (root == node or root.is_ancestor_of(node)):
			node.owner = root
			return
	node.owner = self
