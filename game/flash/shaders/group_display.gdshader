shader_type canvas_item;
render_mode blend_premul_alpha;
// Draws an offscreen group's render target (premultiplied) and applies Flash filters:
// Blur, DropShadow / Glow (outer, inner, knockout, hideObject). Offsets / sizes are in texture pixels.
uniform int mode = 0;               // 0 passthrough, 1 blur, 2 shadow / glow
uniform vec2 blur_px = vec2(0.0);
uniform float passes = 1.0;
uniform vec2 offset_px = vec2(0.0);
uniform vec4 shadow_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 1.0;
uniform bool inner = false;
uniform bool knockout = false;
uniform bool hide_object = false;
// Blend mode of the grouped object itself, applied against the backdrop (a BackBufferCopy precedes the group):
// 0 normal, 1 overlay, 2 hardlight, 3 screen, 4 lighten, 5 darken, 6 difference, 7 invert, 8 multiply, 9 add,
// 10 subtract.
uniform int blend_mode = 0;
uniform sampler2D backdrop : hint_screen_texture, filter_linear;
// Port: a cut (FlashGroupProxy.set_cut): what lies inside rect A and outside rect B is not drawn here (it stays in
// the render target, which an extension may draw elsewhere). Each rect (x0, y0, x1, y1) is in its own space, reached
// from the group's local space by the affine map (columns x, y, origin).
uniform bool cut_on = false;
uniform vec2 cut_a_x = vec2(1.0, 0.0);
uniform vec2 cut_a_y = vec2(0.0, 1.0);
uniform vec2 cut_a_o = vec2(0.0);
uniform vec4 cut_a = vec4(0.0);
uniform vec2 cut_b_x = vec2(1.0, 0.0);
uniform vec2 cut_b_y = vec2(0.0, 1.0);
uniform vec2 cut_b_o = vec2(0.0);
uniform vec4 cut_b = vec4(0.0);

float overlay1(float b, float s) {
	return b < 0.5 ? 2.0 * b * s : 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
}

vec3 blend_rgb(vec3 b, vec3 s) {
	if (blend_mode == 1) return vec3(overlay1(b.r, s.r), overlay1(b.g, s.g), overlay1(b.b, s.b));
	if (blend_mode == 2) return vec3(overlay1(s.r, b.r), overlay1(s.g, b.g), overlay1(s.b, b.b));
	if (blend_mode == 3) return 1.0 - (1.0 - b) * (1.0 - s);
	if (blend_mode == 4) return max(b, s);
	if (blend_mode == 5) return min(b, s);
	if (blend_mode == 6) return abs(b - s);
	if (blend_mode == 7) return 1.0 - b;
	if (blend_mode == 8) return b * s;
	if (blend_mode == 9) return min(b + s, 1.0);
	if (blend_mode == 10) return max(b - s, 0.0);
	return s;
}

// Fragment COLOR starts as texture * modulate; keep the modulate alone from the vertex stage.
varying vec4 modulate;
varying vec2 local_pos;

void vertex() {
	modulate = COLOR;
	local_pos = VERTEX;
}

bool inside(vec2 p, vec4 r) {
	return p.x >= r.x && p.y >= r.y && p.x <= r.z && p.y <= r.w;
}

void fragment() {
	if (cut_on) {
		vec2 a = cut_a_x * local_pos.x + cut_a_y * local_pos.y + cut_a_o;
		vec2 b = cut_b_x * local_pos.x + cut_b_y * local_pos.y + cut_b_o;
		if (inside(a, cut_a) && !inside(b, cut_b)) {
			discard;
		}
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	vec4 r = c;
	// Gaussian blur of the source (mode 1) or of the offset shadow source (mode 2); TEXTURE cannot be passed to a
	// helper function, so the loop lives here.
	vec4 blur = vec4(0.0);
	if (mode != 0) {
		vec2 base_uv = mode == 2 ? UV - offset_px * px : UV;
		vec2 sigma = max(blur_px * sqrt(passes) / 3.4641, vec2(0.001));
		float wsum = 0.0;
		for (int y = -4; y <= 4; y++) {
			for (int x = -4; x <= 4; x++) {
				vec2 o = vec2(float(x), float(y)) / 4.0;
				float w = exp(-dot(o, o) * 4.5);
				blur += texture(TEXTURE, base_uv + o * sigma * 3.0 * px) * w;
				wsum += w;
			}
		}
		blur /= wsum;
	}
	if (mode == 1) {
		r = blur;
	} else if (mode == 2) {
		float a = blur.a;
		if (inner) {
			float ia = clamp((1.0 - a) * strength, 0.0, 1.0) * c.a * shadow_color.a;
			vec4 sh = vec4(shadow_color.rgb * ia, ia);
			r = knockout ? sh : sh + c * (1.0 - ia);
		} else {
			float oa = clamp(a * strength, 0.0, 1.0) * shadow_color.a;
			vec4 sh = vec4(shadow_color.rgb * oa, oa);
			r = knockout ? sh * (1.0 - c.a) : (hide_object ? sh : c + sh * (1.0 - c.a));
		}
	}
	// premultiplied output, scaled by the group's modulate (Flash alpha / multipliers of the composite)
	vec4 o = vec4(r.rgb * modulate.rgb, r.a) * modulate.a;
	if (blend_mode != 0 && o.a > 0.0) {
		vec3 b = texture(backdrop, SCREEN_UV).rgb;
		o.rgb = blend_rgb(b, o.rgb / o.a) * o.a;
	}
	COLOR = o;
}
