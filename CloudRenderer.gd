extends MeshInstance


onready var _camera = get_parent()


func _process(delta: float) -> void:
	get_surface_material(0).set_shader_param("global_transform", _camera.get_global_transform())
	get_surface_material(0).set_shader_param("fov", _camera.fov)
