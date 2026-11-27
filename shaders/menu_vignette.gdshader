shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.04, 0.045, 0.06, 1.0);
uniform vec4 vignette_color : source_color = vec4(0.01, 0.012, 0.018, 1.0);
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.85;
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.45;
uniform float breathing_speed : hint_range(0.0, 5.0) = 0.6;
uniform float breathing_strength : hint_range(0.0, 0.2) = 0.025;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	
	// Slow, subtle atmospheric pulse
	float pulse = sin(TIME * breathing_speed) * breathing_strength;
	float vig = smoothstep(vignette_radius + pulse, 0.85, dist) * vignette_intensity;
	
	vec4 col = mix(base_color, vignette_color, vig);
	COLOR = col;
}
