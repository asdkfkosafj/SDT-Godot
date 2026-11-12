#include "sdt_native.h"

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/transform2d.hpp>

#include <algorithm>
#include <unordered_map>
#include <cstring>
#include <cmath>
#include <vector>

void SDTNative::_bind_methods() {
	ClassDB::bind_static_method("SDTNative",
			D_METHOD("build_strand", "pos", "thickness", "density", "has_stored", "stored", "rgb", "alpha",
					"max_interp_dist"),
			&SDTNative::build_strand);
	ClassDB::bind_static_method("SDTNative", D_METHOD("hit_shape", "obj", "point", "hb_gen"), &SDTNative::hit_shape);
	ClassDB::bind_static_method("SDTNative", D_METHOD("hit_shape_excluding", "obj", "point", "hb_gen", "exclude"),
			&SDTNative::hit_shape_excluding);
	ClassDB::bind_static_method("SDTNative", D_METHOD("hit_flat", "obj", "point", "tick"), &SDTNative::hit_flat);
	ClassDB::bind_static_method("SDTNative", D_METHOD("scale_alpha", "image", "rect", "mult"), &SDTNative::scale_alpha);
	ClassDB::bind_static_method("SDTNative", D_METHOD("draw_image", "dst", "src", "to_src", "rect", "mult", "offset"),
			&SDTNative::draw_image);
}

void SDTNative::draw_image(const Ref<Image> &p_dst, const Ref<Image> &p_src, const Transform2D &p_to_src,
		const Rect2i &p_rect, const Color &p_mult, const Color &p_offset) {
	if (p_dst.is_null() || p_src.is_null() || p_dst->get_format() != Image::FORMAT_RGBA8 ||
			p_src->get_format() != Image::FORMAT_RGBA8) {
		return;
	}
	const int dw = p_dst->get_width();
	const Rect2i r = p_rect.intersection(Rect2i(0, 0, dw, p_dst->get_height()));
	if (r.size.x <= 0 || r.size.y <= 0) {
		return;
	}
	const int iw = p_src->get_width();
	const int ih = p_src->get_height();
	const uint8_t *src = p_src->ptr();
	uint8_t *dst = p_dst->ptrw();
	// premultiplied source pixel, transparent outside the image
	auto px = [&](int x, int y, float out[4]) {
		if (x < 0 || y < 0 || x >= iw || y >= ih) {
			out[0] = out[1] = out[2] = out[3] = 0.0f;
			return;
		}
		const uint8_t *s = src + ((int64_t)y * iw + x) * 4;
		const float a = s[3] / 255.0f;
		out[0] = s[0] / 255.0f * a;
		out[1] = s[1] / 255.0f * a;
		out[2] = s[2] / 255.0f * a;
		out[3] = a;
	};
	const float mult[4] = { p_mult.r, p_mult.g, p_mult.b, p_mult.a };
	const float off[4] = { p_offset.r, p_offset.g, p_offset.b, p_offset.a };
	for (int py = r.position.y; py < r.position.y + r.size.y; py++) {
		for (int pxx = r.position.x; pxx < r.position.x + r.size.x; pxx++) {
			const Vector2 l = p_to_src.xform(Vector2(pxx + 0.5f, py + 0.5f));
			const double ix = l.x;
			const double iy = l.y;
			if (ix < -1 || iy < -1 || ix > iw || iy > ih) {
				continue;
			}
			const int x0 = (int)std::floor(ix);
			const int y0 = (int)std::floor(iy);
			const float fx = (float)(ix - x0);
			const float fy = (float)(iy - y0);
			float c00[4], c10[4], c01[4], c11[4], c[4];
			px(x0, y0, c00);
			px(x0 + 1, y0, c10);
			px(x0, y0 + 1, c01);
			px(x0 + 1, y0 + 1, c11);
			for (int ch = 0; ch < 4; ch++) {
				c[ch] = c00[ch] * (1 - fx) * (1 - fy) + c10[ch] * fx * (1 - fy) + c01[ch] * (1 - fx) * fy + c11[ch] * fx * fy;
			}
			if (c[3] <= 0.0f) {
				continue;
			}
			for (int ch = 0; ch < 3; ch++) {
				c[ch] /= c[3];
			}
			for (int ch = 0; ch < 4; ch++) {
				c[ch] = std::clamp(c[ch] * mult[ch] + off[ch], 0.0f, 1.0f);
			}
			uint8_t *d = dst + ((int64_t)py * dw + pxx) * 4;
			const double sa = c[3];
			const double da = d[3] / 255.0;
			const double oa = sa + da * (1.0 - sa);
			if (oa <= 0.0) {
				continue;
			}
			for (int ch = 0; ch < 3; ch++) {
				const double v = (c[ch] * sa + d[ch] / 255.0 * da * (1.0 - sa)) / oa * 255.0 + 0.5;
				d[ch] = (uint8_t)std::clamp((int)v, 0, 255);
			}
			d[3] = (uint8_t)std::clamp((int)(oa * 255.0 + 0.5), 0, 255);
		}
	}
}

void SDTNative::scale_alpha(const Ref<Image> &p_image, const Rect2i &p_rect, double p_mult) {
	if (p_image.is_null() || p_image->get_format() != Image::FORMAT_RGBA8) {
		return;
	}
	const int w = p_image->get_width();
	const Rect2i r = p_rect.intersection(Rect2i(0, 0, w, p_image->get_height()));
	const int m = std::clamp((int)(p_mult * 256.0), 0, 256);
	if (r.size.x <= 0 || r.size.y <= 0 || m == 256) {
		return;
	}
	uint8_t *px = p_image->ptrw();
	for (int y = r.position.y; y < r.position.y + r.size.y; y++) {
		uint8_t *p = px + ((int64_t)y * w + r.position.x) * 4;
		for (int x = 0; x < r.size.x; x++, p += 4) {
			if (p[3] != 0) {
				p[3] = (uint8_t)((p[3] * m) >> 8);
				if (p[3] == 0) {
					p[0] = p[1] = p[2] = 0;
				}
			}
		}
	}
}

namespace {

// obj.Line: segment p1-p2 with implicit equation A x + B y = C.
struct Line {
	Vector2 p1, p2;
	double A() const { return p2.y - p1.y; }
	double B() const { return p1.x - p2.x; }
	double C() const { return (double)(p2.y - p1.y) * p1.x + (double)(p1.x - p2.x) * p1.y; }
};

// Maths.normal: projection of c onto the line through a and b.
Vector2 maths_normal(Vector2 a, Vector2 b, Vector2 c) {
	Vector2 ab(b.x - a.x, b.y - a.y);
	Vector2 ac(c.x - a.x, c.y - a.y);
	double t = ((double)ab.x * ac.x + (double)ab.y * ac.y) / ((double)ab.x * ab.x + (double)ab.y * ab.y);
	return Vector2(a.x + ab.x * t, a.y + ab.y * t);
}

// Strand._interPoint: control point where adjacent offset lines meet, clamped towards the midpoint.
Vector2 inter_point(const Line &l1, const Line &l2, Vector2 mid, Vector2 o1, Vector2 o2, double max_interp_dist) {
	double d = l1.A() * l2.B() - l2.A() * l1.B();
	if (d == 0) {
		return o1 + (o2 - o1) / 2.0;
	}
	double ix = (l2.B() * l1.C() - l1.B() * l2.C()) / d;
	double iy = (l1.A() * l2.C() - l2.A() * l1.C()) / d;
	Vector2 dv(ix - mid.x, iy - mid.y);
	double d2 = (double)dv.x * dv.x + (double)dv.y * dv.y;
	if (d2 > max_interp_dist) {
		dv *= max_interp_dist / d2;
		return mid + dv;
	}
	return Vector2(ix, iy);
}

// Two-stop linear gradient ("pad" spread) as FlashGraphics.beginGradientFill + graphics_fill.gdshader evaluate it.
struct Gradient {
	Transform2D inv; // object space -> gradient space
	float r0, r1;
	Color c0, c1;
	float t_at(Vector2 p) const {
		Vector2 g = inv.xform(p);
		return g.x / 819.2f * 0.5f + 0.5f;
	}
	Color color_at(float t) const {
		t = std::clamp(t, 0.0f, 1.0f);
		if (t <= r0) {
			return c0;
		}
		if (t >= r1) {
			return c1;
		}
		float span = std::max(r1 - r0, 1e-5f);
		return c0.lerp(c1, (t - r0) / span);
	}
};


// Copies a std::vector into a packed array in one resize + memcpy (element-wise push_back goes through the
// engine API and is slow).
template <typename P, typename T>
P to_packed(const std::vector<T> &v) {
	P out;
	out.resize((int64_t)v.size());
	if (!v.empty()) {
		memcpy(out.ptrw(), v.data(), v.size() * sizeof(T));
	}
	return out;
}

// Emits triangle (a, b, c) split along the gradient's stop lines t = r0 and t = r1, so per-vertex colour
// interpolation reproduces the piecewise-linear ramp exactly. Allocation-free: a triangle clipped by two parallel
// half-planes has at most 5 vertices.
struct TV {
	Vector2 p;
	float t;
	int id; // the corner's slot in VertexShare (-1: a point cut at a stop line)
};

// Shared vertices within one segment (one gradient: a point always gets the same colour there). Corners passed in
// are shared by slot: the same point, bit for bit. Cut points are computed per triangle (and in another order by
// the neighbour), so they are shared only with a recent cut point that is bit-identical in position and colour.
// What is drawn stays the same triangles with the same corner values; only duplicate vertices go.
struct VertexShare {
	static constexpr int SLOTS = 104; // ribbon 0-49 (24 steps at most), caps 50-75 and 77-102
	static constexpr int RECENT = 8;
	int32_t slot[SLOTS];
	int32_t recent[RECENT];
	int nrecent = 0, next = 0;
	void reset() {
		std::fill(slot, slot + SLOTS, -1);
		nrecent = 0;
		next = 0;
	}
	int32_t vertex(StrandMesh &m, const Gradient &g, const TV &v) {
		if (v.id >= 0 && slot[v.id] >= 0) {
			return slot[v.id];
		}
		Color c = g.color_at(v.t);
		if (v.id < 0) {
			for (int i = 0; i < nrecent; i++) {
				int32_t r = recent[i];
				if (memcmp(&m.points[r], &v.p, sizeof(Vector2)) == 0 && memcmp(&m.colors[r], &c, sizeof(Color)) == 0) {
					return r;
				}
			}
		}
		int32_t idx = (int32_t)m.points.size();
		m.points.push_back(v.p);
		m.colors.push_back(c);
		if (v.id >= 0) {
			slot[v.id] = idx;
		} else {
			recent[next] = idx;
			next = (next + 1) % RECENT;
			nrecent = std::min(nrecent + 1, RECENT);
		}
		return idx;
	}
};

static int clip_side(const TV *in, int n, TV *out, float edge, bool keep_above) {
	int m = 0;
	for (int i = 0; i < n; i++) {
		const TV &s = in[i];
		const TV &e = in[(i + 1) % n];
		bool si = keep_above ? s.t >= edge : s.t <= edge;
		bool ei = keep_above ? e.t >= edge : e.t <= edge;
		if (si) {
			out[m++] = s;
		}
		if (si != ei) {
			float k = (edge - s.t) / (e.t - s.t);
			out[m++] = { s.p + (e.p - s.p) * k, edge, -1 };
		}
	}
	return m;
}

void emit_triangle(StrandMesh &m, const Gradient &g, VertexShare &vs, int ia, Vector2 a, int ib, Vector2 b, int ic,
		Vector2 c) {
	TV tri[3] = { { a, g.t_at(a), ia }, { b, g.t_at(b), ib }, { c, g.t_at(c), ic } };
	float tmin = std::min(tri[0].t, std::min(tri[1].t, tri[2].t));
	float tmax = std::max(tri[0].t, std::max(tri[1].t, tri[2].t));
	const float bands[4] = { -INFINITY, g.r0, g.r1, INFINITY };
	for (int band = 0; band < 3; band++) {
		float lo = bands[band], hi = bands[band + 1];
		if (tmax < lo || tmin > hi) {
			continue;
		}
		TV buf1[6], buf2[6];
		const TV *poly = tri;
		int n = 3;
		if (tmin < lo) {
			n = clip_side(poly, n, buf1, lo, true);
			poly = buf1;
		}
		if (n >= 3 && tmax > hi) {
			n = clip_side(poly, n, buf2, hi, false);
			poly = buf2;
		}
		if (n < 3) {
			continue;
		}
		int32_t vi[5];
		for (int k = 0; k < n; k++) {
			vi[k] = vs.vertex(m, g, poly[k]);
		}
		for (int k = 1; k + 1 < n; k++) {
			m.indices.push_back(vi[0]);
			m.indices.push_back(vi[k]);
			m.indices.push_back(vi[k + 1]);
		}
	}
}

} // namespace

void sdt_append_strand_mesh(StrandMesh &mesh, const Vector2 *pos, const float *thick, const float *dens,
		const uint8_t *has_stored, const Vector2 *stored, int n, const Color &p_rgb, double p_alpha,
		double p_max_interp_dist) {
	if (n < 2) {
		return;
	}

	// --- Strand.generateInterpolationPoints
	std::vector<Vector2> dirs(std::max(n + 1, 2));
	for (int i = 0; i < n - 1; i++) {
		Vector2 d = pos[i + 1] - pos[i];
		if (!(d.x == 0 && d.y == 0)) {
			d /= std::sqrt(d.x * d.x + d.y * d.y);
		}
		dirs[i + 1] = d;
	}
	dirs[0] = dirs[1];
	dirs[n] = dirs[n - 1];
	std::vector<Vector2> in_off(n), out_off(n);
	std::vector<Line> in_line(n), out_line(n);
	Vector2 top_cap, bottom_cap;
	for (int i = 0; i < n; i++) {
		Vector2 l = pos[i];
		Vector2 nv = dirs[i + 1] + dirs[i];
		if (nv.x == 0 && nv.y == 0) {
			nv = dirs[i];
		}
		float t = thick[i];
		Vector2 inside(l.x - nv.y * t, l.y + nv.x * t);
		Vector2 outside(l.x + nv.y * t, l.y - nv.x * t);
		if (i == 0) {
			top_cap = Vector2(l.x - nv.x * t * 2.0f, l.y - nv.y * t * 2.0f);
		} else if (i == n - 1) {
			bottom_cap = Vector2(l.x + nv.x * t * 2.0f, l.y + nv.y * t * 2.0f);
		}
		in_off[i] = inside;
		out_off[i] = outside;
		in_line[i] = { inside + nv, inside - nv };
		out_line[i] = { outside + nv, outside - nv };
	}
	std::vector<Vector2> in_ip(n), out_ip(n);
	for (int i = 0; i < n - 1; i++) {
		if (has_stored && stored && has_stored[i]) {
			in_ip[i] = stored[i * 2];
			out_ip[i] = stored[i * 2 + 1];
			continue;
		}
		Vector2 a = pos[i], b = pos[i + 1];
		Vector2 mid((a.x + b.x) / 2.0f, (a.y + b.y) / 2.0f);
		if (i > 0 && i < n - 2) {
			in_ip[i] = inter_point(in_line[i], in_line[i + 1], mid, in_off[i], in_off[i + 1], p_max_interp_dist);
			out_ip[i] = inter_point(out_line[i], out_line[i + 1], mid, out_off[i], out_off[i + 1], p_max_interp_dist);
		} else if (i == 0) {
			in_ip[i] = maths_normal(in_line[1].p1, in_line[1].p2, mid);
			out_ip[i] = maths_normal(out_line[1].p1, out_line[1].p2, mid);
		} else if (i == n - 2) {
			in_ip[i] = maths_normal(in_line[n - 2].p1, in_line[n - 2].p2, mid);
			out_ip[i] = maths_normal(out_line[n - 2].p1, out_line[n - 2].p2, mid);
		}
	}

	// --- Strand.renderStrand. Flash draws each segment as a gradient-filled outline (inside curve, line, outside
	// curve back, plus the rounded caps) that has to be triangulated. The same outline is a ribbon: both curves are
	// sampled with the same parameter and joined as a triangle strip, and the caps are fans; no polygon
	// triangulation needed. Triangles are still split at the gradient's stops, so the colours match exactly.
	Color c_rgb(p_rgb.r, p_rgb.g, p_rgb.b, 1.0f);
	mesh.points.reserve(n * 64);
	mesh.colors.reserve(n * 64);
	mesh.indices.reserve(n * 128);
	auto bez = [](Vector2 p0, Vector2 c, Vector2 p1, float t) {
		float u = 1.0f - t;
		return p0 * (u * u) + c * (2.0f * u * t) + p1 * (t * t);
	};
	// as many steps as FlashGraphics.curveTo would flatten the curve into
	auto steps = [](Vector2 p0, Vector2 c, Vector2 p1) {
		return std::clamp((int)((p0.distance_to(c) + c.distance_to(p1)) / 3.0f), 2, 24);
	};
	VertexShare vs;
	// a cap: the region between the chord a-b and the curve a -> (via c) -> b, as a fan from the chord's midpoint;
	// its vertices use slots base (the midpoint), base + 1 (a) and base + 1 + j
	auto cap = [&](const Gradient &g, int base, Vector2 a, Vector2 c, Vector2 b) {
		int k = steps(a, c, b);
		Vector2 m = (a + b) * 0.5f;
		Vector2 prev = a;
		for (int j = 1; j <= k; j++) {
			Vector2 q = bez(a, c, b, (float)j / k);
			emit_triangle(mesh, g, vs, base, m, base + j, prev, base + 1 + j, q);
			prev = q;
		}
	};
	for (int i = 1; i < n; i++) {
		Vector2 cur = pos[i], prev = pos[i - 1];
		Vector2 d(cur.x - prev.x, cur.y - prev.y);
		float size = std::max(std::abs(d.x), std::abs(d.y));
		// FlashGraphics.createGradientBox(size, size, atan2(d.y, d.x), min x, min y)
		float rot = std::atan2(d.y, d.x);
		float cs = std::cos(rot), sn = std::sin(rot);
		Transform2D box(Vector2(cs * size / 1638.4f, sn * size / 1638.4f), Vector2(-sn * size / 1638.4f, cs * size / 1638.4f),
				Vector2(std::min(cur.x, prev.x) + size / 2.0f, std::min(cur.y, prev.y) + size / 2.0f));
		if (std::abs(box.determinant()) < 1e-12) {
			box = Transform2D(Vector2(1e-4f, 0.0f), Vector2(0.0f, 1e-4f), box.get_origin()); // zero-size box
		}
		Gradient g;
		g.inv = box.affine_inverse();
		g.r0 = 100.0f / 255.0f;
		g.r1 = 155.0f / 255.0f;
		g.c0 = c_rgb;
		g.c0.a = std::min(1.0, (double)dens[i - 1]) * p_alpha;
		g.c1 = c_rgb;
		g.c1.a = std::min(1.0, (double)dens[i]) * p_alpha;

		vs.reset();
		Vector2 a0 = in_off[i - 1], ac = in_ip[i - 1], a1 = in_off[i];
		Vector2 b0 = out_off[i - 1], bc = out_ip[i - 1], b1 = out_off[i];
		int k = std::max(steps(a0, ac, a1), steps(b0, bc, b1));
		Vector2 pa = a0, pb = b0;
		// ribbon slots: 2j for the inside curve's j-th point, 2j + 1 for the outside one's
		for (int j = 1; j <= k; j++) {
			float t = (float)j / k;
			Vector2 qa = bez(a0, ac, a1, t), qb = bez(b0, bc, b1, t);
			emit_triangle(mesh, g, vs, 2 * j - 2, pa, 2 * j - 1, pb, 2 * j, qa);
			emit_triangle(mesh, g, vs, 2 * j - 1, pb, 2 * j + 1, qb, 2 * j, qa);
			pa = qa;
			pb = qb;
		}
		if (i == n - 1) {
			cap(g, 50, a1, bottom_cap, b1);
		}
		if (i == 1) {
			cap(g, 77, b0, top_cap, a0);
		}
	}
}

Rect2 sdt_points_rect(const std::vector<Vector2> &points) {
	if (points.empty()) {
		return Rect2();
	}
	// the same comparisons as Vector2.min / max, so the box is bit-identical to the GDScript loop's
	Vector2 lo = points[0], hi = points[0];
	for (const Vector2 &p : points) {
		lo.x = lo.x < p.x ? lo.x : p.x;
		lo.y = lo.y < p.y ? lo.y : p.y;
		hi.x = hi.x > p.x ? hi.x : p.x;
		hi.y = hi.y > p.y ? hi.y : p.y;
	}
	return Rect2(lo, hi - lo);
}

Array SDTNative::build_strand(const PackedVector2Array &p_pos, const PackedFloat32Array &p_thickness,
		const PackedFloat32Array &p_density, const PackedByteArray &p_has_stored, const PackedVector2Array &p_stored,
		const Color &p_rgb, double p_alpha, double p_max_interp_dist) {
	StrandMesh mesh;
	const int n = (int)p_pos.size();
	if (n >= 2) {
		sdt_append_strand_mesh(mesh, p_pos.ptr(), p_thickness.ptr(), p_density.ptr(),
				p_has_stored.size() >= n ? p_has_stored.ptr() : nullptr, p_stored.size() >= n * 2 ? p_stored.ptr() : nullptr,
				n, p_rgb, p_alpha, p_max_interp_dist);
	}
	Array result;
	result.push_back(to_packed<PackedVector2Array>(mesh.points));
	result.push_back(to_packed<PackedColorArray>(mesh.colors));
	result.push_back(to_packed<PackedInt32Array>(mesh.indices));
	result.push_back(sdt_points_rect(mesh.points));
	return result;
}

// ------------------------------------------------------------------------------------------------ hit testing

namespace {

enum class Kind { SPRITE, SHAPE, OTHER, SWEAT };

struct Names {
	StringName _hb_gen = "_hb_gen", _hb = "_hb", _hit_bounds = "_hit_bounds", _graphics = "_graphics", hit = "hit",
			   _children = "_children", _clip_depth = "_clip_depth", _masking = "_masking", _clip_proxies = "_clip_proxies",
			   _depth = "_depth", _entry = "_entry", _library = "_library", _hit_masks = "_hit_masks",
			   _hit_masks_loaded = "_hit_masks_loaded", hit_mask_test = "hit_mask_test", _hit_shape = "_hit_shape",
			   has_content = "has_content", bounds = "bounds";
	String hm = "hm", x = "x", y = "y";
};

Names &names() {
	static Names n;
	return n;
}

// Classifies an object by its script's inheritance chain (cached per script).
Kind kind_of(Object *o) {
	static std::unordered_map<Object *, Kind> cache;
	Variant sv = o->get_script();
	Object *script = sv;
	auto it = cache.find(script);
	if (it != cache.end()) {
		return it->second;
	}
	Kind k = Kind::OTHER;
	Ref<Script> s = Object::cast_to<Script>(script);
	while (s.is_valid()) {
		StringName gn = s->get_global_name();
		if (gn == StringName("Sweat")) {
			k = Kind::SWEAT;
			break;
		}
		if (gn == StringName("FlashSprite")) {
			k = Kind::SPRITE;
			break;
		}
		if (gn == StringName("FlashShape")) {
			k = Kind::SHAPE;
			break;
		}
		if (gn == StringName("FlashBitmap") || gn == StringName("FlashTextField")) {
			break;
		}
		s = s->get_base_script();
	}
	cache[script] = k;
	return k;
}

bool hit_shape_rec(Object *o, Vector2 p, int64_t hb_gen);

// The object a hit test skips (hit_shape_excluding: a sweat droplet testing the body part it sits on).
Object *g_hit_exclude = nullptr;

// FlashSprite._clip_allows: children under a timeline clip mask only hit inside the mask.
bool clip_allows(Object *c, Vector2 p, const Dictionary &clips, int64_t hb_gen) {
	Names &N = names();
	int64_t d = c->get(N._depth);
	if (d < 0 || clips.is_empty()) {
		return true;
	}
	Array keys = clips.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		Object *m = keys[i];
		if (m == nullptr) {
			continue;
		}
		int64_t md = m->get(N._depth);
		int64_t mcd = m->get(N._clip_depth);
		if (d > md && d <= mcd) {
			Node2D *mn = Object::cast_to<Node2D>(m);
			return hit_shape_rec(m, mn->get_transform().affine_inverse().xform(p), hb_gen);
		}
	}
	return true;
}

bool hit_shape_rec(Object *o, Vector2 p, int64_t hb_gen) {
	Names &N = names();
	switch (kind_of(o)) {
		case Kind::SHAPE: {
			Dictionary e = o->get(N._entry);
			if (e.is_empty() || !e.has(N.hm)) {
				return false;
			}
			Object *lib = o->get(N._library);
			if (lib == nullptr) {
				return false;
			}
			if (!(bool)lib->get(N._hit_masks_loaded)) {
				return lib->call(N.hit_mask_test, e, p);
			}
			Array hm = e[N.hm];
			int64_t x = (int64_t)std::floor(p.x - (double)e[N.x]);
			int64_t y = (int64_t)std::floor(p.y - (double)e[N.y]);
			int64_t w = hm[1], h = hm[2];
			if (x < 0 || y < 0 || x >= w || y >= h) {
				return false;
			}
			int64_t bit = y * w + x;
			int64_t byte_i = (int64_t)hm[0] + (bit >> 3);
			PackedByteArray masks = lib->get(N._hit_masks);
			if (byte_i >= masks.size()) {
				return false;
			}
			return ((masks.ptr()[byte_i] >> (bit & 7)) & 1) == 1;
		}
		case Kind::SWEAT:
		case Kind::SPRITE: {
			Rect2 hb;
			if ((int64_t)o->get(N._hb_gen) == hb_gen) {
				hb = o->get(N._hb);
			} else {
				hb = o->call(N._hit_bounds);
			}
			if (!hb.has_point(p)) {
				return false;
			}
			Variant gv = o->get(N._graphics);
			Object *gr = gv;
			if (gr != nullptr && (bool)gr->call(N.hit, p)) {
				return true;
			}
			Array children = o->get(N._children);
			Dictionary clips;
			bool clips_read = false;
			for (int64_t i = children.size() - 1; i >= 0; i--) {
				Object *c = children[i];
				if (c == nullptr || c == g_hit_exclude) {
					continue;
				}
				// Test the child first (it rejects cheaply on its cached bounds); the mask / clip checks, which do
				// not change the outcome order, are only read for children that actually hit.
				Node2D *cn = Object::cast_to<Node2D>(c);
				if (!hit_shape_rec(c, cn->get_transform().affine_inverse().xform(p), hb_gen)) {
					continue;
				}
				if ((int64_t)c->get(N._clip_depth) > 0) {
					continue;
				}
				Array masking = c->get(N._masking);
				if (!masking.is_empty()) {
					continue;
				}
				if (!clips_read) {
					clips = o->get(N._clip_proxies);
					clips_read = true;
				}
				if (clip_allows(c, p, clips, hb_gen)) {
					return true;
				}
			}
			return false;
		}
		default:
			return o->call(N._hit_shape, p);
	}
}


// ------------------------------------------------------------------------------------------------ flattened tests
// hit_flat: the first test of a root in a tick walks its tree once and keeps a flat list of its shapes (hit mask,
// transform from the root's space, bounds); later tests in the same tick are plain math on that list. Sweat
// droplets are left out (used by the droplets' own tests: is this point on the body part's skin?).

struct FlatLeaf {
	Transform2D inv; // root space -> leaf space
	Rect2 bounds;    // in root space (quick reject)
	bool call = false; // true: ask the object (graphics.hit / _hit_shape), false: hit mask
	ObjectID obj;
	StringName method;
	PackedByteArray masks;
	int64_t ex = 0, ey = 0, w = 0, h = 0, byte0 = 0;
	std::vector<int> clips; // every one of these clip groups must hit too
};

struct FlatRoot {
	int64_t tick = -1;
	Rect2 bounds;
	bool bounds_ok = false;
	std::vector<FlatLeaf> leaves;
	std::vector<std::vector<FlatLeaf>> groups; // clip mask contents
};

std::unordered_map<uint64_t, FlatRoot> g_flat;

Rect2 xform_rect(const Transform2D &t, const Rect2 &r) {
	Vector2 a = t.xform(r.position), b = t.xform(r.position + Vector2(r.size.x, 0)),
			c = t.xform(r.position + Vector2(0, r.size.y)), d = t.xform(r.position + r.size);
	Vector2 mn(std::min(std::min(a.x, b.x), std::min(c.x, d.x)), std::min(std::min(a.y, b.y), std::min(c.y, d.y)));
	Vector2 mx(std::max(std::max(a.x, b.x), std::max(c.x, d.x)), std::max(std::max(a.y, b.y), std::max(c.y, d.y)));
	return Rect2(mn, mx - mn);
}

const Rect2 EVERYWHERE(-1e9, -1e9, 2e9, 2e9);

void flatten(FlatRoot &root, std::vector<FlatLeaf> &out, Object *o, const Transform2D &to_root,
		const std::vector<int> &clips);

// The children of sprite o (to_root: o's space -> root space), with the clip masks of timeline clipping.
void flatten_children(FlatRoot &root, std::vector<FlatLeaf> &out, Object *o, const Transform2D &to_root,
		const std::vector<int> &clips) {
	Names &N = names();
	Array children = o->get(N._children);
	Dictionary clip_proxies;
	bool clips_read = false;
	for (int64_t i = 0; i < children.size(); i++) {
		Object *c = children[i];
		if (c == nullptr) {
			continue;
		}
		if ((int64_t)c->get(N._clip_depth) > 0) {
			continue; // a clip mask itself does not hit
		}
		Array masking = c->get(N._masking);
		if (!masking.is_empty()) {
			continue; // masks do not hit
		}
		Node2D *cn = Object::cast_to<Node2D>(c);
		std::vector<int> cc = clips;
		int64_t d = c->get(N._depth);
		if (d >= 0) {
			if (!clips_read) {
				clip_proxies = o->get(N._clip_proxies);
				clips_read = true;
			}
			Array keys = clip_proxies.keys();
			for (int64_t k = 0; k < keys.size(); k++) {
				Object *m = keys[k];
				if (m == nullptr) {
					continue;
				}
				if (d > (int64_t)m->get(N._depth) && d <= (int64_t)m->get(N._clip_depth)) {
					Node2D *mn = Object::cast_to<Node2D>(m);
					std::vector<FlatLeaf> tmp;
					flatten(root, tmp, m, to_root * mn->get_transform(), {});
					root.groups.push_back(std::move(tmp));
					cc.push_back((int)root.groups.size() - 1);
					break;
				}
			}
		}
		flatten(root, out, c, to_root * cn->get_transform(), cc);
	}
}

FlatLeaf call_leaf(Object *o, const StringName &method, const Transform2D &to_root, const std::vector<int> &clips) {
	FlatLeaf l;
	l.inv = to_root.affine_inverse();
	l.clips = clips;
	l.call = true;
	l.obj = ObjectID(o->get_instance_id());
	l.method = method;
	l.bounds = EVERYWHERE;
	return l;
}

void flatten(FlatRoot &root, std::vector<FlatLeaf> &out, Object *o, const Transform2D &to_root,
		const std::vector<int> &clips) {
	Names &N = names();
	switch (kind_of(o)) {
		case Kind::SWEAT:
			return;
		case Kind::SHAPE: {
			Dictionary e = o->get(N._entry);
			if (e.is_empty() || !e.has(N.hm)) {
				return;
			}
			Object *lib = o->get(N._library);
			if (lib == nullptr) {
				return;
			}
			if (!(bool)lib->get(N._hit_masks_loaded)) {
				out.push_back(call_leaf(o, N._hit_shape, to_root, clips)); // rare: ask the object
				return;
			}
			FlatLeaf l;
			l.inv = to_root.affine_inverse();
			l.clips = clips;
			Array hm = e[N.hm];
			double ex = e[N.x], ey = e[N.y];
			l.ex = (int64_t)std::floor(ex);
			l.ey = (int64_t)std::floor(ey);
			l.byte0 = hm[0];
			l.w = hm[1];
			l.h = hm[2];
			l.masks = lib->get(N._hit_masks);
			// the hit test floors p - (x, y): the mask covers [x, x + w) in the shape's space
			l.bounds = xform_rect(to_root, Rect2(ex - 1, ey - 1, (double)l.w + 2, (double)l.h + 2));
			out.push_back(l);
			return;
		}
		case Kind::SPRITE: {
			Variant gv = o->get(N._graphics);
			Object *gr = gv;
			if (gr != nullptr && (bool)gr->call(N.has_content)) {
				FlatLeaf l = call_leaf(gr, N.hit, to_root, clips);
				Rect2 gb = gr->call(N.bounds);
				l.bounds = xform_rect(to_root, gb.grow(1));
				out.push_back(l);
			}
			flatten_children(root, out, o, to_root, clips);
			return;
		}
		default:
			out.push_back(call_leaf(o, N._hit_shape, to_root, clips));
			return;
	}
}

bool leaf_hit(const FlatLeaf &l, Vector2 p) {
	if (!l.bounds.has_point(p)) {
		return false;
	}
	Vector2 q = l.inv.xform(p);
	if (l.call) {
		Object *o = ObjectDB::get_instance(l.obj);
		return o != nullptr && (bool)o->call(l.method, q);
	}
	int64_t x = (int64_t)std::floor(q.x - (double)l.ex) ;
	int64_t y = (int64_t)std::floor(q.y - (double)l.ey);
	if (x < 0 || y < 0 || x >= l.w || y >= l.h) {
		return false;
	}
	int64_t bit = y * l.w + x;
	int64_t byte_i = l.byte0 + (bit >> 3);
	if (byte_i >= l.masks.size()) {
		return false;
	}
	return ((l.masks.ptr()[byte_i] >> (bit & 7)) & 1) == 1;
}

bool leaves_hit(const FlatRoot &root, const std::vector<FlatLeaf> &leaves, Vector2 p) {
	for (const FlatLeaf &l : leaves) {
		if (!leaf_hit(l, p)) {
			continue;
		}
		bool ok = true;
		for (int gi : l.clips) {
			if (!leaves_hit(root, root.groups[gi], p)) {
				ok = false;
				break;
			}
		}
		if (ok) {
			return true;
		}
	}
	return false;
}
} // namespace

bool SDTNative::hit_shape(Object *p_obj, const Vector2 &p_point, int64_t p_hb_gen) {
	if (p_obj == nullptr) {
		return false;
	}
	return hit_shape_rec(p_obj, p_point, p_hb_gen);
}

bool SDTNative::hit_flat(Object *p_obj, const Vector2 &p_point, int64_t p_tick) {
	return sdt_hit_flat(p_obj, p_point, p_tick);
}

// The flattened root for obj in this tick (built on first use).
static FlatRoot &flat_root(Object *p_obj, int64_t p_tick) {
	FlatRoot &root = g_flat[p_obj->get_instance_id()];
	if (root.tick != p_tick) {
		root.tick = p_tick;
		root.leaves.clear();
		root.groups.clear();
		root.bounds_ok = false;
		flatten(root, root.leaves, p_obj, Transform2D(), {});
	}
	return root;
}

Rect2 sdt_flat_bounds(Object *p_obj, int64_t p_tick) {
	if (p_obj == nullptr) {
		return Rect2();
	}
	FlatRoot &root = flat_root(p_obj, p_tick);
	if (!root.bounds_ok) {
		bool first = true;
		Rect2 r;
		for (const FlatLeaf &l : root.leaves) {
			if (l.call) {
				continue; // unbounded entries (graphics, text) do not count
			}
			r = first ? l.bounds : r.merge(l.bounds);
			first = false;
		}
		root.bounds = r;
		root.bounds_ok = true;
	}
	return root.bounds;
}

bool sdt_hit_flat(Object *p_obj, const Vector2 &p_point, int64_t p_tick) {
	if (p_obj == nullptr) {
		return false;
	}
	FlatRoot &root = g_flat[p_obj->get_instance_id()];
	if (root.tick != p_tick) {
		root.tick = p_tick;
		root.leaves.clear();
		root.groups.clear();
		root.bounds_ok = false;
		flatten(root, root.leaves, p_obj, Transform2D(), {});
	}
	if (g_flat.size() > 256) { // forget roots not tested lately
		for (auto it = g_flat.begin(); it != g_flat.end();) {
			if (it->second.tick < p_tick - 1) {
				it = g_flat.erase(it);
			} else {
				++it;
			}
		}
		return sdt_hit_flat(p_obj, p_point, p_tick);
	}
	return leaves_hit(root, root.leaves, p_point);
}

bool SDTNative::hit_shape_excluding(Object *p_obj, const Vector2 &p_point, int64_t p_hb_gen, Object *p_exclude) {
	if (p_obj == nullptr) {
		return false;
	}
	g_hit_exclude = p_exclude;
	bool hit = hit_shape_rec(p_obj, p_point, p_hb_gen);
	g_hit_exclude = nullptr;
	return hit;
}
