shader_type canvas_item;

uniform sampler2D Tex1;
uniform sampler2D Tex2;
uniform float Blend;

void fragment() {
	COLOR = mix(texture(Tex1, SCREEN_UV), texture(Tex2, SCREEN_UV), Blend);
}