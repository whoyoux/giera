// Zaokragla rogi obrazka, zeby awatar pasowal do naklejek w interfejsie.
shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.18;

void fragment() {
	vec2 corner = abs(UV - 0.5) - (0.5 - radius);
	float distance_to_edge = length(max(corner, 0.0)) - radius;
	float softness = fwidth(distance_to_edge);
	COLOR.a *= 1.0 - smoothstep(-softness, softness, distance_to_edge);
}
