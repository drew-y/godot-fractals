shader_type canvas_item;

//////////////////////
// Raymarch Config
//////////////////////
uniform int max_steps = 100;
uniform float min_hit_dist = 0.001;
uniform float max_trace_dist = 500.0;
uniform float darkness = 35.0;

//////////////////////
// MandleBulb Config
//////////////////////
uniform int mandlebulb_iterations = 15;
uniform float mandlebulb_sale = 0.5;

// Adapted from: http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
float mandle_bulb_distance(vec3 pos, float time) {
	vec3 z = pos;
	float dr = 1.;
	float r = 0.0;
    float power = 1.0 + time / 15.;

	for (int i = 0; i < mandlebulb_iterations ; i++) {
		r = length(z);
		if (r > 2.) break;

		// convert to polar coordinates
        float theta = asin( z.z/r );
        float phi = atan( z.y,z.x );
		dr =  pow(r, power - 1.0) * power * dr + 1.0;

		// scale and rotate the point
		float zr = pow(r, power);
		theta = theta * power;
		phi = phi * power;

		// convert back to cartesian coordinates
		z = zr * vec3(cos(theta) * cos(phi), cos(theta) * sin(phi), sin(theta));
		z += pos;
	}

	return mandlebulb_sale * log(r) * r / dr;
}

float world(vec3 pos, float time) {
    return mandle_bulb_distance(pos, time);
}

vec3 normal_of_pos(vec3 pos, float time) {
    const vec3 step = vec3(0.001, 0.0, 0.0);

    float gradX = world(pos + step.xyy, time) - world(pos - step.xyy, time);
    float gradY = world(pos + step.yxy, time) - world(pos - step.yxy, time);
    float gradZ = world(pos + step.yyx, time) - world(pos - step.yyx, time);

    vec3 normal = vec3(gradX, gradY, gradZ);

    return normalize(normal);
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

        float dist_to_closest = mandle_bulb_distance(cur_pos, time);
        
        // Hit
        if (dist_to_closest < min_hit_dist) {
            vec3 normal = normal_of_pos(cur_pos, time);
            vec3 light_pos = vec3(1., 2., 3.);
            vec3 light_dir = normalize(cur_pos - light_pos);
            float diffuse_intensity = max(0.0, dot(normal, light_dir));
            color = sin(time / 7. + cur_pos.zyx + vec3(1.4,0.7,10.1)) * diffuse_intensity;
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
    return color * rim;
}

void fragment() {
	// Camera position is also our ray origin
    vec3 cam_pos = vec3(-.7, -.5, -2.);
	vec3 look_at = vec3(0.0);
    vec3 ray_dir = get_ray_dir(UV, cam_pos, look_at, 0.75);

    // Time varying pixel color
    vec3 col = ray_march(cam_pos, ray_dir, UV, TIME);

    COLOR = vec4(col,1.0);
}