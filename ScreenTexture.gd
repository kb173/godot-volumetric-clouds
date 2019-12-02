extends ColorRect


export(NodePath) var camera_path

var _camera


func _ready():
	_camera = get_node(camera_path)


func _process(delta: float) -> void:
	material.set_shader_param("global_transform", _camera.get_global_transform())
	
	print(_camera.get_global_transform()[2])
