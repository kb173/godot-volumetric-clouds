shader_type canvas_item;

uniform sampler2D tex_1;
uniform sampler2D tex_2;
uniform float blend;

void fragment() {
	COLOR = mix(texture(tex_1, SCREEN_UV), texture(tex_2, SCREEN_UV), blend);
}