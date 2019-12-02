shader_type canvas_item;

uniform sampler2D camera_view;
uniform sampler2D worley;

uniform float worley_uv_scale = 0.005;
uniform float depth = 128.0;

uniform int num_steps = 512;
uniform float step_length = 1.0;

uniform mat4 global_transform;

varying vec3 offset;
varying vec3 vertex_pos;
varying vec3 start_direction;

uniform float fov = 45.0;
uniform vec3 cameraPos = vec3(-5.0, 0.0, 0.0);
uniform vec3 front = vec3(1.0, 0.0, 0.0);
uniform vec3 up = vec3(0.0, 1.0, 0.0);

vec4 texture3d(sampler2D p_texture, vec3 p_uvw) {
	vec3 mod_uvw = mod(p_uvw  * worley_uv_scale + offset, 1.0);
	
	float fd = mod_uvw.z * depth;
	float fz = floor(fd);
	
	vec2 uv1 = vec2(mod_uvw.x, (mod_uvw.y + fz) / depth);
	vec2 uv2 = vec2(mod_uvw.x, mod((mod_uvw.y + fz + 1.0) / depth, 1.0));
	
	vec4 col1 = texture(p_texture, uv1);
	vec4 col2 = texture(p_texture, uv2);
	
	return mix(col1, col2, fd - fz);
}

float cloud_density(vec3 p_pos) {
	vec4 density_in_texture = texture3d(worley, p_pos);
	
	// join our octaves
	float value = density_in_texture.r + (0.5 * density_in_texture.g) + (0.25 * density_in_texture.b);
	
	// inverse and clamp
	value = clamp(1.0 - value, 0.0, 1.0);
	
	return value;
}

// Adapted from https://github.com/PLUkraine/raymarching-godot
vec3 get_ray_direction(vec2 resolution, vec2 uv)
{
	float aspect = resolution.x / resolution.y;
	float fov2 = radians(fov) / 2.0;
	
	// convert coordinates from [0, 1] to [-1, 1]
	// and invert y axis to flow from bottom to top
	vec2 screenCoord = (uv - 0.5) * 2.0;
	screenCoord.x *= aspect;
	screenCoord.y = -screenCoord.y;
	
	vec2 offsets = screenCoord * tan(fov2);
	
	vec3 rayFront = -normalize(global_transform[2].xyz);
	vec3 rayRight = normalize(cross(rayFront, normalize(global_transform[1].xyz)));
	vec3 rayUp = cross(rayRight, rayFront);
	vec3 rayDir = rayFront + rayRight * offsets.x + rayUp * offsets.y;
	
	return normalize(rayDir);
}

void fragment() {
	vec3 start_position = global_transform[3].xyz / worley_uv_scale;
	vec3 direction = get_ray_direction(1.0 / SCREEN_PIXEL_SIZE, UV);
	
	// Draw the camera's view
    COLOR = texture(camera_view, SCREEN_UV);
	
	// March forward
	float distance_to_camera = 0.0f;
	vec3 cloud_color = vec3(1.0, 1.0, 1.0);
	float cloud_alpha = 0.0f;
	
	for (int i = 0; i < num_steps; i++) {
		vec3 position = (start_position + distance_to_camera * direction);
		
		float density = cloud_density(position);
		
		cloud_alpha += density * 0.005;
		
		distance_to_camera += step_length;
	}
	
	COLOR += vec4(cloud_color * cloud_alpha, 0.0);
}