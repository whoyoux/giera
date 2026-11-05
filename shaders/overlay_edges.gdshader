shader_type canvas_item;
render_mode blend_premul_alpha;

// Obraz 3D z przezroczystym tlem. Silnik rozjasnia kolory juz po wygladzeniu krawedzi, wiec
// polprzezroczyste piksele na brzegu modelu wychodza za jasne i tworza biala obwodke.
// Przyciemnienie ich o krzywa jasnosci przywraca wlasciwy kolor brzegu.
const float EDGE_CURVE = 0.545;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	pixel.rgb *= pow(max(pixel.a, 0.0001), EDGE_CURVE);
	COLOR = pixel;
}
