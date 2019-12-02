extends Spatial


onready var _head = get_node("Viewport/Head")
onready var _camera = _head.get_node("Camera")

const MOUSE_SENSITIVITY = 0.07
const MOUSE_MOVE_SPEED = 0.1


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	_head.translation += MOUSE_MOVE_SPEED * Vector3.FORWARD * delta


func _input(event):
	if event is InputEventMouseMotion:
		_camera.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))
		_head.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Prevent player from doing a purzelbaum
		_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -70, 70)