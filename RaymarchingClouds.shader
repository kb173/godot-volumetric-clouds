shader_type spatial;
render_mode unshaded;

uniform sampler2D worley;

uniform float worley_uv_scale = 0.0001;
uniform float depth = 128.0;

uniform int num_steps = 1024;
uniform float step_length = 10.0;

varying vec3 offset;

uniform float cloud_begin = 2000.0;
uniform float cloud_end = 5000.0;

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

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float screen_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, screen_depth) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;

	vec3 start_position = CAMERA_MATRIX[3].xyz * step_length;
	
	vec2 centered_uv = vec2(UV.x - 0.5, -UV.y + 0.5) * 2.0;
	vec3 direction = (INV_PROJECTION_MATRIX * vec4(centered_uv, 0.0, 1.0)).xyz;
	direction = normalize((CAMERA_MATRIX * vec4(direction, 0.0)).xyz);
	
	
	// March forward
	float distance_to_camera = 0.0f;
	vec3 cloud_color = vec3(1.0, 1.0, 1.0);
	float cloud_alpha = 0.0f;
	
	for (int i = 0; i < num_steps; i++) {
		vec3 position = (start_position + distance_to_camera * direction);
		distance_to_camera += step_length;
		
		if (position.y < cloud_begin || position.y > cloud_end) { continue; }
		
		float density = cloud_density(position) * (1.0 + -cos(((position.y - (cloud_begin)) / (cloud_end - cloud_begin)) * 6.2831853)) / 2.0;
		
		cloud_alpha += density * 0.005;
	}
	
	ALBEDO = cloud_color;
	ALPHA = cloud_alpha;
}