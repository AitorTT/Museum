@tool
class_name RoomInteraction
extends Node

var generator: Node3D

var _crosshair: Label
var _hovered_type: String = ""
var _hovered_index: int = -1
var _hovered_area: Area3D
var _prev_hovered_type: String = ""
var _prev_hovered_index: int = -1
var _prev_hovered_area: Area3D
var _mouse_down: bool = false
var _dbg_ray_hit: String = ""
var _room_cull_hysteresis = {}
var _cull_frame_count: int = 0


func setup(gen: Node3D) -> void:
	generator = gen
	name = "RoomInteraction"


func setup_crosshair() -> void:
	var cl := CanvasLayer.new()
	cl.name = "Crosshair"
	cl.layer = 129
	generator.add_child(cl)
	var lbl := Label.new()
	lbl.name = "CrosshairLabel"
	lbl.text = "."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cl.add_child(lbl)
	_crosshair = lbl


func set_crosshair_visible(v: bool) -> void:
	if _crosshair:
		_crosshair.get_parent().visible = v


func get_camera() -> Camera3D:
	var player := generator.get_node_or_null("PLAYER") as Node3D
	if not player:
		return null
	return player.get_node_or_null("CameraArm/Camera3D") as Camera3D


func process_loop() -> void:
	if not generator.IS_ANDROID_WEB:
		_update_hover()
		_handle_click()
	_update_debug()
	_cull_frame_count += 1
	if _cull_frame_count % 10 == 0:
		_cull_distant_rooms()


func setup_debug() -> void:
	var l := _get_debug_label()
	if l:
		l.visible = bool(generator.show_debug)


func set_debug_visible(v: bool) -> void:
	var l := _get_debug_label()
	if l:
		l.visible = v


func _get_debug_label() -> Label:
	var cl := generator.get_node_or_null("DebugOverlay") as CanvasLayer
	if not cl:
		return null
	return cl.get_node_or_null("Label") as Label


func _update_debug() -> void:
	if not bool(generator.show_debug):
		return
	var l := _get_debug_label()
	if not l:
		return
	var perf := Performance
	var fps := perf.get_monitor(perf.TIME_FPS)
	var frame_time := perf.get_monitor(perf.TIME_PROCESS) * 1000.0
	var draw := perf.get_monitor(perf.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := perf.get_monitor(perf.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var meshes := perf.get_monitor(perf.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var mem := int(perf.get_monitor(perf.MEMORY_STATIC)) >> 20
	l.text = "FPS: %d  Frame: %.1fms\nDraw: %d  Prims: %d\nMeshes: %d  Mem: %dMB\nRay: %s\nHover: %s[%d]  Paintings: %d" % [fps, frame_time, draw, prims, meshes, mem, _dbg_ray_hit, _hovered_type, _hovered_index, generator._paintings.size()]


func _update_hover() -> void:
	if generator._settings_panel and generator._settings_panel.is_visible():
		_hovered_type = ""
		_hovered_index = -1
		_dbg_ray_hit = "—"
		return
	if generator._transform_panel and generator._transform_panel.is_visible():
		_hovered_type = ""
		_hovered_index = -1
		_dbg_ray_hit = "—"
		return
	var camera := get_camera()
	if not camera:
		return
	var viewport := camera.get_viewport()
	if not viewport:
		return
	var size := viewport.get_visible_rect().size
	var from := camera.project_ray_origin(size * 0.5)
	var to := from + camera.project_ray_normal(size * 0.5) * 50.0
	var space := generator.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 8
	var result := space.intersect_ray(query)

	_hovered_type = ""
	_hovered_index = -1
	_dbg_ray_hit = "—"

	if result:
		var obj = result.collider
		if obj:
			_dbg_ray_hit = str(obj.name) + " (" + str(obj.get_class()) + ")"
		if result.collider is Area3D:
			var area := result.collider as Area3D
			if area.has_meta("interact_type"):
				_hovered_type = area.get_meta("interact_type") as String
				_hovered_index = area.get_meta("interact_index") as int
				_hovered_area = area

	if _hovered_type != _prev_hovered_type or _hovered_index != _prev_hovered_index or _hovered_area != _prev_hovered_area:
		if _prev_hovered_type == "painting" and _prev_hovered_area and generator._viewer_panel:
			generator._viewer_panel.highlight_painting(_prev_hovered_area, false, _prev_hovered_index)
		elif _prev_hovered_type == "button":
			_highlight_button(_prev_hovered_index, false)
		elif _prev_hovered_type == "settings":
			_highlight_settings(false)
		if _hovered_type == "painting" and _hovered_area and generator._viewer_panel:
			generator._viewer_panel.highlight_painting(_hovered_area, true, _hovered_index)
		elif _hovered_type == "button":
			_highlight_button(_hovered_index, true)
		elif _hovered_type == "settings":
			_highlight_settings(true)
		_prev_hovered_type = _hovered_type
		_prev_hovered_index = _hovered_index
		_prev_hovered_area = _hovered_area


func _handle_click() -> void:
	if generator._viewer_panel and generator._viewer_panel.is_visible():
		return
	if generator._settings_panel and generator._settings_panel.is_visible():
		return
	if generator._transform_panel and generator._transform_panel.is_visible():
		return
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not _mouse_down:
		_mouse_down = true
		if _hovered_type == "painting" and _hovered_area and generator._viewer_panel:
			var tex: Texture2D = generator._viewer_panel.get_painting_tex(_hovered_area, _hovered_index)
			if tex:
				generator._viewer_panel.show_viewer(tex, _hovered_area)
		elif _hovered_type == "button" and _hovered_index >= 0 and generator._elevator_gen:
			generator._elevator_gen.press_button(_hovered_index)
		elif _hovered_type == "settings":
			_toggle_settings()
			if generator._settings_panel and generator._settings_panel.is_visible():
				_highlight_settings(false)
	elif not pressed:
		_mouse_down = false


func handle_touch(screen_pos: Vector2) -> void:
	if generator._viewer_panel and generator._viewer_panel.is_transitioning():
		return
	if generator._transform_panel and generator._transform_panel.is_visible():
		generator._transform_panel.hide_panel()
		return
	if generator._viewer_panel and generator._viewer_panel.is_visible():
		generator._viewer_panel.hide_viewer()
		return
	var camera := get_camera()
	if not camera:
		return
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 50.0
	var space := generator.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 8
	var result := space.intersect_ray(query)
	if not result or not (result.collider is Area3D):
		return
	var area := result.collider as Area3D
	if not area.has_meta("interact_type"):
		return
	var interact_type := area.get_meta("interact_type") as String
	var interact_index := area.get_meta("interact_index") as int
	if interact_type == "painting" and generator._viewer_panel:
		var tex: Texture2D = generator._viewer_panel.get_painting_tex(area, interact_index)
		if tex:
			generator._viewer_panel.show_viewer(tex, area)
	elif interact_type == "button" and generator._elevator_gen:
		generator._elevator_gen.press_button(interact_index)
		_flash_button(interact_index)
	elif interact_type == "settings":
		_toggle_settings()
		if generator._settings_panel and generator._settings_panel.is_visible():
			_highlight_settings(false)


func _flash_button(index: int) -> void:
	if not generator._elevator_gen:
		return
	generator._elevator_gen.hover_button(index)
	await get_tree().create_timer(0.12).timeout
	generator._elevator_gen.unhover_button()


func _highlight_button(index: int, hovered: bool) -> void:
	if not generator._elevator_gen:
		return
	if hovered:
		generator._elevator_gen.hover_button(index)
	else:
		generator._elevator_gen.unhover_button()


func _highlight_settings(hovered: bool) -> void:
	if not _hovered_area or not _hovered_area.has_meta("settings_mat"):
		return
	var mat := _hovered_area.get_meta("settings_mat") as StandardMaterial3D
	if not mat:
		return
	if hovered:
		mat.emission = Color(0, 0.6, 1)
		mat.emission_energy = 1.0
	else:
		mat.emission = Color.BLACK
		mat.emission_energy = 0.0


func _toggle_settings() -> void:
	if generator._settings_panel:
		generator._settings_panel.toggle()


func _cull_distant_rooms() -> void:
	var cam := get_camera()
	if not cam:
		return
	var cam_y := cam.global_position.y
	var closest_dist := INF
	var closest_room: Node3D
	for child in generator.get_children():
		if child is Node3D and child.name.begins_with("Room"):
			var d: float = abs(child.global_position.y - cam_y)
			if d < closest_dist:
				closest_dist = d
				closest_room = child
	for child in generator.get_children():
		if child is Node3D and child.name.begins_with("Room"):
			var dist: float = abs(child.global_position.y - cam_y)
			if child == closest_room:
				if not child.visible:
					child.visible = true
					_room_cull_hysteresis[child] = true
				continue
			var was: bool = _room_cull_hysteresis.get(child, true)
			var show := was
			if was and dist > 5.0:
				show = false
			elif not was and dist < 3.0:
				show = true
			if show != was:
				child.visible = show
				_room_cull_hysteresis[child] = show


func reset() -> void:
	_hovered_type = ""
	_hovered_index = -1
	_hovered_area = null
	_prev_hovered_type = ""
	_prev_hovered_index = -1
	_prev_hovered_area = null
	_mouse_down = false
