shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Smuga swiatla nad lootem: mocna przy ziemi, a ku gorze zanika.
uniform vec3 color : source_color = vec3(1.0);
uniform float height = 1.0;
uniform float strength = 0.55;

varying float along;

void vertex() {
	along = VERTEX.y / height + 0.5;
}

void fragment() {
	float pulse = 0.85 + sin(TIME * 2.4) * 0.15;
	ALBEDO = color;
	ALPHA = strength * pulse * pow(1.0 - clamp(along, 0.0, 1.0), 1.8);
}
