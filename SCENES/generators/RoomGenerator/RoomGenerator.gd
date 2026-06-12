@tool
extends Node3D

@export_category("Room Dimensions")
@export var width: float = 8.0
@export var height: float = 3.0
@export var depth: float = 6.0
@export var wall_thickness: float = 0.15

@export_category("Materials")
@export var wall_material: Material
@export var floor_material: Material
@export var ceiling_material: Material

@export_category("Doors")
@export var door_x_pos: bool = false
@export var door_x_neg: bool = false
@export var door_z_pos: bool = false
@export var door_z_neg: bool = false
@export var door_width: float = 0.9
@export var door_height: float = 2.0

@export_category("Windows")
@export var window_x_pos: bool = false
@export var window_x_neg: bool = false
@export var window_z_pos: bool = false
@export var window_z_neg: bool = false
@export var window_width: float = 1.2
@export var window_height: float = 1.0
@export var window_bottom: float = 0.8

@export_category("Paintings")
@export var painting_x_pos: bool = false
@export var painting_x_pos_texture: Texture2D
@export var painting_x_neg: bool = false
@export var painting_x_neg_texture: Texture2D
@export var painting_z_pos: bool = false
@export var painting_z_pos_texture: Texture2D
@export var painting_z_neg: bool = false
@export var painting_z_neg_texture: Texture2D
@export var painting_ceiling: bool = false
@export var painting_ceiling_texture: Texture2D
@export var painting_height: float = 1.5
@export var painting_scale: float = 0.4

@export var painting_offset_h: float = 0.0
@export var painting_offset_v: float = 0.0

@export_category("Lights")
@export var light_x_pos: bool = false
@export var light_x_neg: bool = false
@export var light_z_pos: bool = false
@export var light_z_neg: bool = false
@export var light_ceiling: bool = false
@export_enum("Spot", "Omni") var light_type: String = "Spot"
@export var light_energy: float = 10.0
@export var light_color: Color = Color(1, 1, 1)
@export var light_range: float = 8.0

@export_category("Debug")
@export var show_debug: bool = true:
	set(v):
		show_debug = v
		if _interaction_panel:
			_interaction_panel.set_debug_visible(v)

@export_category("Save/Load")
@export var room_layout: RoomLayout
@export var save_path: String = "res://SCENES/room_layout.tres"
@export var save_layout: bool = false:
	set(v):
		if v:
			_save_layout()
			save_layout = false
@export var load_layout: bool = false:
	set(v):
		if v:
			_load_layout()
			load_layout = false

@export_category("Generation")
@export var google_sheets_url: String = ""
@export var transforms_sheets_url: String = ""
@export var generate_room: bool = false:
	set(v):
		if v:
			if _builder:
				_builder.generate()
			generate_room = false

@export var clear_room: bool = false:
	set(v):
		if v:
			_clear()
			clear_room = false


@export_category("Settings Panel")
@export var open_settings: bool = false:
	set(v):
		if v:
			_toggle_settings_panel()
			open_settings = false

var _paintings: Array[Dictionary] = []

var _elevator_gen: ElevatorGenerator
var IS_ANDROID_WEB := OS.has_feature("web_android")
var _painting_mount: Node3D

var _transform_panel: PaintingTransformPanel
var _settings_panel
var _viewer_panel
var _interaction_panel
var _builder
var _thieflist



func _ready() -> void:
	var BuilderScript = load("res://SCENES/generators/RoomGenerator/RoomBuilder.gd")
	_builder = BuilderScript.new()
	_builder.setup(self)
	add_child(_builder)

	if Engine.is_editor_hint():
		return
	_transform_panel = PaintingTransformPanel.new()
	_transform_panel.setup(self)
	add_child(_transform_panel)
	_settings_panel = RoomSettingsPanel.new()
	_settings_panel.setup(self)
	add_child(_settings_panel)
	_viewer_panel = PaintingViewer.new()
	_viewer_panel.setup(self)
	add_child(_viewer_panel)
	var InteractionScript = load("res://SCENES/generators/RoomGenerator/RoomInteraction.gd")
	_interaction_panel = InteractionScript.new()
	_interaction_panel.setup(self)
	add_child(_interaction_panel)
	_interaction_panel.setup_debug()
	if not IS_ANDROID_WEB:
		_interaction_panel.setup_crosshair()
	_viewer_panel.setup_viewer()
	_viewer_panel.scan_paintings()
	await get_tree().process_frame
	_load_transforms()
	_elevator_gen = get_node_or_null("ElevatorGenerator") as ElevatorGenerator
	_thieflist = get_node_or_null("Thieflist")
	if _thieflist and not google_sheets_url.is_empty():
		_thieflist.set_sheets_url(google_sheets_url)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _settings_panel:
		_settings_panel.update_cursor()
	if _transform_panel:
		_transform_panel.update_cursor()
	if _interaction_panel:
		if not _transform_panel or not _transform_panel.is_visible():
			_interaction_panel.process_loop()
	if _viewer_panel:
		_viewer_panel.check_web_emoji()


func _input(event: InputEvent) -> void:
	if _viewer_panel and _viewer_panel.handle_input(event):
		return
	if _settings_panel and _settings_panel.is_visible():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_settings_panel.toggle()
			get_viewport().set_input_as_handled()
		return
	if _transform_panel and _transform_panel.is_visible():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_transform_panel.hide_panel()
			get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not IS_ANDROID_WEB or not _interaction_panel:
		return
	if _transform_panel and _transform_panel.is_visible():
		return
	if event is InputEventScreenTouch and event.pressed:
		_interaction_panel.handle_touch(event.position)





func _save_layout() -> void:
	var layout := RoomLayout.new()
	layout.width = width
	layout.height = height
	layout.depth = depth
	layout.wall_thickness = wall_thickness
	layout.wall_material = wall_material
	layout.floor_material = floor_material
	layout.ceiling_material = ceiling_material
	layout.door_x_pos = door_x_pos
	layout.door_x_neg = door_x_neg
	layout.door_z_pos = door_z_pos
	layout.door_z_neg = door_z_neg
	layout.door_width = door_width
	layout.door_height = door_height
	layout.window_x_pos = window_x_pos
	layout.window_x_neg = window_x_neg
	layout.window_z_pos = window_z_pos
	layout.window_z_neg = window_z_neg
	layout.window_width = window_width
	layout.window_height = window_height
	layout.window_bottom = window_bottom
	layout.painting_x_pos = painting_x_pos
	layout.painting_x_pos_texture = painting_x_pos_texture
	layout.painting_x_neg = painting_x_neg
	layout.painting_x_neg_texture = painting_x_neg_texture
	layout.painting_z_pos = painting_z_pos
	layout.painting_z_pos_texture = painting_z_pos_texture
	layout.painting_z_neg = painting_z_neg
	layout.painting_z_neg_texture = painting_z_neg_texture
	layout.painting_ceiling = painting_ceiling
	layout.painting_ceiling_texture = painting_ceiling_texture
	layout.painting_height = painting_height
	layout.painting_scale = painting_scale
	layout.painting_offset_h = painting_offset_h
	layout.painting_offset_v = painting_offset_v
	layout.light_x_pos = light_x_pos
	layout.light_x_neg = light_x_neg
	layout.light_z_pos = light_z_pos
	layout.light_z_neg = light_z_neg
	layout.light_ceiling = light_ceiling
	layout.light_type = light_type
	layout.light_energy = light_energy
	layout.light_color = light_color
	layout.light_range = light_range
	room_layout = layout
	var err := ResourceSaver.save(layout, save_path)
	if err != OK:
		push_error("Failed to save room layout: ", err)


func _load_layout() -> void:
	if room_layout == null:
		return
	width = room_layout.width
	height = room_layout.height
	depth = room_layout.depth
	wall_thickness = room_layout.wall_thickness
	wall_material = room_layout.wall_material
	floor_material = room_layout.floor_material
	ceiling_material = room_layout.ceiling_material
	door_x_pos = room_layout.door_x_pos
	door_x_neg = room_layout.door_x_neg
	door_z_pos = room_layout.door_z_pos
	door_z_neg = room_layout.door_z_neg
	door_width = room_layout.door_width
	door_height = room_layout.door_height
	window_x_pos = room_layout.window_x_pos
	window_x_neg = room_layout.window_x_neg
	window_z_pos = room_layout.window_z_pos
	window_z_neg = room_layout.window_z_neg
	window_width = room_layout.window_width
	window_height = room_layout.window_height
	window_bottom = room_layout.window_bottom
	painting_x_pos = room_layout.painting_x_pos
	painting_x_pos_texture = room_layout.painting_x_pos_texture
	painting_x_neg = room_layout.painting_x_neg
	painting_x_neg_texture = room_layout.painting_x_neg_texture
	painting_z_pos = room_layout.painting_z_pos
	painting_z_pos_texture = room_layout.painting_z_pos_texture
	painting_z_neg = room_layout.painting_z_neg
	painting_z_neg_texture = room_layout.painting_z_neg_texture
	painting_ceiling = room_layout.painting_ceiling
	painting_ceiling_texture = room_layout.painting_ceiling_texture
	painting_height = room_layout.painting_height
	painting_scale = room_layout.painting_scale
	painting_offset_h = room_layout.painting_offset_h
	painting_offset_v = room_layout.painting_offset_v
	light_x_pos = room_layout.light_x_pos
	light_x_neg = room_layout.light_x_neg
	light_z_pos = room_layout.light_z_pos
	light_z_neg = room_layout.light_z_neg
	light_ceiling = room_layout.light_ceiling
	light_type = room_layout.light_type
	light_energy = room_layout.light_energy
	light_color = room_layout.light_color
	light_range = room_layout.light_range


func _clear() -> void:
	if _interaction_panel:
		_interaction_panel.reset()
	if _builder:
		_builder.clear()


func _toggle_settings_panel() -> void:
	if _settings_panel:
		_settings_panel.toggle()


func _get_room() -> Node3D:
	if _builder and _builder.has_method("get_room"):
		return _builder.get_room()
	return null


func _duplicate_room_dir(dir: String) -> void:
	var cur := _get_room()
	if not cur:
		return
	var off := Vector3.ZERO
	match dir:
		"front":
			off.x = -width
		"back":
			off.x = width
		"left":
			off.z = depth
		"right":
			off.z = -depth
		"up":
			off.y = height
		"down":
			off.y = -height
	var pos := cur.position + off
	if _builder and _builder.has_method("duplicate_room"):
		_builder.duplicate_room(pos)


func _load_transforms() -> void:
	if transforms_sheets_url.is_empty():
		return
	var http := HTTPRequest.new()
	http.name = "TransformLoadHTTP"
	add_child(http)
	http.request_completed.connect(_on_transforms_loaded.bind(http))
	http.request(transforms_sheets_url)


func _on_transforms_loaded(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	var raw: Variant = JSON.parse_string(body.get_string_from_utf8())
	if raw == null:
		return
	var data: Dictionary
	if raw is Dictionary:
		data = raw
	else:
		return
	var indices: Array[int] = []
	for key in data:
		var idx: int = int(key)
		indices.append(idx)
	indices.sort()
	for idx in indices:
		var entry: Dictionary = data[str(idx)]
		if idx < 0 or idx >= _paintings.size():
			continue
		var m: Node3D = _paintings[idx].get("mount")
		if not m:
			continue
		if entry.has("position"):
			var p: Variant = entry["position"]
			if p is String:
				p = JSON.parse_string(p)
			if p is Dictionary:
				m.global_position = Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
		if entry.has("rotation"):
			var r: Variant = entry["rotation"]
			if r is String:
				r = JSON.parse_string(r)
			if r is Dictionary:
				m.global_rotation = Vector3(r.get("x", 0.0), r.get("y", 0.0), r.get("z", 0.0))
		if entry.has("scale"):
			var s: Variant = entry["scale"]
			if s is String:
				s = JSON.parse_string(s)
			if s is Dictionary:
				m.scale = Vector3(s.get("x", 1.0), s.get("y", 1.0), s.get("z", 1.0))


func _on_edit_clicked() -> void:
	if _transform_panel and _transform_panel.is_visible():
		_transform_panel.hide_panel()
		return
	if not _painting_mount:
		return
	if _viewer_panel:
		_viewer_panel.hide_viewer()
	_transform_panel.show_panel(_painting_mount)
