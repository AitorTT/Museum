extends CharacterBody3D

@export var speed: float = 7.0
@export var rotation_speed: float = 3
@export var gravity: float = 9.8 * 3
@export_range(-45, 45) var max_pitch_angle_deg: float = 45.0

@onready var left_knob: Panel = $Joysticks_margins/Control/MarginContainer/HBoxContainer/Left/Joystick_movement
@onready var right_knob: Panel = $Joysticks_margins/Control/MarginContainer/HBoxContainer/Right/Joystick_rotation
@onready var joysticks = $Joysticks_margins

@onready var camera_arm: SpringArm3D = $CameraArm  # Adjust name as needed
@onready var IS_ANDROID_WEB := OS.has_feature("web_android")

var pitch: float = 0.0  # In radians

@export var mouse_sensitivity := 0.005

var _hovered_painting: Painting = null


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if IS_ANDROID_WEB == false:
		joysticks.hide()
		
				
func _physics_process(delta: float) -> void:
	var move_input: Vector2 = left_knob.output_vector
	var rot_input: Vector2 = right_knob.rotation_delta

	# ---- ROTATION (Android only) ----
	if IS_ANDROID_WEB:
		rotation.y -= rot_input.x * rotation_speed * delta

		pitch -= rot_input.y * rotation_speed * delta
		pitch = clamp(
			pitch,
			deg_to_rad(-max_pitch_angle_deg),
			deg_to_rad(max_pitch_angle_deg)
		)
		camera_arm.rotation.x = pitch

	var direction := Vector3.ZERO

	if IS_ANDROID_WEB:
		var forward := transform.basis.z
		var right := transform.basis.x
		direction = (forward * move_input.y + right * move_input.x)
	else:
		var input_dir := Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward"
		)
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))

	if direction.length() > 0.0:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()


# Click on objects
@onready var camera: Camera3D = $CameraArm/Camera3D

static var ignore_clicks: bool = false

func _input(event: InputEvent) -> void:
	if ignore_clicks:
		return
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if ignore_clicks:
		return
	# ----------------------------
	# DESKTOP (mouse)
	# ----------------------------
	if not IS_ANDROID_WEB:
		if event is InputEventMouseMotion:
			# Mouse look
			rotate_y(-event.relative.x * mouse_sensitivity)

			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(
				pitch,
				deg_to_rad(-max_pitch_angle_deg),
				deg_to_rad(max_pitch_angle_deg)
			)
			camera_arm.rotation.x = pitch

			# Hover detection
			_update_hover(event.position)

		elif event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
			_click_at(event.position)

		return  # 🚪 desktop handled


	# ----------------------------
	# ANDROID WEB (touch)
	# ----------------------------
	if event is InputEventScreenTouch:
		if event.pressed:
			_click_at(event.position)



func _update_hover(screen_pos: Vector2) -> void:
	var painting := _pick_painting(screen_pos)

	if painting != _hovered_painting:
		if _hovered_painting:
			_hovered_painting.on_hover_exit()

		_hovered_painting = painting

		if _hovered_painting:
			_hovered_painting.on_hover_enter()


func _click_at(screen_pos: Vector2) -> void:
	var painting := _pick_painting(screen_pos)
	if painting:
		painting.on_clicked()



func _pick_painting(screen_pos: Vector2) -> Painting:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 100000.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if not result:
		return null

	var node: Node = result.collider
	
	while node and not (node is Painting):
		node = node.get_parent()

	return node

	
