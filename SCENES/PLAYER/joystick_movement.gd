extends Panel

@onready var handle := $TextureRect
var drag_start := Vector2.ZERO
var drag_vector := Vector2.ZERO
var dragging := false
var output_vector := Vector2.ZERO


func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			# Touch began
			drag_start = event.position
			dragging = true
		else:
			# Touch ended
			_reset_knob()

	elif event is InputEventScreenDrag and dragging:
		# Finger is dragging — update movement or rotation
		drag_vector = event.position - drag_start
		var max_distance = size.x * 0.4
		if drag_vector.length() > max_distance:
			drag_vector = drag_vector.normalized() * max_distance
		handle.position = (size - handle.size) / 2 + drag_vector

		# Normalize drag vector to range -1.0 to 1.0
		output_vector = drag_vector / max_distance  # or rotation_delta
		
func _reset_knob():
	drag_vector = Vector2.ZERO
	handle.position = (size - handle.size) / 2
	output_vector = Vector2.ZERO  # or rotation_delta
	dragging = false
