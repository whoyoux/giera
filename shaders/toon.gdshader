// Kreskowkowy shader low-poly: plaskie cieniowanie scianek i twarde pasy swiatla.
shader_type spatial;
render_mode cull_back;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float shade_level : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Normalna liczona per trojkat daje wyrazne, plaskie scianki.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
}

void light() {
	float amount = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = 0.0;
	if (amount > 0.42) {
		band = 1.0;
	} else if (amount > 0.08) {
		band = shade_level;
	}
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
