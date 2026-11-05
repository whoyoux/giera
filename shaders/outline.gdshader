// Ciemny kontur metoda "inverted hull". Wymaga siatki wycentrowanej w (0,0,0).
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 color : source_color = vec3(0.12, 0.09, 0.16);
uniform float width = 0.02;

void vertex() {
	VERTEX += normalize(VERTEX) * width;
}

void fragment() {
	ALBEDO = color;
}
