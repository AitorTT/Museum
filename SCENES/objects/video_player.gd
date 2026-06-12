extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var video: VideoStreamPlayer = $SubViewport/VideoStreamPlayer

func _ready():
	# Ensure the mesh has a material
	var mat: StandardMaterial3D
	if mesh.material_override:
		mat = mesh.material_override
	else:
		mat = StandardMaterial3D.new()
		mesh.material_override = mat

	# Assign the video texture
	mat.albedo_texture = video.get_video_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Play the video
	video.play()
