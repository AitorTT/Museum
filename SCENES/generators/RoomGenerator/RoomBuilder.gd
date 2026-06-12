@tool
extends Node

var generator: Node3D


func setup(gen: Node3D) -> void:
	generator = gen
	name = "RoomBuilder"


func generate() -> void:
	clear()
	var room := Node3D.new()
	room.name = "Room"
	generator.add_child(room, true)
	_set_owner(room)
	_build_room_contents(room)
	room.owner = generator.get_tree().edited_scene_root


func duplicate_room(offset: Vector3) -> Node3D:
	var count := 0
	for child in generator.get_children():
		if child is Node3D and child.name.begins_with("Room"):
			count += 1
	var room := Node3D.new()
	room.name = "Room_%d" % count
	room.position = offset
	generator.add_child(room, true)
	_set_owner(room)
	_build_room_contents(room)
	if generator.get_tree():
		room.owner = generator.get_tree().edited_scene_root
	return room


func clear() -> void:
	generator._paintings.clear()
	for child in generator.get_children():
		if child is Node3D and child.name == "Room":
			child.free()


func get_room() -> Node3D:
	for child in generator.get_children():
		if child is Node3D and child.name == "Room":
			return child
	return null


static func _make_lightmapped(prim: PrimitiveMesh) -> ArrayMesh:
	var arrays := prim.get_mesh_arrays()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.lightmap_unwrap(Transform3D.IDENTITY, 0.05)
	var mat := prim.material
	if mat:
		am.surface_set_material(0, mat)
	return am


static func rebuild_painting(mount: Node3D, tex: Texture2D, scale_factor: float = 1.0) -> StandardMaterial3D:
	var aspect := 1.0
	if tex:
		var tw := tex.get_width()
		var th := tex.get_height()
		if th > 0:
			aspect = float(tw) / float(th)

	# Remove old Canvas and Frame
	for child in mount.get_children():
		if child is MeshInstance3D and (child.name == "Canvas" or child.name == "Frame"):
			mount.remove_child(child)
			child.queue_free()

	var fp: float = 0.05
	var fd: float = 0.08
	var s: float = scale_factor
	var fw_val := aspect + fp * 2.0
	var fh_val := 1.0 + fp * 2.0

	# Recreate Frame
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.2, 0.2, 0.2)
	frame_mat.emission_enabled = true
	frame_mat.emission = Color.BLACK

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := [
		{"p": Vector3(0, fh_val * 0.5 - fp * 0.5, 0) * s, "sz": Vector3(fw_val * s, fp * s, fd * s)},
		{"p": Vector3(0, -(fh_val * 0.5 - fp * 0.5), 0) * s, "sz": Vector3(fw_val * s, fp * s, fd * s)},
		{"p": Vector3(-(fw_val * 0.5 - fp * 0.5), 0, 0) * s, "sz": Vector3(fp * s, fh_val * s, fd * s)},
		{"p": Vector3(fw_val * 0.5 - fp * 0.5, 0, 0) * s, "sz": Vector3(fp * s, fh_val * s, fd * s)},
	]
	for seg in segs:
		var box := BoxMesh.new()
		box.size = seg.sz
		st.append_from(box, 0, Transform3D.IDENTITY.translated(seg.p))
	st.generate_normals()
	var frame_am := ArrayMesh.new()
	st.commit(frame_am)
	frame_am.lightmap_unwrap(Transform3D.IDENTITY, 0.05)
	frame_am.surface_set_material(0, frame_mat)
	var frame_mi := MeshInstance3D.new()
	frame_mi.name = "Frame"
	frame_mi.mesh = frame_am
	mount.add_child(frame_mi, true)

	# Recreate Canvas
	var canvas_mat := StandardMaterial3D.new()
	if tex:
		canvas_mat.albedo_texture = tex
	canvas_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canvas_mat.uv1_scale = Vector3(1, -1, 1)
	canvas_mat.uv1_offset = Vector3(0, 1, 0)

	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var plane := PlaneMesh.new()
	plane.size = Vector2(aspect * s, 1.0 * s)
	plane.material = canvas_mat
	canvas.mesh = _make_lightmapped(plane)
	canvas.rotation_degrees.x = -90
	canvas.scale.x = -1
	canvas.position = Vector3(0, 0, -0.0625 * s)
	mount.add_child(canvas, true)

	# Update ClickArea collision shape and meta
	for child in mount.get_children():
		if child is Area3D and child.name == "ClickArea":
			for c in child.get_children():
				if c is CollisionShape3D:
					var box := c.shape as BoxShape3D
					if box:
						box.size = Vector3(fw_val * s, fh_val * s, fd * s + 0.05)
			child.set_meta("painting_frame_mat", frame_mat)
			child.set_meta("painting_tex", tex)
			child.set_meta("painting_name", tex.resource_path.get_file() if tex else "")
			break

	return frame_mat


func _build_room_contents(room: Node3D) -> void:
	var hw: float = float(generator.width) * 0.5
	var hd: float = float(generator.depth) * 0.5
	var hh: float = float(generator.height) * 0.5
	var t: float = float(generator.wall_thickness)

	_add_z_wall(room, "Wall_Back",  Vector3(0, 0, -hd + t * 0.5), float(generator.width) + t * 2, bool(generator.door_z_neg), bool(generator.window_z_neg))
	_add_z_wall(room, "Wall_Front", Vector3(0, 0,  hd - t * 0.5), float(generator.width) + t * 2, bool(generator.door_z_pos), bool(generator.window_z_pos))

	_add_x_wall(room, "Wall_Left",  Vector3(-hw + t * 0.5, 0, 0), float(generator.depth), bool(generator.door_x_neg), bool(generator.window_x_neg))
	_add_x_wall(room, "Wall_Right", Vector3( hw - t * 0.5, 0, 0), float(generator.depth), bool(generator.door_x_pos), bool(generator.window_x_pos))

	_add_segment(room, "Floor",   Vector3(0, -hh + t * 0.5, 0),  Vector3(float(generator.width), t, float(generator.depth)), generator.floor_material)
	_add_segment(room, "Ceiling", Vector3(0,  hh - t * 0.5, 0),  Vector3(float(generator.width), t, float(generator.depth)), generator.ceiling_material)

	_add_room_features(room)
	_add_settings_button(room)


func _add_z_wall(parent: Node, seg_name: String, pos: Vector3, face_w: float, has_door: bool, has_window: bool) -> void:
	var fw: float = face_w
	var fh: float = float(generator.height)
	var t: float = float(generator.wall_thickness)
	var mat: Material = generator.wall_material

	if has_door:
		var dw: float = min(float(generator.door_width), fw - 0.2)
		var dh: float = min(float(generator.door_height), fh - 0.1)
		var lw: float = (fw - dw) * 0.5
		var th: float = fh - dh
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x - (fw - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x + (fw - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
		if th > 0.01:
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + (fh - th) * 0.5, pos.z), Vector3(dw, th, t), mat)
		_add_door_filler(parent, seg_name + "_DoorFiller", Vector3(pos.x, -fh * 0.5 + dh * 0.5, pos.z), Vector3(dw, dh, t), mat)
		return

	if has_window:
		var ww: float = min(float(generator.window_width), fw - 0.2)
		var wh: float = min(float(generator.window_height), fh - 0.1)
		var wcy: float = -fh * 0.5 + float(generator.window_bottom) + wh * 0.5
		var lw: float = (fw - ww) * 0.5
		var th: float = fh * 0.5 - (wcy + wh * 0.5)
		var bh: float = (wcy - wh * 0.5) - (-fh * 0.5)
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x - (fw - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x + (fw - lw) * 0.5, pos.y, pos.z), Vector3(lw, fh, t), mat)
		if th > 0.01:
			var cy: float = (fh * 0.5 + wcy + wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + cy, pos.z), Vector3(ww, th, t), mat)
		if bh > 0.01:
			var cy: float = (-fh * 0.5 + wcy - wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_B", Vector3(pos.x, pos.y + cy, pos.z), Vector3(ww, bh, t), mat)
		return

	_add_segment(parent, seg_name, pos, Vector3(fw, fh, t), mat)


func _add_x_wall(parent: Node, seg_name: String, pos: Vector3, face_w: float, has_door: bool, has_window: bool) -> void:
	var fw: float = face_w
	var fh: float = float(generator.height)
	var t: float = float(generator.wall_thickness)
	var mat: Material = generator.wall_material

	if has_door:
		var dw: float = min(float(generator.door_width), fw - 0.2)
		var dh: float = min(float(generator.door_height), fh - 0.1)
		var lw: float = (fw - dw) * 0.5
		var th: float = fh - dh
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x, pos.y, pos.z - (fw - lw) * 0.5), Vector3(t, fh, lw), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x, pos.y, pos.z + (fw - lw) * 0.5), Vector3(t, fh, lw), mat)
		if th > 0.01:
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + (fh - th) * 0.5, pos.z), Vector3(t, th, dw), mat)
		_add_door_filler(parent, seg_name + "_DoorFiller", Vector3(pos.x, -fh * 0.5 + dh * 0.5, pos.z), Vector3(t, dh, dw), mat)
		return

	if has_window:
		var ww: float = min(float(generator.window_width), fw - 0.2)
		var wh: float = min(float(generator.window_height), fh - 0.1)
		var wcy: float = -fh * 0.5 + float(generator.window_bottom) + wh * 0.5
		var lw: float = (fw - ww) * 0.5
		var th: float = fh * 0.5 - (wcy + wh * 0.5)
		var bh: float = (wcy - wh * 0.5) - (-fh * 0.5)
		if lw > 0.01:
			_add_segment(parent, seg_name + "_L", Vector3(pos.x, pos.y, pos.z - (fw - lw) * 0.5), Vector3(t, fh, lw), mat)
			_add_segment(parent, seg_name + "_R", Vector3(pos.x, pos.y, pos.z + (fw - lw) * 0.5), Vector3(t, fh, lw), mat)
		if th > 0.01:
			var cy: float = (fh * 0.5 + wcy + wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_T", Vector3(pos.x, pos.y + cy, pos.z), Vector3(t, th, ww), mat)
		if bh > 0.01:
			var cy: float = (-fh * 0.5 + wcy - wh * 0.5) * 0.5
			_add_segment(parent, seg_name + "_B", Vector3(pos.x, pos.y + cy, pos.z), Vector3(t, bh, ww), mat)
		return

	_add_segment(parent, seg_name, pos, Vector3(t, fh, fw), mat)


func _add_segment(parent: Node, seg_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = seg_name
	var box := BoxMesh.new()
	box.size = size
	if mat:
		box.material = mat
	else:
		var default_mat := StandardMaterial3D.new()
		default_mat.albedo_color = Color(0.8, 0.8, 0.8)
		default_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material = default_mat
	mi.mesh = _make_lightmapped(box)
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


func _add_door_filler(parent: Node, seg_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = seg_name
	mi.visible = false
	var box := BoxMesh.new()
	box.size = size
	if mat:
		box.material = mat
	else:
		var default_mat := StandardMaterial3D.new()
		default_mat.albedo_color = Color(0.8, 0.8, 0.8)
		default_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box.material = default_mat
	mi.mesh = _make_lightmapped(box)
	mi.position = pos
	parent.add_child(mi, true)
	_set_owner(mi)

	var sb := _get_collision(parent)
	var cs := CollisionShape3D.new()
	cs.name = seg_name + "_col"
	cs.disabled = true
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	sb.add_child(cs, true)
	_set_owner(cs)


func _get_collision(parent: Node) -> StaticBody3D:
	var sb := parent.get_node_or_null("Collision") as StaticBody3D
	if not sb:
		sb = StaticBody3D.new()
		sb.name = "Collision"
		parent.add_child(sb, true)
		_set_owner(sb)
	return sb


func _add_room_features(room: Node) -> void:
	var hw: float = float(generator.width) * 0.5
	var hd: float = float(generator.depth) * 0.5
	var hh: float = float(generator.height) * 0.5
	var t: float = float(generator.wall_thickness)
	var py: float = -hh + float(generator.painting_height)
	var le: float = float(generator.light_energy)
	var lr: float = float(generator.light_range)
	var lc: Color = generator.light_color
	var ps: float = float(generator.painting_scale)

	var faces := [
		["X_Pos",  Vector3( hw - t - 0.02, py, 0), Vector3(0, 90, 0), generator.painting_x_pos_texture, bool(generator.light_x_pos)],
		["X_Neg",  Vector3(-hw + t + 0.02, py, 0), Vector3(0, -90, 0), generator.painting_x_neg_texture, bool(generator.light_x_neg)],
		["Z_Pos",  Vector3(0, py,  hd - t - 0.02), Vector3(0, 0, 0), generator.painting_z_pos_texture, bool(generator.light_z_pos)],
		["Z_Neg",  Vector3(0, py, -hd + t - 0.02), Vector3(0, 180, 0), generator.painting_z_neg_texture, bool(generator.light_z_neg)],
	]

	for f in faces:
		var pos := f[1] as Vector3
		var oh := float(generator.painting_offset_h)
		var ov := float(generator.painting_offset_v)
		match f[0]:
			"X_Pos", "X_Neg":
				pos = Vector3(pos.x, pos.y + ov, pos.z + oh)
			"Z_Pos", "Z_Neg":
				pos = Vector3(pos.x + oh, pos.y + ov, pos.z)
		if bool(f[4]):
			_add_light(room, f[0], pos, Vector3(0, py, 0), le, lr, lc)
		if f[3] != null:
			_add_painting(room, f[0], pos, f[2], f[3], ps)

	if bool(generator.light_ceiling):
		_add_light(room, "Ceiling", Vector3(0, hh - t - 0.05, 0), Vector3(0, -hh * 0.5, 0), le, lr, lc, Vector3(-90, 0, 0))
	if generator.painting_ceiling_texture != null:
		_add_painting(room, "Ceiling", Vector3(0, hh - t - 0.02, 0), Vector3(-90, 0, 0), generator.painting_ceiling_texture, ps)


func _add_painting(room: Node, face_name: String, pos: Vector3, mount_rot: Vector3, tex: Texture2D, scale_factor: float) -> void:
	var mount := Node3D.new()
	mount.name = "Painting_" + face_name
	mount.position = pos
	mount.rotation_degrees = mount_rot
	room.add_child(mount, true)
	_set_owner(mount)

	var aspect: float = 1.0
	if tex:
		var tw := tex.get_width()
		var th := tex.get_height()
		if th > 0:
			aspect = float(tw) / float(th)

	var fp: float = 0.05
	var fd: float = 0.08
	var s: float = scale_factor

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.2, 0.2, 0.2)
	frame_mat.emission_enabled = true
	frame_mat.emission = Color.BLACK

	var canvas_mat := StandardMaterial3D.new()
	if tex:
		canvas_mat.albedo_texture = tex
	canvas_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canvas_mat.uv1_scale = Vector3(1, -1, 1)
	canvas_mat.uv1_offset = Vector3(0, 1, 0)

	var fw_val := aspect + fp * 2.0
	var fh_val := 1.0 + fp * 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := [
		{"p": Vector3(0, fh_val * 0.5 - fp * 0.5, 0) * s, "sz": Vector3(fw_val * s, fp * s, fd * s)},
		{"p": Vector3(0, -(fh_val * 0.5 - fp * 0.5), 0) * s, "sz": Vector3(fw_val * s, fp * s, fd * s)},
		{"p": Vector3(-(fw_val * 0.5 - fp * 0.5), 0, 0) * s, "sz": Vector3(fp * s, fh_val * s, fd * s)},
		{"p": Vector3(fw_val * 0.5 - fp * 0.5, 0, 0) * s, "sz": Vector3(fp * s, fh_val * s, fd * s)},
	]
	for seg in segs:
		var box := BoxMesh.new()
		box.size = seg.sz
		st.append_from(box, 0, Transform3D.IDENTITY.translated(seg.p))
	st.generate_normals()
	var frame_am := ArrayMesh.new()
	st.commit(frame_am)
	frame_am.lightmap_unwrap(Transform3D.IDENTITY, 0.05)
	frame_am.surface_set_material(0, frame_mat)
	var frame_mi := MeshInstance3D.new()
	frame_mi.name = "Frame"
	frame_mi.mesh = frame_am
	mount.add_child(frame_mi, true)
	_set_owner(frame_mi)

	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var plane := PlaneMesh.new()
	plane.size = Vector2(aspect * s, 1.0 * s)
	plane.material = canvas_mat
	canvas.mesh = _make_lightmapped(plane)
	canvas.rotation_degrees.x = -90
	canvas.scale.x = -1
	canvas.position = Vector3(0, 0, -0.0625 * s)
	mount.add_child(canvas, true)
	_set_owner(canvas)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = 8
	area.set_meta("interact_type", "painting")
	area.set_meta("interact_index", generator._paintings.size())
	area.set_meta("painting_frame_mat", frame_mat)
	area.set_meta("painting_tex", tex)
	area.set_meta("painting_name", tex.resource_path.get_file() if tex else "")
	mount.add_child(area, true)
	_set_owner(area)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(fw_val * s, fh_val * s, fd * s + 0.05)
	cs.shape = shape
	area.add_child(cs, true)
	_set_owner(cs)

	generator._paintings.append({"mount": mount, "frame_mat": frame_mat, "texture": tex})


func _add_light(room: Node, face_name: String, pos: Vector3, target: Vector3, energy: float, range_val: float, color: Color, explicit_rot: Variant = null) -> void:
	var lt := str(generator.light_type)
	var light: Light3D
	if lt == "Omni":
		var o := OmniLight3D.new()
		o.omni_range = range_val
		light = o
	else:
		var s := SpotLight3D.new()
		if explicit_rot != null:
			s.rotation_degrees = explicit_rot
		else:
			s.look_at(target)
		s.spot_range = range_val
		s.spot_angle = 60.0
		s.spot_angle_attenuation = 1.0
		light = s
	light.name = "Light_" + face_name
	light.position = pos
	light.light_energy = energy
	light.light_color = color
	light.light_bake_mode = 1
	room.add_child(light, true)
	_set_owner(light)


func _add_settings_button(room: Node3D) -> void:
	var hw: float = float(generator.width) * 0.5
	var hd: float = float(generator.depth) * 0.5
	var hh: float = float(generator.height) * 0.5
	var t: float = float(generator.wall_thickness)

	var mount := Node3D.new()
	mount.name = "SettingsButton"
	mount.position = Vector3(-hw + t + 0.04, -hh * 0.15, hd * 0.35)
	mount.rotation_degrees = Vector3(0, 90, 0)
	room.add_child(mount, true)
	_set_owner(mount)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.18)
	mat.emission_enabled = true
	mat.emission = Color.BLACK

	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.35, 0.03)

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = box
	body.material_override = mat
	mount.add_child(body, true)
	_set_owner(body)

	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.text = "CREATE"
	lbl.font_size = 56
	lbl.pixel_size = 0.0035
	lbl.modulate = Color(0.9, 0.9, 0.9)
	lbl.position = Vector3(0, -0.02, 0.02)
	mount.add_child(lbl, true)
	_set_owner(lbl)

	var area := Area3D.new()
	area.name = "ClickArea"
	area.collision_layer = 8
	area.set_meta("interact_type", "settings")
	area.set_meta("interact_index", 0)
	area.set_meta("settings_mat", mat)
	mount.add_child(area, true)
	_set_owner(area)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.65, 0.4, 0.06)
	cs.shape = shape
	area.add_child(cs, true)
	_set_owner(cs)

	mount.visible = false


func _set_owner(node: Node) -> void:
	var root := generator.get_tree().edited_scene_root
	if root:
		node.owner = root
