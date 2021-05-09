shader_type canvas_item;

//////////////////////
// Raymarch Config
//////////////////////
uniform int max_steps = 25;
uniform float min_hit_dist = 0.001;
uniform float max_trace_dist = 200.0;
uniform float darkness = 12.0;

//////////////////////
// MandleBulb Config
//////////////////////
uniform int mandlebulb_iterations = 15;
uniform float mandlebulb_sale = 0.5;

vec3 saturate(vec3 color) {
	return clamp(color, 0.0, 1.0);
}

// Adapted from: http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
vec2 mandle_bulb_distance(vec3 pos, float time) {
	vec3 z = pos;
	float dr = 1.;
	float r = 0.0;
    float power = 1.0 + abs(sin(time / 25.0) * 20.0);
	
	int iterations = 0;
	while (iterations < mandlebulb_iterations) {
		r = length(z);
		if (r > 2.) break;

		// convert to polar coordinates
        float theta = acos(z.z / r);
        float phi = atan(z.y, z.x);
		dr = pow(r, power - 1.0) * power * dr + 1.0;

		// scale and rotate the point
		float zr = pow(r, power);
		theta = theta * power;
		phi = phi * power;

		// convert back to cartesian coordinates
		z = zr * vec3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
		z += pos;
		iterations += 1;
	}
	
	float dist = mandlebulb_sale * log(r) * r / dr;
	return vec2(dist, float(iterations));
}

float world(vec3 pos, float time) {
    return mandle_bulb_distance(pos, time).x;
}

vec3 normal_of_pos(vec3 pos, float time) {
    const vec3 step = vec3(0.001, 0.0, 0.0);

    float gradX = world(pos + step.xyy, time) - world(pos - step.xyy, time);
    float gradY = world(pos + step.yxy, time) - world(pos - step.yxy, time);
    float gradZ = world(pos + step.yyx, time) - world(pos - step.yyx, time);

    vec3 normal = vec3(gradX, gradY, gradZ);

    return -normalize(normal);
}

vec3 get_ray_dir(vec2 uv, vec3 cam_pos, vec3 look_at, float zoom) {
    vec3 f = normalize(look_at - cam_pos);
    vec3 r = cross(vec3(0.0, 1.0, 0.0), f);
    vec3 u = cross(f, r);
    vec3 c = cam_pos + f * zoom;
    vec3 i = c + uv.x * r + uv.y * u;
    return normalize(i - cam_pos);
}

// Adapted from https://michaelwalczyk.com/blog-ray-marching.html
vec3 ray_march(vec3 ray_origin, vec3 ray_dir, vec2 uv, float time) {
    float total_dist_traveled = 0.0;
    
	vec3 color = mix(sin(time / 7. + vec3(1.4,0.7,10.1)), vec3(uv.x), vec3(uv.y)) * 0.3;
    
    int steps = 0;
    while (steps < max_steps) {
        // Calculate our current position along the ray
        vec3 cur_pos = ray_origin + total_dist_traveled * ray_dir;

        vec2 info = mandle_bulb_distance(cur_pos, time);
		float dist_to_closest = info.x;
		float iterations = info.y;
        
        // Hit
        if (dist_to_closest < min_hit_dist) {
			vec3 normal = normal_of_pos(cur_pos, time);
			vec3 light_pos = vec3(-4.0, -3.0, 0.0);
			vec3 light_dir = normalize(cur_pos - light_pos);
			float diffuse_intensity = clamp(dot(normal * 0.2 + 0.3, light_dir), 0.0, 1.0);
			vec3 colorA = sin(time / 7. + cur_pos.zyx + vec3(1.4,0.7,10.1)) * diffuse_intensity;
			vec3 colorB = vec3(0.0, 0.0, 0.2) * clamp(iterations / 16.0, 0.0, 1.0);
			color = saturate(colorA + colorB);
			break;
        }
        
        // Miss
        if (total_dist_traveled > max_trace_dist) break;

        // accumulate the distance traveled thus far
        total_dist_traveled += dist_to_closest;
        
        steps += 1;
    }
	
	
    // Inspired by https://github.com/SebLague/Ray-Marching/blob/f7e44c15a212dec53b244b1f53cdaf318f6ec700/Assets/Scripts/Fractal/Fractal.compute
    float rim = float(steps) / darkness;
    return mix(color, vec3(0.6), 0.03) * rim;
}

void fragment() {
	// Camera position is also our ray origin
    vec3 cam_pos = vec3(-8, 0.0, -5.0);
	vec3 look_at = vec3(1.5, 0.0, 0.0);
	vec2 uv = UV - vec2(0.5);
    vec3 ray_dir = get_ray_dir(uv, cam_pos, look_at, 7.0);

    // Time varying pixel color
    vec3 col = ray_march(cam_pos, ray_dir, UV, TIME);

    COLOR = vec4(col,1.0);
}