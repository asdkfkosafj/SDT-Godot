// flash.display.Graphics fills: solid, linear, radial and focal-radial gradients ("pad" spread, rgb interp).
// graphics_fill.gdshader; graphics_fill_screen.gdshader (SCREEN_BLEND) for fills under an overlay / hardlight /
// screen ... blend (her neck's tan).
#define CUSTOM_VERTEX
#include "shape_common.gdshaderinc"
#ifdef SCREEN_BLEND
#include "screen_blend.gdshaderinc"
#endif

uniform int fill_mode = 0;             // 0 solid, 1 linear, 2 radial
uniform vec4 solid : source_color = vec4(1.0);
uniform mat3 inv_matrix = mat3(1.0);   // object space -> gradient space (gradient box is -819.2..819.2)
uniform float focal = 0.0;
uniform int stop_count = 2;
uniform vec4 stop_colors[8];
uniform float stop_ratios[8];          // 0..1

varying vec2 gpos;

void vertex() {
	flash_modulate = COLOR;
	gpos = (inv_matrix * vec3(VERTEX, 1.0)).xy / 819.2;
}

vec4 ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	if (t <= stop_ratios[0]) return stop_colors[0];
	for (int i = 1; i < 8; i++) {
		if (i >= stop_count) break;
		if (t <= stop_ratios[i]) {
			float span = max(stop_ratios[i] - stop_ratios[i - 1], 1e-5);
			return mix(stop_colors[i - 1], stop_colors[i], (t - stop_ratios[i - 1]) / span);
		}
	}
	return stop_colors[stop_count - 1];
}

void fragment() {
	vec4 c;
	if (fill_mode == 0) {
		c = solid;
	} else if (fill_mode == 1) {
		c = ramp(gpos.x * 0.5 + 0.5);
	} else {
		vec2 f = vec2(focal, 0.0);
		vec2 d = gpos - f;
		float len = length(d);
		float t = 0.0;
		if (len > 1e-6) {
			vec2 dir = d / len;
			float b = dot(f, dir);
			float s = -b + sqrt(max(b * b - (dot(f, f) - 1.0), 0.0));
			t = len / max(s, 1e-6);
		}
		c = ramp(t);
	}
	c = flash_color(c, flash_modulate);
#ifdef SCREEN_BLEND
	c.rgb = screen_blend(texture(backdrop, SCREEN_UV).rgb, c.rgb);
#endif
	COLOR = c;
}
