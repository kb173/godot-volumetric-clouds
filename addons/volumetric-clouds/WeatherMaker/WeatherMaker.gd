# This script creates a procedural weather map for clouds.

tool
extends Node

signal cycle_finished # When the weather map is finished blending to the next weather

enum {COPY_BUFFER, WEATHER_BUFFER, BLEND_BUFFER}
const TEXTURE_SIZE = 512

export var blend_time = 60.0 # The time it takes to blend from the previous weather map to the next (in seconds barring lag)

var _time = 1.0 # The current time inbetween transitioning

func _init():
	name = "WeatherMaker"

func _ready():
	get_child(COPY_BUFFER).size = Vector2(TEXTURE_SIZE, TEXTURE_SIZE)
	get_child(WEATHER_BUFFER).size = Vector2(TEXTURE_SIZE, TEXTURE_SIZE)
	get_child(BLEND_BUFFER).size = Vector2(TEXTURE_SIZE, TEXTURE_SIZE)
	
	var next_random = Vector3(rand_range(-1000,1000), rand_range(-1000,1000), randf() * 1.5 - 0.2)
	var weather_mat = get_child(WEATHER_BUFFER).get_child(0).material
	weather_mat.set_shader_param("Randomness", next_random)
	
	get_child(COPY_BUFFER).render_target_update_mode = Viewport.UPDATE_ONCE
	yield(get_tree(), "idle_frame")
	get_child(COPY_BUFFER).render_target_update_mode = Viewport.UPDATE_DISABLED
	
	get_child(WEATHER_BUFFER).render_target_update_mode = Viewport.UPDATE_ONCE
	yield(get_tree(), "idle_frame")
	get_child(WEATHER_BUFFER).render_target_update_mode = Viewport.UPDATE_DISABLED

func _process(delta):
	var blend_mat = get_child(BLEND_BUFFER).get_child(0).material
	
	if _time >= 1.0: # If the blending is complete,
		_time = 0.0 # Reset the time,
		emit_signal("cycle_finished")
		
		# Should be the same code as in the _ready function
		var next_random = Vector3(rand_range(-1000,1000), rand_range(-1000,1000), randf() * 1.5 - 0.2)
		var weather_mat = get_child(WEATHER_BUFFER).get_child(0).material
		weather_mat.set_shader_param("Randomness", next_random)
		
		get_child(COPY_BUFFER).render_target_update_mode = Viewport.UPDATE_ONCE
		yield(get_tree(), "idle_frame")
		get_child(COPY_BUFFER).render_target_update_mode = Viewport.UPDATE_DISABLED
		
		get_child(WEATHER_BUFFER).render_target_update_mode = Viewport.UPDATE_ONCE
		yield(get_tree(), "idle_frame")
		get_child(WEATHER_BUFFER).render_target_update_mode = Viewport.UPDATE_DISABLED
	
	blend_mat.set_shader_param("Blend", _smoothstep(_time))
	if blend_time > 0:
		_time += delta / blend_time

func get_texture():
	var weather_map : ViewportTexture = get_child(BLEND_BUFFER).get_texture()
	weather_map.flags = Texture.FLAGS_DEFAULT
	return weather_map

func _smoothstep(x : float) -> float:
	var c_x := clamp(x, 0, 1)
	return c_x * c_x * (3 - 2 * c_x)
