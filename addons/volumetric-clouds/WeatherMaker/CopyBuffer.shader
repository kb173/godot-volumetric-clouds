shader_type canvas_item;

uniform sampler2D tex;

void fragment() {
	COLOR = texture(tex, SCREEN_UV);
}