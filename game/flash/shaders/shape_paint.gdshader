shader_type canvas_item;
render_mode blend_mix;
#define CUSTOM_VERTEX
#include "shape_common.gdshaderinc"

// A shape under an object with a paint (FlashDisplayObject.paint): a texture laid over the stage (paint_transform)
// composited onto what the shape draws with hardlight, inside the shape's own pixels. The texture is found from the
// shape's own coordinates (paint_row0 / paint_row1: shape-local -> paint UV, set by the runtime every tick), so it
// stays right inside render targets (masks, groups) and sticks to the shape. Marks painted onto her skin (the
// spankanywhere plugin) stay continuous over the parts her skin is made of.
uniform sampler2D paint : filter_linear;
uniform vec3 paint_row0 = vec3(0.0);
uniform vec3 paint_row1 = vec3(0.0);
varying vec2 paint_uv;

void vertex() {
	flash_modulate = COLOR;
	vec3 v = vec3(VERTEX, 1.0);
	paint_uv = vec2(dot(paint_row0, v), dot(paint_row1, v));
}

float hardlight1(float s, float b) {
	return s < 0.5 ? 2.0 * b * s : 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
}

void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), flash_modulate);
	vec4 p = texture(paint, paint_uv);   // premultiplied (a render target)
	if (p.a > 0.001) {
		vec3 s = clamp(p.rgb / p.a, 0.0, 1.0);
		c.rgb = mix(c.rgb, vec3(hardlight1(s.r, c.r), hardlight1(s.g, c.g), hardlight1(s.b, c.b)), p.a);
	}
	COLOR = c;
}
