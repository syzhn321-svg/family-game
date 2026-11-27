shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.96, 0.88, 0.05);
uniform float beam_length = 8.0;
uniform float max_beam_dist = 8.0;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.2;
uniform float beam_energy = 1.0;

varying float v_dist_ratio;
varying float v_dist_meters;

void vertex() {
	// Bottom of cylinder (-beam_length*0.5) is at flashlight lens (0.0 meters)
	// Top of cylinder (+beam_length*0.5) is in the distance (+beam_length meters)
	v_dist_meters = VERTEX.y + (beam_length * 0.5);
	v_dist_ratio = clamp(v_dist_meters / beam_length, 0.0, 1.0);
}

void fragment() {
	// Softly fade to zero right before hitting any solid wall or obstacle
	float wall_fade = clamp((max_beam_dist - v_dist_meters) / 0.35, 0.0, 1.0);
	
	// Longitudinal falloff: bright near the source, smoothly fades to 0 at tip
	float dist_fade = pow(1.0 - v_dist_ratio, 2.0);
	
	// Soft fade right near the lens to avoid harsh clipping at the glass
	float lens_fade = smoothstep(0.0, 0.08, v_dist_ratio);
	
	// Fresnel edge falloff: creates soft, misty volumetric cone boundaries
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);
	
	// Core volume so the beam looks tangible even when looking straight down the axis
	float core = fresnel * 0.7 + 0.3;
	
	// Soft camera near-plane fade: eliminates harsh clipping, polygon slicing, and glitchy flashing when pointed at other player's head/camera
	float cam_dist = length(VERTEX);
	float camera_near_fade = smoothstep(0.18, 0.60, cam_dist);
	
	float final_alpha = lens_fade * dist_fade * core * beam_color.a * beam_energy * wall_fade * camera_near_fade;
	
	ALBEDO = beam_color.rgb;
	ALPHA = clamp(final_alpha, 0.0, 1.0);
}
