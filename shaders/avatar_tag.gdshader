// Awatar nad glowa gracza: zawsze przodem do kamery, z zaokraglonymi rogami i biala ramka jak naklejka.
// Widac go przez sciany, tak samo jak nazwe pod spodem.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
uniform float radius : hint_range(0.0, 0.5) = 0.22;
uniform float border : hint_range(0.0, 0.5) = 0.07;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 corner = abs(UV - 0.5) - (0.5 - radius);
	float distance_to_edge = length(max(corner, 0.0)) - radius;
	float softness = fwidth(distance_to_edge);
	float frame = smoothstep(-border - softness, -border + softness, distance_to_edge);
	ALBEDO = mix(texture(picture, UV).rgb, vec3(1.0), frame);
	ALPHA = 1.0 - smoothstep(-softness, softness, distance_to_edge);
}
