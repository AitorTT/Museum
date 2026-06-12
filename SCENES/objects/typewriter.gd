extends Node3D

@export var full_text: String
@export var char_delay: float = 0.1

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var viewport: SubViewport = $SubViewport
@onready var label: Label = $SubViewport/Control/Label

func _ready():
	# Ensure the viewport exists
	if not viewport:
		push_error("SubViewport node not found!")
		return

	# Clear the text
	label.text = ""

	# Setup the mesh material
	setup_material()

	# Start the typewriter effect
	async_typewriter()

func setup_material() -> void:
	var mat: StandardMaterial3D
	if mesh.material_override:
		mat = mesh.material_override
	else:
		mat = StandardMaterial3D.new()
		mesh.material_override = mat

	# Assign the viewport texture safely
	var tex = viewport.get_texture()
	if tex:
		mat.albedo_texture = tex
	else:
		push_error("Viewport texture is null!")

	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func async_typewriter() -> void:
	while true:  # loop forever
		label.text = ""  # clear text at start
		for char in full_text:
			label.text += char
			await get_tree().create_timer(char_delay).timeout
			
		await get_tree().create_timer(1.0).timeout  # 1-second wait
