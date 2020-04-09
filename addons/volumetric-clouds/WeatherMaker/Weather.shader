shader_type canvas_item;
render_mode blend_disabled;

uniform vec3 Randomness;

float mod289(float x) {return x - floor(x  / 289.0) * 289.0;}
vec3 mod289_3(vec3 x) {return x - floor(x / 289.0) * 289.0;}
vec3 permute_3(vec3 x) {return mod289_3(x*x*34.0 + x);}
float permute(float x) {return mod289(((x*34.0)+1.0)*x);}

// (The constant 0.0243902439 is 1/41)
vec2 rgrad2(vec2 p) {
	// For more isotropic gradients, sin/cos can be used instead.
	float u = permute(permute(p.x) + p.y) * 0.0243902439; // Rotate by shift
	u = fract(u) * 6.28318530718; // 2*pi
	return vec2(cos(u), sin(u));
}

//
// 2-D tiling simplex noise with rotating gradients and analytical derivative.
// The first component of the 3-element return vector is the noise value,
// and the second and third components are the x and y partial derivatives.
//
// Note: This function has been modified for the use of this shader in particular.

float psnoise(vec2 pos, vec2 per, vec2 offset) {
	// Hack: offset y slightly to hide some rare artifacts
	pos.y += 0.01;
	
	// Skew to hexagonal grid
	vec2 uv = vec2(pos.x + pos.y*0.5, pos.y);
	vec2 i0 = floor(uv);
	vec2 f0 = fract(uv);
	
	// Traversal order
	vec2 i1 = (f0.x > f0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	
	// Unskewed grid points in (x,y) space
	vec2 p0 = vec2(i0.x - i0.y * 0.5, i0.y);
	vec2 p1 = vec2(p0.x + i1.x - i1.y * 0.5, p0.y + i1.y);
	vec2 p2 = vec2(p0.x + 0.5, p0.y + 1.0);
	
	// Integer grid point indices in (u,v) space
	i1 = i0 + i1;
	vec2 i2 = i0 + vec2(1.0, 1.0);
	// Vectors in unskewed (x,y) coordinates from
	// each of the simplex corners to the evaluation point
	vec2 d0 = pos - p0;
	vec2 d1 = pos - p1;
	vec2 d2 = pos - p2;

	// Wrap i0, i1 and i2 to the desired period before gradient hashing:
	// wrap points in (x,y), map to (u,v)
	vec3 xw = mod(vec3(p0.x, p1.x, p2.x), per.x) + vec3(offset.x);
	vec3 yw = mod(vec3(p0.y, p1.y, p2.y), per.y) + vec3(offset.y);
	vec3 iuw = xw + 0.5 * yw;
	vec3 ivw = yw;
	
	// Create gradients from indices
	vec2 g0 = rgrad2(vec2(iuw.x, ivw.x));
	vec2 g1 = rgrad2(vec2(iuw.y, ivw.y));
	vec2 g2 = rgrad2(vec2(iuw.z, ivw.z));
	
	// Gradients dot vectors to corresponding corners
	// (The derivatives of this are simply the gradients)
	vec3 w = vec3(dot(g0, d0), dot(g1, d1), dot(g2, d2));
	
	// Radial weights from corners
	// 0.8 is the square of 2/sqrt(5), the distance from
	// a grid point to the nearest simplex boundary
	vec3 t = 0.8 - vec3(dot(d0, d0), dot(d1, d1), dot(d2, d2));
	
	// Set influence of each surflet to zero outside radius sqrt(0.8)
	if(t.x < 0.0) {t.x = 0.0;}
	if(t.y < 0.0) {t.y = 0.0;}
	if(t.z < 0.0) {t.z = 0.0;}
	
	// Fourth power of t
	vec3 t2 = t * t;
	vec3 t4 = t2 * t2;
	
	// Final noise value is:
	// sum of ((radial weights) times (gradient dot vector from corner))
	float n = dot(t4, w);
	
	return 11.0*n;
}


vec4 FAST32_hash_2D_Cell(vec2 gridcell) {
	// generates 4 different random numbers for the single given cell point
	// gridcell is assumed to be an integer coordinate
	vec2 OFFSET = vec2(26.0, 161.0);
	float DOMAIN = 71.0;
	vec4 SOMELARGEFLOATS = vec4(951.135664, 642.949883, 803.202459, 986.973274);
	vec2 P = gridcell - floor(gridcell * (1.0 / DOMAIN)) * DOMAIN;
	P += OFFSET.xy;
	P *= P;
	return fract((P.x * P.y) * (1.0 / SOMELARGEFLOATS.xyzw));
}

float Cellular2D(vec2 xy, float tiling, vec2 offset) {
	int xi = int(floor(xy.x));
	int yi = int(floor(xy.y));
	
	float xf = xy.x - float(xi);
	float yf = xy.y - float(yi);
	
	float dist1 = 9999999.0;
	vec2 cell;
	
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			cell = FAST32_hash_2D_Cell(mod(vec2(ivec2(xi + x, yi + y)), tiling) + offset).xy;
			cell.x += (float(x) - xf);
			cell.y += (float(y) - yf);
			float dist = sqrt(dot(cell, cell));
			if (dist < dist1) {
				dist1 = dist;
			}
		}
	}
	
	return dist1;
}

float worley(vec2 pos, float tiling, vec2 offset, float amp) {return Cellular2D(pos * tiling, tiling, offset) * amp;}
float invertedWorley(vec2 pos, float tiling, vec2 offset, float amp) {return 1.0 - worley(pos, tiling, offset, amp);}


float remap(float o_value, float o_min, float o_max, float n_min, float n_max) {
	return n_min + (((o_value - o_min) / (o_max - o_min)) * (n_max - n_min));
}

float saturate(float value) {
	return clamp(value, 0.0, 1.0);
}

vec3 weather(vec3 random, vec2 pos) {
	
	float simplex_noise = 0.0;
	simplex_noise += 1.0 * psnoise(pos * 2.0, vec2(2.0), random.xy);
	simplex_noise += 0.2 * psnoise(pos * 9.0, vec2(9.0), random.xy);
	simplex_noise += 0.09 * psnoise(pos * 18.0, vec2(18.0), random.xy);
	simplex_noise += 0.05 * psnoise(pos * 24.0, vec2(24.0), random.xy);
	simplex_noise = simplex_noise * 0.5 + 0.5;
	
	float cell = 0.0;
	cell += 1.0 * invertedWorley(pos, 4.0, random.xy, random.z + 1.0);
	cell += 0.4 * invertedWorley(pos, 9.0, random.xy, random.z + 1.0);
	cell += 0.1 * invertedWorley(pos, 19.0, random.xy, random.z + 1.0);
	
	float coverage = remap(saturate(simplex_noise / 1.34), saturate(1.0 - cell / 1.5), 1.0, 0.0, 1.0);
	coverage = saturate(coverage * 0.55 + 0.65);
	
	float density = 0.0;
	density += invertedWorley(pos, 1.0, random.xy, random.z + 3.0);
	density *= coverage;
	
	float type_high = invertedWorley((pos + vec2(-142.214, 8434.345)) * 2.0, 1.0, random.xy, random.z + 2.5);
	type_high += invertedWorley((pos + vec2(-142.214, 8434.345)) * 1.0, 1.0, random.xy, random.z + 2.5);
	type_high = remap(saturate(simplex_noise / 1.34), saturate(1.0 - min(type_high, 1.0)), 1.0, 0.0, 1.0);
	type_high = smoothstep(0.1, 0.6, type_high) * 0.5;
	
	float type_med = invertedWorley((pos + vec2(1236.1234, -74.4356)) * 0.3, 1.0, random.xy, random.z);
	type_med = remap(saturate(simplex_noise / 1.34), saturate(1.0 - type_med), 1.0, 0.0, 1.0);
	
	float type_med2 = remap(saturate(simplex_noise / 1.34), saturate(1.0 - type_med), 1.0, 0.0, 1.0);
	type_med = (smoothstep(0.1, 0.6, type_med) + smoothstep(0.1, 0.6, type_med2)) * 0.5;
	
	float type = saturate(type_med + type_high);
	
	return vec3(coverage, type, density);
}

void fragment() {
	vec3 weather = weather(Randomness, (SCREEN_UV+Randomness.xy*2.0));
	COLOR = vec4(weather, 1.0);
}