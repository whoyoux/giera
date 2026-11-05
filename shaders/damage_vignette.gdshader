// Czerwona poswiata na krawedziach ekranu przy trafieniu i przy niskim zdrowiu.
shader_type canvas_item;

uniform float hit : hint_range(0.0, 1.0) = 0.0;
uniform float low_health : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.86, 0.12, 0.16);

void fragment() {
	vec2 centered = (UV - 0.5) * vec2(1.0, 0.82);
	float distance_from_center = length(centered) * 2.0;
	float hit_edge = smoothstep(0.58, 1.2, distance_from_center);
	float low_edge = smoothstep(0.7, 1.25, distance_from_center);
	float amount = max(hit_edge * hit, low_edge * low_health * 0.75);
	COLOR = vec4(tint, amount * 0.75);
}
