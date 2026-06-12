extends Panel

@onready var handle := $TextureRect

var drag_start := Vector2.ZERO
var drag_vector := Vector2.ZERO
var dragging := false
var rotation_delta := Vector2.ZERO  # Exposed to character

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			drag_start = event.position
			dragging = true
		else:
			_reset_knob()

	elif event is InputEventScreenDrag and dragging:
		drag_vector = event.position - drag_start
		var max_distance = size.x * 0.4

		if drag_vector.length() > max_distance:
			drag_vector = drag_vector.normalized() * max_distance

		handle.position = (size - handle.size) / 2 + drag_vector
		rotation_delta = drag_vector / max_distance

func _reset_knob():
	drag_vector = Vector2.ZERO
	handle.position = (size - handle.size) / 2
	rotation_delta = Vector2.ZERO
	dragging = false
