shader_type spatial;
render_mode unshaded;

uniform sampler2D worley;

uniform float worley_uv_scale = 0.001;
uniform float depth = 128.0;

uniform int num_steps = 512;

varying vec3 offset;

uniform float cloud_begin = 100.0;
uniform float cloud_end = 200.0;

uniform float earth_radius = 900.0f;

vec4 texture3d(sampler2D p_texture, vec3 p_uvw) {
	p_uvw *= worley_uv_scale;
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

// Adapted from https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code
// Returns the 3-dimensional point of intersection and the distance from the ray origin to there in the 4th dimension
// Returns a 0 vector when no hit occured
vec4 raySphereIntersect(vec3 ray_origin, vec3 ray_direction, vec3 sphere_origin, float sphere_radius) {
	/*float a = dot(ray_direction, ray_direction) * 2.0f;
	float b = dot(ray_direction, ray_origin) * 2.0f;
	float c = dot(ray_origin, ray_origin);
	
	float discriminant = b * b - 2.0 * a * (c - sphere_radius * sphere_radius);
	
	float t = max(0.0, (-b + sqrt(discriminant)) / a);
	vec3 intersection = ray_origin + ray_direction * t;
	
	return vec4(intersection, t);*/
vec3 m = ray_origin - sphere_origin; 
float b = dot(m, ray_direction); 
float c = dot(m, m) - sphere_radius * sphere_radius; 

// Exit if r’s origin outside s (c > 0) and r pointing away from s (b > 0) 
if (c > 0.0f && b > 0.0f) return vec4(0.0); 
float discr = b*b - c; 

// A negative discriminant corresponds to ray missing sphere 
if (discr < 0.0f) return vec4(0.0); 

// Ray now found to intersect sphere, compute smallest t value of intersection
float t = -b - sqrt(discr); 

// If t is negative, ray started inside sphere so clamp t to zero 
t = abs(t); 
vec3 q = ray_origin + t * ray_direction; 

return vec4(q, t);
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
	vec3 start_position = (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0f)).xyz;
	
	// Calculate the direction using the camera projection matrix and the UV coordinates
	vec2 centered_uv = vec2(UV.x - 0.5, -UV.y + 0.5) * 2.0f;
	vec3 direction = (INV_PROJECTION_MATRIX * vec4(centered_uv, 0.0, 1.0)).xyz;
	direction = normalize((CAMERA_MATRIX * vec4(direction, 0.0)).xyz);
	
	vec4 march_start = raySphereIntersect(start_position, direction, vec3(start_position.x, -earth_radius, start_position.z), earth_radius + cloud_begin);
	vec4 march_end = raySphereIntersect(start_position, direction, vec3(start_position.x, -earth_radius, start_position.z), earth_radius + cloud_end);
	
	// No intersection at all?
	if (march_start == vec4(0.0) && march_end == vec4(0.0)) {return;}
	
	if (start_position.y > cloud_begin) {
		if (start_position.y > cloud_end) {
			vec4 buffer = march_start;
			march_start = march_end;
			march_end = buffer;
		} else {
			march_start = vec4(start_position, length(march_start));
		}
	}
	
	// If the clouds begin further away than the closest other object, we can stop
	if (linear_depth < 499.0 && march_start.w >= linear_depth) {
		return;
	}
	
	float step_length = length(march_end - march_start) / float(num_steps);
	
	// March forward
	float distance_to_camera = 0.0f;
	vec3 cloud_color = vec3(1.0, 1.0, 1.0);
	float cloud_alpha = 0.0f;
	
	for (int i = 0; i < num_steps; i++) {
		vec3 position = march_start.xyz + distance_to_camera * direction;
		distance_to_camera += step_length;
		
		float density = cloud_density(position);
		
		cloud_alpha += density * 0.001;
	}
	
	ALBEDO = cloud_color;
	ALPHA = cloud_alpha;
}