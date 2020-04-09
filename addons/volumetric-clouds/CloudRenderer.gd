tool
extends MeshInstance

var weather

func _ready():
	weather = preload("WeatherMaker/WeatherMaker.tscn").instance()
	add_child(weather)
	weather.blend_time = 30.0 # seconds
	get_surface_material(0).set_shader_param("weather_map", weather.get_texture())

func set_sun_energy(new_energy: float):
	get_surface_material(0).set_shader_param("sun_energy", new_energy)

func set_sun_direction(new_direction: Vector3):
	get_surface_material(0).set_shader_param("sun_direction", new_direction)
