shader_type spatial;
render_mode unshaded;

uniform sampler2D worley;

uniform float worley_uv_scale = 0.00005;
uniform float depth = 128.0;

uniform int num_steps = 128;

varying vec3 offset;

uniform float cloud_begin = 1500.0;
uniform float cloud_end = 10000.0;
uniform float density_cutoff = 1.2;
uniform float sun_march_distance = 500.0;

uniform float rain_absorption_gain = 0.1;

uniform float earth_radius = 6370000.0f;

uniform vec3 sun_direction = vec3(0.0, -0.5, 0.5);

// Get the value by which vertex at given point must be lowered to simulate the earth's curvature 
float get_curve_offset(float distance_squared, float radius) {
	return sqrt(radius * radius + distance_squared) - radius;
}

// Adapted from https://github.com/BastiaanOlij/godot-worley-shader/blob/master/raymarch.shader
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
vec4 ray_sphere_intersect(vec3 ray_origin, vec3 ray_direction, vec3 sphere_origin, float sphere_radius) {
	vec3 m = ray_origin - sphere_origin; 
	float b = dot(m, ray_direction); 
	float c = dot(m, m) - sphere_radius * sphere_radius; 
	
	// Exit if r’s origin outside s (c > 0) and r pointing away from s (b > 0) 
	if (c > 0.0f && b > 0.0f) return vec4(0.0); 
	float discr = b*b - c; 
	
	// A negative discriminant corresponds to ray missing sphere 
	if (discr < 0.0f) return vec4(0.0); 
	
	// Ray now found to intersect sphere, compute smallest t value of intersection
	float t1 = -b - sqrt(discr);
	float t2 = -b + sqrt(discr); 
	
	if (t1 < 0.0 && t2 < 0.0) {return vec4(0.0);}
	float t = t1;
	
	if (t1 < t2 && t1 > 0.0) {
		t = t1;
	} else {
		t = t2;
	}
	
	// If t is negative, ray started inside sphere so clamp t to zero
	if (t < 0.0) {return vec4(0.0);}
	vec3 q = ray_origin + t * ray_direction; 
	
	return vec4(q, t);
}

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
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
	
	// Calculate the maximum depth (the far clip plane)
	vec4 max_depth_view = (INV_PROJECTION_MATRIX * vec4(1.0));
	max_depth_view.xyz /= max_depth_view.w;
	float max_depth = -max_depth_view.z;

	// Get the camera position (the translation)
	vec3 camera_position = (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0f)).xyz;
	
	// Calculate the direction using the camera projection matrix and the UV coordinates
	// Without taking the UV coordinates into account, this would be an orthogonal camera
	vec2 centered_uv = vec2(UV.x - 0.5, -UV.y + 0.5) * 2.0f;
	vec3 direction = (INV_PROJECTION_MATRIX * vec4(centered_uv, 0.0, 1.0)).xyz;
	direction = normalize((CAMERA_MATRIX * vec4(direction, 0.0)).xyz);
	
	// The cloud layer is spherical, so we check where our ray intersects with the outer limit sphere and the inner limit sphere
	vec3 earth_center = vec3(camera_position.x, -earth_radius, camera_position.z);
	
	vec4 march_start = ray_sphere_intersect(camera_position, direction, earth_center, earth_radius + cloud_begin);
	vec4 march_end = ray_sphere_intersect(camera_position, direction, earth_center, earth_radius + cloud_end);
	
	// If we didn't intersect with any sphere, we're above the clouds, looking into space
	if (march_start == vec4(0.0) && march_end == vec4(0.0)) {return;}
	
	// march_start and march_end are only correct if we're below the clouds. If we're inside or above the clouds,
	//  things get a bit more complicated:
	if (camera_position.y > cloud_begin) {
		if (camera_position.y > cloud_end) {
			// Above the clouds
			if (march_start == vec4(0.0)) {
				// We only intersected with the outer sphere - most likely twice. We could get the second intersection
				//  point, but we just use a fixed distance for marching here for simplicity.
				march_start = march_end + vec4(direction, 0.0) * 10000.0;
			}
			// Since we're above the clouds, the intersection with the other sphere is actually our starting point,
			//  so swap start and end!
			vec4 buffer = march_start;
			march_start = march_end;
			march_end = buffer;
		} else {
			// Inside the clouds
			if (march_start != vec4(0.0)) {
				// If we did intersect with the inner sphere, that should be our end point (we're looking downwards)
				march_end = march_start;
			}
			
			// If we're inside the clouds, there could be one right in front of us, so our camera position is
			//  our starting point
			march_start = vec4(camera_position, 0.0);
		}
	}
	
	// If the clouds begin further away than the closest other object, we can stop
	if (linear_depth < max_depth && march_start.w >= linear_depth) {
		return;
	}
	
	// Something like this for temporal AA:
	//march_start -= vec4(direction, 0.0) * rand(vec2(TIME,0.0)) * 2000.0;
	
	// Choose the step length so that we always march from march_start to march_end, with our constant num_steps.
	// However, we do limit this step_length because extremely large steps only cause artifacts.
	float step_length = min(length(march_end.xyz - march_start.xyz) / float(num_steps), 1000.0);
	
	vec3 projected_sun_direction = normalize((INV_CAMERA_MATRIX * INV_PROJECTION_MATRIX * vec4(-sun_direction, 0.0)).xyz);
	
	// March forward
	float distance_to_camera = 0.0f;
	vec3 cloud_color = vec3(0.9, 0.8, 0.8);
	float cloud_alpha = 0.0f;
	
	for (int i = 0; i < num_steps; i++) {
		// If we're already fully opaque, there's no point in continuing
		if (cloud_alpha > 0.99) {
			cloud_alpha = 1.0;
			break;
		}
		
		// Calculate the position of the current sample point
		vec3 position = march_start.xyz + distance_to_camera * direction;
		
		// Step forward (for the next iteration)
		distance_to_camera += step_length;
		
		// We don't need to render clouds on the other side of the earth, so if we're too far down, we stop
		if (position.y < -500.0) {break;}
		
		float distance_to_center = length(earth_center - position);
		
		// TODO: Is this required? It would check again whether we're inside the marching volume, but I think that's
		//  always the case due to previous checks
		// if (distance_to_center < earth_radius + cloud_begin || distance_to_center > earth_radius + cloud_end) {continue;}
		
		// Calculate the cloud density - we mix two textures, scaled and offset by time, to get some dynamics
		float density = cloud_density(position + vec3(TIME * 50.0));
		
		if (density > 0.0) {
			// Calculate how far we're in the layer from 0 (start of clouds, closer to earth) to 1 (end of clouds) 
			float distance_within_cloudlayer = (distance_to_center - earth_radius - cloud_begin) / (cloud_end - cloud_begin);
			
			// We give clouds a more cloudy shape by applying a vertical cosine to the density
			// This causes the typical flat bottom of cumulus clouds
			density = density * (1.0 + -cos((distance_within_cloudlayer * 4.2831853 + 3.0))) / 2.0;
			
			// We use a density cutoff to have some areas with clear sky
			if (density > density_cutoff
				// TODO: Very ugly testing stuff
				// Basically we want the edges of the cloud to fade out nicely, so we check another scaled texture at the border
				// The time scaled differently makes these edges fade around nicely
				|| density > density_cutoff - cloud_density(position * 10.0 + vec3(TIME * 100.0) * 10.0) * 0.11) {
				// March towards the sun
				vec3 sun_march_position = position + sun_march_distance * projected_sun_direction;
				float light_density = cloud_density(sun_march_position + vec3(TIME * 50.0));
				
				float cos_light_view_angle = dot(direction, projected_sun_direction);
			
				cloud_color = vec3(0.9 + (light_density - density) * 0.9);
				cloud_alpha += density * 0.0005 * step_length;
			}
			
			// If the clouds begin further away than the closest other object, we can stop
			// TODO: We already checked this before, could this be required again here?
			/*if (linear_depth < max_depth && distance_to_camera >= linear_depth) {
				break;
			}*/
		}
	}
	
	// Apply our color and alpha
	ALBEDO = cloud_color;
	ALPHA = cloud_alpha;
}