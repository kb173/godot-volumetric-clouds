extends Spatial


onready var _head = get_node("Viewport/Head")
onready var _camera = _head.get_node("Camera")

const MOUSE_SENSITIVITY = 0.07


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	if event is InputEventMouseMotion:
		_camera.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))
		_head.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Prevent player from doing a purzelbaum
		_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -70, 70)