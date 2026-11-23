// Blend modes that read the backdrop (a BackBufferCopy is placed in front of the blended object): shapes
// (shape_screen.gdshader) and Graphics fills (graphics_fill_screen.gdshader).
uniform sampler2D backdrop : hint_screen_texture, filter_linear;
uniform int mode = 0; // 0 overlay, 1 hardlight, 2 screen, 3 lighten, 4 darken, 5 difference, 6 invert

float overlay1(float b, float s) {
	return b < 0.5 ? 2.0 * b * s : 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
}

// c: the object's colour (straight alpha); b: the backdrop.
vec3 screen_blend(vec3 b, vec3 c) {
	if (mode == 0) {
		return vec3(overlay1(b.r, c.r), overlay1(b.g, c.g), overlay1(b.b, c.b));
	} else if (mode == 1) {
		return vec3(overlay1(c.r, b.r), overlay1(c.g, b.g), overlay1(c.b, b.b));
	} else if (mode == 2) {
		return 1.0 - (1.0 - b) * (1.0 - c);
	} else if (mode == 3) {
		return max(b, c);
	} else if (mode == 4) {
		return min(b, c);
	} else if (mode == 5) {
		return abs(b - c);
	}
	return 1.0 - b;
}
