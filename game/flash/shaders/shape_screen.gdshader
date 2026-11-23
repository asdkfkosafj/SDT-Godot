shader_type canvas_item;
render_mode blend_mix;
#include "shape_common.gdshaderinc"
#include "screen_blend.gdshaderinc"

void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), flash_modulate);
	COLOR = vec4(screen_blend(texture(backdrop, SCREEN_UV).rgb, c.rgb), c.a);
}
