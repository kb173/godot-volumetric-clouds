shader_type canvas_item;

uniform sampler2D Tex;

void fragment() {
	COLOR = texture(Tex, SCREEN_UV);
}