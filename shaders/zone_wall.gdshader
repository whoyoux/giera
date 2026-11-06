// Sciana strefy: pasy plyna w gore i zanikaja ku gorze, a od srodka i z zewnatrz wyglada tak samo.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.55, 0.42, 1.0);

void fragment() {
	float bands = 0.5 + 0.5 * sin(UV.y * 90.0 + TIME * 2.2);
	float fade = smoothstep(0.0, 0.35, UV.y);
	ALBEDO = tint;
	ALPHA = (0.2 + bands * 0.16) * fade;
}
