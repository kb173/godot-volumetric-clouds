shader_type canvas_item;

uniform sampler2D camera_view;
uniform sampler2D worley;

uniform float depth = 128.0;

uniform int num_steps = 64;
uniform float step_length = 0.5;

varying vec3 offset;
varying vec3 start_position;
varying vec3 direction;

vec4 texture3d(sampler2D p_texture, vec3 p_uvw) {
	vec3 mod_uvw = mod(p_uvw + offset, 1.0);
	
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

void vertex() {
	// Position
	start_position = vec3(VERTEX.x, 0.0, VERTEX.y);
	
	// get our direction for our raymarch
	direction = (inverse(PROJECTION_MATRIX) * vec4(normalize(start_position), 0.0)).xyz;
}

void fragment() {
	// Draw the camera's view
    COLOR = texture(camera_view, SCREEN_UV);
	
	// March forward
	float distance_to_camera = 0.0f;
	vec3 cloud_color = vec3(1.0, 1.0, 1.0);
	float cloud_alpha = 0.0f;
	
	for (int i = 0; i < num_steps; i++) {
		vec3 position = (start_position + distance_to_camera * vec3(0.0, 0.0, -1.0)) * 0.002;
		
		float density = cloud_density(position);
		
		cloud_alpha += density * 0.005;
		
		distance_to_camera += step_length;
	}
	
	COLOR += vec4(cloud_color * cloud_alpha, 0.0);
}