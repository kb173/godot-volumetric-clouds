shader_type spatial;
render_mode unshaded;

uniform sampler2D worley;

uniform float worley_uv_scale = 0.01;
uniform float depth = 128.0;

uniform int num_steps = 1024;

varying vec3 offset;

uniform float cloud_begin = 100.0;
uniform float cloud_end = 150.0;

uniform float earth_radius = 200.0f;

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

// Adapted from https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code
// Returns the 3-dimensional point of intersection and the distance from the ray origin to there in the 4th dimension
// Returns a 0 vector when no hit occured
vec4 raySphereIntersect(vec3 ray_origin, vec3 ray_direction, vec3 sphere_origin, float sphere_radius) {
	vec3 sphere_to_ray = ray_origin - sphere_origin;
	
	float b = dot(sphere_to_ray, ray_direction);
	float c = dot(sphere_to_ray, sphere_to_ray) - sphere_radius * sphere_radius;
	
	// If the ray origin is outside of the sphere and the ray direction points away from it, we can exit
	if (c > 0.0f && b > 0.0f) { return vec4(0.0); }
	
	float discriminant = b * b - c;
	
	// If the distriminant is negative, we miss the sphere
	if (discriminant < 0.0f) { return vec4(0.0); }
	
	// We hit the sphere -> get the distance to the intersection
	float distance_to_intersection = -b - sqrt(discriminant);
	
	// If t is negative, we're inside the sphere - we still want the distance to be positive, though
	distance_to_intersection = abs(distance_to_intersection);
	
	vec3 intersection_point = ray_origin + ray_direction * distance_to_intersection;
	
	return vec4(intersection_point, distance_to_intersection);
}

void vertex() {
	// Cover the viewport with the mesh
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	// Calculate the depth (the value from DEPTH_TEXTURE isn't linear!)
	float screen_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, screen_depth) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;

	// Get the position to start marching at
	vec3 start_position = CAMERA_MATRIX[3].xyz;
	
	// Calculate the direction using the camera projection matrix and the UV coordinates
	vec2 centered_uv = vec2(UV.x - 0.5, -UV.y + 0.5) * 2.0;
	vec3 direction = (INV_PROJECTION_MATRIX * vec4(centered_uv, 0.0, 1.0)).xyz;
	direction = normalize((CAMERA_MATRIX * vec4(direction, 0.0)).xyz);
	
	vec4 march_start = raySphereIntersect(start_position, direction, vec3(start_position.x, -earth_radius, start_position.z), earth_radius + cloud_begin);
	vec4 march_end = raySphereIntersect(start_position, direction, vec3(start_position.x, -earth_radius, start_position.z), earth_radius + cloud_end);
	
	// If the clouds begin further away than the closest other object, we can stop
	if (linear_depth < 499.0 && march_start.w >= linear_depth) {
		return;
	}
	
	float step_length = length(march_end - march_start) / float(num_steps);
	
	//march_start /= step_length;
	
	// March forward
	float distance_to_camera = 0.0f;
	vec3 cloud_color = vec3(1.0, 1.0, 1.0);
	float cloud_alpha = 0.0f;
	
	for (int i = 0; i < num_steps; i++) {
		vec3 position = (march_start.xyz + distance_to_camera * direction);
		distance_to_camera += step_length;
		
		float density = cloud_density(position);
		
		if (density > 0.5) {
			cloud_alpha += density * 0.001;
		}
	}
	
	ALBEDO = cloud_color;
	ALPHA = cloud_alpha;
}