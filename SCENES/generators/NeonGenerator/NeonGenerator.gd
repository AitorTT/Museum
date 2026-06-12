@tool
extends Node3D

@export_category("Neon Text")
@export var text_enabled: bool = true
@export var text: String = "MUSEUM"
@export var glow_color: Color = Color(0.0, 0.8, 1.0)
@export var glow_intensity: float = 3.0
@export var font_size: int = 128
@export var depth: float = 0.05
@export var pixel_size: float = 0.004

@export_category("Options")
@export var use_mesh: bool = true
@export_enum("Real-time", "Baked", "Both") var bake_mode: int = 0
@export var add_light: bool = true
@export var light_range: float = 2.0
@export var light_energy: float = 1.0

@export_category("Line Lamp")
@export var use_line_lamp: bool = false
@export var line_length: float = 2.0
@export var line_count: int = 5
@export var fixture_mesh: Mesh

@export_category("Generate")
@export var generate_neon: bool = false:
	set(v):
		if v:
			_generate()
			generate_neon = false
@export var clear_neon: bool = false:
	set(v):
		if v:
			_clear()
			clear_neon = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate()


func _generate() -> void:
	_clear()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy = glow_intensity

	if text_enabled:
		if use_mesh:
			var mi := MeshInstance3D.new()
			mi.name = "NeonText"
			var tm := TextMesh.new()
			tm.text = text
			tm.font_size = font_size
			tm.depth = depth
			tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mi.mesh = tm
			mi.material_override = mat
			add_child(mi, true)
			_set_owner(mi)
		else:
			var lbl := Label3D.new()
			lbl.name = "NeonSign"
			lbl.text = text
			lbl.font_size = font_size
			lbl.pixel_size = pixel_size
			lbl.modulate = Color(1, 1, 1)
			lbl.outline_size = 12
			lbl.outline_modulate = glow_color * 0.6
			lbl.material_override = mat
			add_child(lbl, true)
			_set_owner(lbl)

	if add_light:
		var bake_modes := [Light3D.BAKE_DISABLED, Light3D.BAKE_STATIC, Light3D.BAKE_DYNAMIC]
		if use_line_lamp and line_count > 1:
			var spacing := line_length / float(line_count - 1) if line_count > 1 else 0.0
			var start := -line_length * 0.5
			for i in line_count:
				var light := OmniLight3D.new()
				light.name = "NeonLight_%d" % i
				light.omni_range = light_range
				light.light_color = glow_color
				light.light_energy = light_energy / float(line_count)
				light.light_bake_mode = bake_modes[bake_mode]
				light.position = Vector3(start + float(i) * spacing, 0, -0.5)
				add_child(light, true)
				_set_owner(light)
		else:
			var light := OmniLight3D.new()
			light.name = "NeonLight"
			light.omni_range = light_range
			light.light_color = glow_color
			light.light_energy = light_energy
			light.light_bake_mode = bake_modes[bake_mode]
			light.position = Vector3(0, 0, -0.5)
			add_child(light, true)
			_set_owner(light)

	if fixture_mesh:
		var fixture := MeshInstance3D.new()
		fixture.name = "NeonFixture"
		fixture.mesh = fixture_mesh
		var fix_mat := StandardMaterial3D.new()
		fix_mat.albedo_color = Color(0.1, 0.1, 0.1)
		fix_mat.emission_enabled = true
		fix_mat.emission = glow_color
		fix_mat.emission_energy = glow_intensity * 0.3
		fixture.material_override = fix_mat
		add_child(fixture, true)
		_set_owner(fixture)


func _clear() -> void:
	for child in get_children():
		if child.name.begins_with("Neon"):
			child.queue_free()


func _set_owner(node: Node) -> void:
	var root := get_tree().edited_scene_root
	if root:
		node.owner = root
