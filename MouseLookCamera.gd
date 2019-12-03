extends Spatial


onready var _head = get_node("Viewport/Head")
onready var _camera = _head.get_node("Camera")

const MOUSE_SENSITIVITY = 0.07
const MOVE_SPEED = 100.0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	var movement_vec: Vector3
	
	if Input.is_action_pressed("move_forward"):
		movement_vec += Vector3.FORWARD
	
	if Input.is_action_pressed("move_back"):
		movement_vec += -Vector3.FORWARD
	
	if Input.is_action_pressed("move_right"):
		movement_vec += Vector3.RIGHT
	
	if Input.is_action_pressed("move_left"):
		movement_vec += -Vector3.RIGHT
	
	_head.translation += _camera.global_transform.basis * (MOVE_SPEED * movement_vec.normalized() * delta)


func _input(event):
	if event is InputEventMouseMotion:
		_camera.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * -1))
		_head.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * -1))
		
		# Prevent player from doing a purzelbaum
		_camera.rotation_degrees.x = clamp(_camera.rotation_degrees.x, -70, 70)