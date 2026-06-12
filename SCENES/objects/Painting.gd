extends Node3D
class_name Painting

@export var texture: Texture2D
@export var frame_depth: float = 0.1
@export var frame_color: Color = Color(0.2, 0.2, 0.2)
@export var hover_glow_color: Color = Color(1.0, 0.9, 0.6)
@export var hover_glow_strength: float = 1.5

@export var frame_padding: float = 0.1   # Extra space around painting
@export var hover_padding: float = 0.2   # Extra area for hover/click

var _frame_mesh: MeshInstance3D
var _frame_material: StandardMaterial3D
var _area: Area3D


func _ready():
	if not texture:
		push_warning("No texture assigned to Painting.")
		return

	if get_parent() is Node3D and get_parent().get_child_count() > 0:
		var target := get_parent().get_child(0)
		if target != self:
			look_at(target.global_position)
			rotation_degrees.y += 180

	_build_frame()
	_build_canvas()
	_setup_click_area()


# ---------------- FRAME ----------------
func _build_frame() -> void:
	var w := texture.get_width()
	var h := texture.get_height()
	if h == 0:
		return

	var aspect := float(w) / float(h)

	_frame_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(aspect + frame_padding, 1.0 + frame_padding, frame_depth)
	_frame_mesh.mesh = box

	_frame_material = StandardMaterial3D.new()
	_frame_material.albedo_color = frame_color
	_frame_material.emission_enabled = true
	_frame_material.emission = Color.BLACK

	_frame_mesh.mesh.surface_set_material(0, _frame_material)
	add_child(_frame_mesh)


# ---------------- CANVAS ----------------
func _build_canvas() -> void:
	var w := texture.get_width()
	var h := texture.get_height()
	if h == 0:
		return

	var aspect := float(w) / float(h)

	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(aspect, 1.0)
	plane.mesh = plane_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.uv1_triplanar = false

	plane.mesh.surface_set_material(0, mat)

	plane.rotate_x(-PI / 2)
	plane.translate_object_local(Vector3(0, -frame_depth * 0.51, 0))
	plane.scale = Vector3(1, -1, -1)

	add_child(plane)


# ---------------- CLICK AREA ----------------
func _setup_click_area() -> void:
	var w := texture.get_width()
	var h := texture.get_height()
	if h == 0:
		return

	var aspect := float(w) / float(h)

	_area = Area3D.new()
	_area.collision_layer = 1
	_area.collision_mask = 1

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(aspect + hover_padding, 1.0 + hover_padding, frame_depth + 0.05)
	shape.shape = box

	_area.add_child(shape)
	add_child(_area)


# ---------------- INTERACTION ----------------
func on_hover_enter() -> void:
	if not _frame_material:
		return

	_frame_material.emission = hover_glow_color
	_frame_material.emission_energy = hover_glow_strength


func on_hover_exit() -> void:
	if not _frame_material:
		return

	_frame_material.emission = Color.BLACK
	_frame_material.emission_energy = 0.0


func on_clicked() -> void:
	print("Painting clicked:", texture.resource_path)
	
	var root = get_tree().current_scene
	if not root:
		push_warning("No current scene found")
		return
	
	var viewer = root.get_node_or_null("UI_Layer/FullscreenViewer")
	if viewer:
		viewer.show_image(texture)
	else:
		push_warning("FullscreenViewer node not found")
