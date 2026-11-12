#include "fluids.h"

#include "sdt_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>

// The logic follows the game's Strand / StrandLink (see their GDScript ports, which remain the fallback), with
// these deliberate differences: neighbours are always the previous and next link (the original's setNeighbours
// left one link with stale neighbours), stored inter points are gone (never created), and a strand stays in the
// list it was created in (the original delisted by its cum flag, which spit drool changes).

namespace {

float randf() {
	return (float)UtilityFunctions::randf();
}

template <typename P, typename T>
P packed(const std::vector<T> &v) {
	P out;
	out.resize((int64_t)v.size());
	if (!v.empty()) {
		memcpy(out.ptrw(), v.data(), v.size() * sizeof(T));
	}
	return out;
}

} // namespace

void SDTFluids::_bind_methods() {
	ClassDB::bind_method(D_METHOD("add_container", "obj", "flags"), &SDTFluids::add_container);
	ClassDB::bind_method(D_METHOD("set_container_object", "index", "obj"), &SDTFluids::set_container_object);
	ClassDB::bind_method(D_METHOD("set_special", "face", "jaw", "eye_box", "scene"), &SDTFluids::set_special);
	ClassDB::bind_method(D_METHOD("set_transforms", "transforms"), &SDTFluids::set_transforms);
	ClassDB::bind_method(D_METHOD("set_targets", "targets"), &SDTFluids::set_targets);
	ClassDB::bind_method(D_METHOD("set_params", "params"), &SDTFluids::set_params);
	ClassDB::bind_method(D_METHOD("new_strand", "layer", "links", "mass", "top", "bottom", "top_source", "disappear",
								 "initial_speed"),
			&SDTFluids::new_strand);
	ClassDB::bind_method(D_METHOD("new_cum_strand", "layer", "mass", "p", "container"), &SDTFluids::new_cum_strand);
	ClassDB::bind_method(D_METHOD("add_source_link", "id", "p", "container", "cum"), &SDTFluids::add_source_link);
	ClassDB::bind_method(D_METHOD("insert_link", "id", "v", "delay", "mass"), &SDTFluids::insert_link);
	ClassDB::bind_method(D_METHOD("detach_source_link", "id", "v", "delay"), &SDTFluids::detach_source_link);
	ClassDB::bind_method(D_METHOD("set_gravity", "id", "gravity"), &SDTFluids::set_gravity);
	ClassDB::bind_method(D_METHOD("get_gravity", "id"), &SDTFluids::get_gravity);
	ClassDB::bind_method(D_METHOD("set_collision_free", "id", "n"), &SDTFluids::set_collision_free);
	ClassDB::bind_method(D_METHOD("get_collision_free", "id"), &SDTFluids::get_collision_free);
	ClassDB::bind_method(D_METHOD("release", "id"), &SDTFluids::release);
	ClassDB::bind_method(D_METHOD("is_alive", "id"), &SDTFluids::is_alive);
	ClassDB::bind_method(D_METHOD("tick"), &SDTFluids::tick);
	ClassDB::bind_method(D_METHOD("take_events"), &SDTFluids::take_events);
	ClassDB::bind_method(D_METHOD("get_mesh", "layer", "fraction"), &SDTFluids::get_mesh);
	ClassDB::bind_method(D_METHOD("get_mesh_changed", "layer", "fraction"), &SDTFluids::get_mesh_changed);
	ClassDB::bind_method(D_METHOD("smear", "p", "radius"), &SDTFluids::smear);
	ClassDB::bind_method(D_METHOD("detach_container", "container"), &SDTFluids::detach_container);
	ClassDB::bind_method(D_METHOD("clear", "cum"), &SDTFluids::clear);
	ClassDB::bind_method(D_METHOD("count", "cum"), &SDTFluids::count);
	ClassDB::bind_method(D_METHOD("kill_oldest", "cum"), &SDTFluids::kill_oldest);
	ClassDB::bind_method(D_METHOD("alphas", "cum"), &SDTFluids::alphas);
	ClassDB::bind_method(D_METHOD("add_ages", "cum", "amounts"), &SDTFluids::add_ages);
	ClassDB::bind_method(D_METHOD("get_points", "id"), &SDTFluids::get_points);
	ClassDB::bind_method(D_METHOD("get_state"), &SDTFluids::get_state);
}

// ---------------------------------------------------------------------------------------------- setup

int SDTFluids::add_container(Object *obj, int flags) {
	Container c;
	c.obj = obj ? ObjectID(obj->get_instance_id()) : ObjectID();
	c.flags = flags;
	containers.push_back(c);
	smudge.emplace_back();
	return (int)containers.size() - 1;
}

void SDTFluids::set_container_object(int index, Object *obj) {
	if (index >= 0 && index < (int)containers.size()) {
		containers[index].obj = obj ? ObjectID(obj->get_instance_id()) : ObjectID();
	}
}

void SDTFluids::set_special(int p_face, int p_jaw, int p_eye_box, int p_scene) {
	face = p_face;
	jaw = p_jaw;
	eye_box = p_eye_box;
	scene = p_scene;
}

void SDTFluids::set_transforms(const Array &transforms) {
	int n = std::min((int)transforms.size(), (int)containers.size());
	for (int i = 0; i < n; i++) {
		Transform2D t = transforms[i];
		containers[i].to_scene = t;
		containers[i].from_scene = t.affine_inverse();
	}
}

void SDTFluids::set_targets(const Array &p_targets) {
	targets.clear();
	for (int64_t i = 0; i < p_targets.size(); i++) {
		Dictionary d = p_targets[i];
		Target t;
		Object *o = d.get("obj", Variant());
		t.obj = o ? ObjectID(o->get_instance_id()) : ObjectID();
		t.from_scene = d.get("inv", Transform2D());
		t.anchor = d.get("anchor", -1);
		t.hit_target = d.get("hit_target", -1);
		t.force = d.get("force", false);
		t.kind = d.get("kind", 0);
		Array need = d.get("need", Array());
		for (int64_t k = 0; k < need.size(); k++) {
			t.need.push_back(need[k]);
		}
		Object *ex = d.get("exclude", Variant());
		t.exclude = ex ? ObjectID(ex->get_instance_id()) : ObjectID();
		t.exclude_from_scene = d.get("exclude_inv", Transform2D());
		t.eye = d.get("eye", Rect2());
		targets.push_back(t);
	}
}

void SDTFluids::set_params(const Dictionary &d) {
	gravity = d.get("gravity", gravity);
	friction = d.get("friction", friction);
	max_mass = d.get("max_mass", max_mass);
	mass_generate_speed = d.get("mass_generate_speed", mass_generate_speed);
	mass_flow = d.get("mass_flow", mass_flow);
	max_strand_length = d.get("max_strand_length", max_strand_length);
	kill_y = d.get("kill_y", kill_y);
	floor_y = d.get("floor_y", floor_y);
	him_ejaculating = d.get("him_ejaculating", him_ejaculating);
	cum_rgb = d.get("cum_rgb", cum_rgb);
	cum_min_thickness = d.get("cum_min_thickness", cum_min_thickness);
	tick_key = d.get("tick", tick_key);
}

// ---------------------------------------------------------------------------------------------- helpers

int SDTFluids::alloc() {
	int id;
	if (!free_ids.empty()) {
		id = free_ids.back();
		free_ids.pop_back();
		strands[id] = Strand();
	} else {
		strands.emplace_back();
		id = (int)strands.size() - 1;
	}
	order.push_back(id);
	return id;
}

SDTFluids::Link SDTFluids::make_link(float mass, float density, Vector2 speed, int collision_free, bool slide) const {
	Link l;
	l.mass = std::max(l.min_mass, mass);
	l.density = density;
	l.slide_on_anchor = slide;
	l.speed = speed;
	l.collision_free = collision_free;
	return l;
}

Vector2 SDTFluids::anchor_point(const Link &l) const {
	int c = l.anchor.container;
	if (c < 0 || c >= (int)containers.size()) {
		return l.p;
	}
	return containers[c].to_scene.xform(l.anchor.local);
}

bool SDTFluids::obj_hit(const ObjectID &obj, const Transform2D &from_scene, Vector2 p) const {
	Object *o = ObjectDB::get_instance(obj);
	return o != nullptr && sdt_hit_flat(o, from_scene.xform(p), tick_key);
}

bool SDTFluids::shape_hit(int container, Vector2 p) const {
	if (container < 0 || container >= (int)containers.size()) {
		return false;
	}
	return obj_hit(containers[container].obj, containers[container].from_scene, p);
}

void SDTFluids::detach(Link &l, bool free_, bool delay) {
	if (l.anchored) {
		l.anchored = false;
		l.just_anchored = false;
		l.sliding = false;
		if (free_) {
			l.freed = true;
		} else if (delay) {
			l.anchor_delay = 2;
		}
	}
}

// StrandLink.anchorTo (keep_counter: a cloned link keeps its slide counter, as the original's clone did)
void SDTFluids::anchor_to(Strand &s, int li, const Anchor &a, bool is_source, bool delay_on_detach, bool keep_counter) {
	Link &l = s.links[li];
	if (l.anchored) {
		detach(l, false, delay_on_detach);
	}
	if (a.eye) {
		l.on_eye = true;
	}
	l.anchor = a;
	l.anchor_age = 0;
	l.anchored = true;
	if (l.slide_on_anchor) {
		l.speed *= 0.7f;
		if (!keep_counter) {
			l.slide_counter = (int)std::floor(randf() * l.slide_max);
		}
		l.sliding = true;
	} else {
		l.speed = Vector2();
	}
	l.just_anchored = true;
	l.source = is_source;
	l.freed = false;
	int flags = (a.container >= 0 && a.container < (int)containers.size()) ? containers[a.container].flags : 0;
	if (flags & TONGUE_TIP) {
		l.on_tongue = true;
		l.speed *= 0.5f;
		l.slide_counter += (int)((l.slide_max - l.slide_counter) * 0.5f);
	}
	if (flags & SCENE) {
		for (int n : { li - 1, li + 1 }) {
			if (n >= 0 && n < (int)s.links.size()) {
				s.links[n].speed.y *= 0.2f;
				s.links[n].speed.x += randf() * 20.0f - 10.0f;
			}
		}
	}
}

SDTFluids::Link SDTFluids::clone_link(const Link &l) {
	Link c = make_link(l.mass, l.density, l.speed, l.collision_free, false);
	if (l.anchored) {
		Anchor a;
		a.container = l.anchor.container;
		a.local = l.anchor.local;
		a.force = l.anchor.force;
		Strand tmp;
		tmp.links.push_back(c);
		anchor_to(tmp, 0, a, false, false, true);
		c = tmp.links[0];
		c.anchor_age = l.anchor_age;
		c.anchor_delay = l.anchor_delay;
		c.on_tongue = l.on_tongue;
	}
	c.generate_mass = l.generate_mass;
	c.expanded = l.expanded;
	c.p = l.p;
	return c;
}

bool SDTFluids::anchorable(const Link &l) const {
	if (!l.anchored && !l.freed && l.collision_free == 0) {
		return true;
	}
	if (l.anchored && !l.source) {
		int c = l.anchor.container;
		if (c >= 0 && c < (int)containers.size() && (containers[c].flags & HIM)) {
			return true;
		}
	}
	return false;
}

// StrandLink.recheckAnchor: an anchor that slid or was smeared off its body part moves to the neighbouring part
// (face <-> jaw) or lets go.
void SDTFluids::recheck_anchor(Link &l) {
	int ht = l.anchor.hit_target >= 0 ? l.anchor.hit_target : l.anchor.container;
	if (ht < 0 || ht >= (int)containers.size() || (containers[ht].flags & SCENE)) {
		return;
	}
	Vector2 ga = anchor_point(l);
	if (shape_hit(ht, ga)) {
		return;
	}
	if (ht == face && shape_hit(jaw, ga)) {
		l.anchor.local = containers[jaw].from_scene.xform(ga);
		l.anchor.container = jaw;
		if (l.anchor.hit_target >= 0) {
			l.anchor.hit_target = jaw;
		}
		return;
	}
	if (ht == jaw && shape_hit(face, ga)) {
		l.anchor.local = containers[face].from_scene.xform(ga);
		l.anchor.container = face;
		if (l.anchor.hit_target >= 0) {
			l.anchor.hit_target = face;
		}
		return;
	}
	if (l.on_eye && !shape_hit(eye_box, ga)) {
		event(EV_EYE_CLEAR);
	}
	detach(l, false);
}

void SDTFluids::link_tick(Strand &s, int li) {
	Link &l = s.links[li];
	if (l.anchored) {
		l.anchor_age += 1;
		if (l.sliding) {
			l.speed.x *= 0.6f;
			l.speed.y = l.speed.y * 0.5f + s.gravity * l.mass * l.density * (1.0f - (float)l.slide_counter / l.slide_max) * 0.5f;
			l.slide_counter += 1;
			if (l.slide_counter >= l.slide_max) {
				l.sliding = false;
			}
			Vector2 p = anchor_point(l) + l.speed;
			int c = l.anchor.container;
			if (c >= 0 && c < (int)containers.size()) {
				l.anchor.local = containers[c].from_scene.xform(p);
			}
			recheck_anchor(l);
			if (std::abs(l.speed.x) < 0.01f && std::abs(l.speed.y) < 0.01f) {
				l.sliding = false;
			}
		}
	}
	if (l.collision_free > 0) {
		l.collision_free -= 1;
	}
	if (l.generate_mass) {
		l.mass += mass_generate_speed;
	}
	// mass and density flow to the neighbours below
	for (int ni : { li - 1, li + 1 }) {
		if (ni < 0 || ni >= (int)s.links.size()) {
			continue;
		}
		Link &n = s.links[ni];
		if (n.p.y > l.p.y) {
			Vector2 v = n.p - l.p;
			float flow = std::max(0.0f, std::sin(std::atan2(v.y, v.x)));
			if (l.mass > l.min_mass) {
				float m = std::min(mass_flow, l.mass - l.min_mass) * flow;
				if (!n.anchored) {
					n.mass += m;
					l.mass -= m;
				}
			}
			float amount = std::min(1.0f - n.density, std::min(std::max(0.05f, l.density * 0.1f), l.density - n.min_density) * flow);
			n.density += amount;
			l.density -= amount;
		}
	}
}

bool SDTFluids::collide(Strand &s, int li, Anchor &out) {
	Vector2 p = s.links[li].p;
	for (const Target &t : targets) {
		bool inside = true;
		for (const Rect2 &r : t.need) {
			if (!r.has_point(p)) {
				inside = false;
				break;
			}
		}
		if (!inside || !obj_hit(t.obj, t.from_scene, p)) {
			continue;
		}
		if (t.exclude.is_valid() && obj_hit(t.exclude, t.exclude_from_scene, p)) {
			continue;
		}
		if (t.anchor < 0 || t.anchor >= (int)containers.size()) {
			continue;
		}
		out = Anchor();
		out.container = t.anchor;
		out.hit_target = t.hit_target;
		out.local = containers[t.anchor].from_scene.xform(p);
		out.force = t.force;
		if (t.kind == TARGET_FACE && s.cum && t.eye.has_point(p)) {
			out.eye = true;
		}
		if (t.kind == TARGET_TONGUE && s.cum) {
			event(EV_TONGUE_CUM_HIT);
		}
		return true;
	}
	// the floor
	if (scene >= 0 && p.y > floor_y + randf() * 65.0f) {
		out = Anchor();
		out.container = scene;
		out.local = containers[scene].from_scene.xform(p);
		out.force = true;
		return true;
	}
	return false;
}

bool SDTFluids::tongue_collide(Strand &s, int li) {
	Vector2 p = s.links[li].p;
	return shape_hit(face, p) || shape_hit(jaw, p);
}

void SDTFluids::event(int type, const Array &args) {
	Array e;
	e.push_back(type);
	for (int64_t i = 0; i < args.size(); i++) {
		e.push_back(args[i]);
	}
	events.push_back(e);
}

float SDTFluids::alpha_of(const Strand &s) const {
	if (s.cum) {
		return 0.95f - std::max(0.0f, std::min(1.9f, 1.2f * s.age / s.age_max - 0.2f)) / 2.0f;
	}
	return 1.0f - std::max(0.0f, std::min(1.0f, 1.2f * s.age / s.age_max - 0.2f));
}

float SDTFluids::thickness(const Strand &s, int li) const {
	const Link &l = s.links[li];
	float t = std::max(s.cum ? cum_min_thickness : 1.0f, std::pow(l.mass * 2.0f, 1.5f));
	if (l.anchored) {
		t *= 1.5f;
	}
	if (s.cum) {
		t *= 1.3f;
	}
	return t;
}

// ---------------------------------------------------------------------------------------------- strand changes

void SDTFluids::kill(int id) {
	Strand &s = strands[id];
	if (!s.alive) {
		return;
	}
	for (const Link &l : s.links) {
		if (l.on_eye) {
			event(EV_EYE_CLEAR);
		}
	}
	s.alive = false;
}

void SDTFluids::cleanup() {
	std::vector<int> keep;
	for (int id : order) {
		Strand &s = strands[id];
		if (s.alive) {
			keep.push_back(id);
		} else if (!s.handle) {
			s.links.clear();
			free_ids.push_back(id);
		}
	}
	order = std::move(keep);
}

int SDTFluids::split(int id, int at, bool add_middle, bool remove_first) {
	Strand &s = strands[id];
	int n = (int)s.links.size();
	if (at < 0 || at > n || (add_middle && at < 1)) {
		return 0;
	}
	Link middle;
	if (add_middle) {
		const Link &a = s.links[at - 1];
		const Link &b = s.links[at];
		middle = make_link(0.0f, (a.density + b.density) * 0.5f, Vector2(), 0, false);
		middle.p = b.p + (a.p - b.p) / 2.0f;
		middle.speed = b.speed + (a.speed - b.speed) / 2.0f;
	}
	std::vector<Link> head(s.links.begin(), s.links.begin() + at);
	std::vector<Link> tail(s.links.begin() + at, s.links.end());
	if (remove_first && !tail.empty()) {
		tail.erase(tail.begin());
	}
	if (add_middle) {
		head.push_back(middle);
		if (!remove_first) {
			tail.insert(tail.begin(), middle);
		}
	}
	s.links = std::move(tail);
	if (head.size() > 1) {
		// StrandControl.addStrand: the head becomes a strand of its own (cloned links, same age)
		int layer = s.layer, age = s.age, age_max = s.age_max;
		bool cum = s.cum, listed = s.listed_cum;
		float lm = s.lm;
		int nid = alloc();
		Strand &ns = strands[nid]; // strands is a deque: s stays valid
		for (const Link &l : head) {
			ns.links.push_back(clone_link(l));
		}
		ns.layer = layer;
		ns.age = age;
		ns.age_max = age_max;
		ns.cum = cum;
		ns.listed_cum = listed;
		ns.lm = lm;
		ns.gravity = gravity;
		ns.dist_split_delay = 10;
		ns.alive = true;
	}
	Strand &s2 = strands[id];
	if (s2.links.size() <= 1) {
		kill(id);
		return 1;
	}
	return 0;
}

void SDTFluids::expand(int id, int li) {
	Strand &s = strands[id];
	Link &l = s.links[li];
	l.mass /= 2.0f;
	l.density /= 2.0f;
	Link c = clone_link(l);
	c.p.x += 1.0f;
	c.expanded = true;
	s.links.insert(s.links.begin() + li, c);
	Array args;
	args.push_back(s.links[li].p);
	args.push_back(s.links[li].speed);
	args.push_back(alpha_of(s));
	args.push_back(s.cum);
	event(EV_DROPLET, args);
}

// Strand.updateStrand: the links' springs, collisions and anchors, splitting and expanding, fading.
void SDTFluids::update(int id) {
	Strand &s = strands[id];
	if (!s.alive) {
		return;
	}
	s.age += 1;
	s.max_dist = std::max(30.0f, s.max_dist - 0.2f);
	float highest = std::numeric_limits<float>::max();
	int i = 0;
	while (true) {
		int n = (int)s.links.size();
		if (i >= n) {
			if (highest > kill_y) {
				kill(id);
				break;
			}
			for (int k = 0; k < n; k++) {
				link_tick(s, k);
			}
			if (!s.cum && n > max_strand_length) {
				int at = (int)std::floor(randf() * n / 3.0f + n / 3.0f);
				if (split(id, at)) {
					break;
				}
			}
			if (alpha_of(s) <= 0.0f) {
				kill(id);
				break;
			}
			break;
		}
		if (s.links[i].on_tongue) {
			if (tongue_collide(s, i)) {
				int died = split(id, i, i > 0, true);
				if (s.cum) {
					event(EV_TONGUE_CUM_REMOVED);
				}
				if (died || i >= (int)s.links.size()) {
					break;
				}
			}
		} else if (anchorable(s.links[i])) {
			Anchor a;
			if (collide(s, i, a)) {
				bool anchored = false;
				if (a.force) {
					anchor_to(s, i, a);
					anchored = true;
				} else if (s.links[i].anchor_delay > 0) {
					s.links[i].anchor_delay -= 1;
				} else {
					anchor_to(s, i, a);
					anchored = true;
				}
				if (anchored) {
					if (s.cum && (containers[a.container].flags & IN_HEAD) && him_ejaculating) {
						event(EV_CUM_ON_FACE);
					}
					if (a.eye) {
						event(EV_EYE_HIT);
					}
				}
				if (s.disappear) {
					bool all = true;
					for (const Link &l : s.links) {
						if (!l.anchored) {
							all = false;
							break;
						}
					}
					if (all) {
						kill(id);
						break;
					}
				}
			}
		}
		Link &link = s.links[i];
		if (link.anchored) {
			link.p = anchor_point(link);
			if (!s.cum && link.anchor_age > s.age_max) {
				detach(link);
			}
		}
		Vector2 to_prev, to_next;
		float dist_sq = 0.0f;
		n = (int)s.links.size();
		if (i > 0) {
			to_prev = s.links[i - 1].p - link.p;
			dist_sq = to_prev.x * to_prev.x + to_prev.y * to_prev.y;
		}
		if (i < n - 1) {
			to_next = s.links[i + 1].p - link.p;
		}
		// StrandLink.accelerate / move
		if (!link.anchored) {
			float ax = (to_prev.x + to_next.x) / s.move_smoothing;
			float ay = (to_prev.y + to_next.y) / s.move_smoothing + s.gravity * link.mass;
			if (link.sliding) {
				float f = 0.5f - 0.5f * (float)link.slide_counter / link.slide_max;
				ax *= f;
				ay *= f;
			}
			link.speed.x += ax;
			link.speed.y += ay;
		}
		if (!link.anchored || link.sliding) {
			link.p += link.speed;
			link.speed /= friction;
		}
		if (dist_sq > s.max_dist && i > 0 && s.dist_split_delay == 0) {
			s.dist_split_delay = 10;
			split(id, i);
		}
		n = (int)s.links.size();
		if (i < n) {
			highest = std::min(highest, s.links[i].p.y);
			if (s.links[i].mass >= max_mass) {
				expand(id, i);
			}
		}
		i += 1;
	}
	if (s.dist_split_delay > 0) {
		s.dist_split_delay -= 1;
	}
}

// ---------------------------------------------------------------------------------------------- API

int SDTFluids::new_strand(int layer, int nlinks, double mass, const Variant &top, const Variant &bottom, bool top_source,
		bool disappear, const Variant &initial_speed) {
	int id = alloc();
	Strand &s = strands[id];
	s.layer = layer;
	s.lm = (float)mass;
	s.gravity = gravity;
	s.disappear = disappear;
	s.handle = true;
	Vector2 v0 = initial_speed.get_type() == Variant::VECTOR2 ? (Vector2)initial_speed : Vector2();
	auto anchor_of = [](const Variant &d) {
		Anchor a;
		Dictionary dd = d;
		a.container = dd.get("container", -1);
		a.local = dd.get("local", Vector2());
		a.force = dd.get("force", true);
		return a;
	};
	bool has_top = top.get_type() == Variant::DICTIONARY, has_bottom = bottom.get_type() == Variant::DICTIONARY;
	Anchor ta, ba;
	if (has_top) {
		ta = anchor_of(top);
		has_top = ta.container >= 0 && ta.container < (int)containers.size();
	}
	if (has_bottom) {
		ba = anchor_of(bottom);
		has_bottom = ba.container >= 0 && ba.container < (int)containers.size();
	}
	for (int i = 0; i < nlinks; i++) {
		Link l = make_link(s.lm, 1.0f, v0, s.collision_free, s.cum);
		if (has_top && has_bottom) {
			Vector2 tp = containers[ta.container].to_scene.xform(ta.local);
			Vector2 bp = containers[ba.container].to_scene.xform(ba.local);
			l.p = tp + (bp - tp) * ((float)i / nlinks);
		} else if (has_top) {
			l.p = containers[ta.container].to_scene.xform(ta.local);
		}
		s.links.push_back(l);
	}
	if (!s.links.empty()) {
		if (top_source) {
			s.links[0].generate_mass = true;
		}
		if (has_top) {
			anchor_to(s, 0, ta);
		}
		if (has_bottom) {
			anchor_to(s, (int)s.links.size() - 1, ba);
		}
	}
	s.alive = true;
	return id;
}

int SDTFluids::new_cum_strand(int layer, double mass, const Vector2 &p, int container) {
	int id = alloc();
	Strand &s = strands[id];
	s.layer = layer;
	s.lm = (float)mass;
	s.gravity = gravity;
	s.listed_cum = true;
	s.handle = true;
	add_source_link(id, p, container, true);
	return id;
}

void SDTFluids::add_source_link(int id, const Vector2 &p, int container, bool cum) {
	if (id < 0 || id >= (int)strands.size()) {
		return;
	}
	Strand &s = strands[id];
	if (cum) {
		s.cum = true;
		s.age_max = 1500;
	}
	s.links.clear();
	s.links.push_back(make_link(s.lm, 1.0f, Vector2(), s.collision_free, false));
	Anchor a;
	a.container = container;
	a.local = p;
	a.force = true;
	anchor_to(s, 0, a, true);
	s.has_source = true;
	s.collision_free = 2;
	s.alive = true;
}

// Strand.insertLink: a new link just above the source link (the source stays the last link)
void SDTFluids::insert_link(int id, const Vector2 &v, int delay, double mass) {
	if (id < 0 || id >= (int)strands.size()) {
		return;
	}
	Strand &s = strands[id];
	if (s.links.empty()) {
		return;
	}
	Link l = make_link((float)mass, std::min(1.0f, randf() * 3.0f), v, s.collision_free, s.cum);
	l.p = s.links.back().p;
	l.anchor_delay = delay;
	s.links.insert(s.links.end() - 1, l);
}

void SDTFluids::detach_source_link(int id, const Vector2 &v, int delay) {
	if (id < 0 || id >= (int)strands.size()) {
		return;
	}
	Strand &s = strands[id];
	if (s.links.empty() || !s.has_source) {
		return;
	}
	Link &l = s.links.back();
	detach(l, false);
	l.speed = v;
	l.anchor_delay = delay;
	l.collision_free = s.collision_free;
	l.slide_on_anchor = s.cum;
}

void SDTFluids::set_gravity(int id, double g) {
	if (id >= 0 && id < (int)strands.size()) {
		strands[id].gravity = (float)g;
	}
}

double SDTFluids::get_gravity(int id) const {
	return (id >= 0 && id < (int)strands.size()) ? strands[id].gravity : 0.0;
}

void SDTFluids::set_collision_free(int id, int n) {
	if (id >= 0 && id < (int)strands.size()) {
		strands[id].collision_free = n;
	}
}

int SDTFluids::get_collision_free(int id) const {
	return (id >= 0 && id < (int)strands.size()) ? strands[id].collision_free : 0;
}

// The game dropped its handle: a dead strand's slot can be reused, a live one goes on by itself.
void SDTFluids::release(int id) {
	if (id < 0 || id >= (int)strands.size()) {
		return;
	}
	Strand &s = strands[id];
	s.handle = false;
	if (!s.alive && std::find(order.begin(), order.end(), id) == order.end() &&
			std::find(free_ids.begin(), free_ids.end(), id) == free_ids.end()) {
		s.links.clear();
		free_ids.push_back(id);
	}
}

bool SDTFluids::is_alive(int id) const {
	return id >= 0 && id < (int)strands.size() && strands[id].alive;
}

Array SDTFluids::tick() {
	std::vector<int> ids = order; // strands made this tick (splits) start next tick
	for (int id : ids) {
		for (Link &l : strands[id].links) {
			l.prev = l.p;
			l.prev_valid = true;
		}
	}
	for (int id : ids) {
		if (strands[id].alive) {
			update(id);
		}
	}
	cleanup();
	return take_events();
}

Array SDTFluids::take_events() {
	Array e = events;
	events = Array();
	return e;
}

namespace {
template <typename T>
bool same_bits(const std::vector<T> &a, const std::vector<T> &b) {
	return a.size() == b.size() && (a.empty() || memcmp(a.data(), b.data(), a.size() * sizeof(T)) == 0);
}
} // namespace

bool SDTFluids::MeshInput::operator==(const MeshInput &o) const {
	if (strands.size() != o.strands.size()) {
		return false;
	}
	for (size_t i = 0; i < strands.size(); i++) {
		const MeshStrand &a = strands[i], &b = o.strands[i];
		if (a.start != b.start || a.n != b.n || memcmp(&a.rgb, &b.rgb, sizeof(Color)) != 0 ||
				memcmp(&a.alpha, &b.alpha, sizeof(float)) != 0 || memcmp(&a.max_interp, &b.max_interp, sizeof(float)) != 0) {
			return false;
		}
	}
	return same_bits(pos, o.pos) && same_bits(thick, o.thick) && same_bits(dens, o.dens);
}

void SDTFluids::mesh_input(int layer, double fraction, MeshInput &in) const {
	float f = (float)std::clamp(fraction, 0.0, 1.0);
	Color white(1, 1, 1);
	for (int id : order) {
		const Strand &s = strands[id];
		if (!s.alive || s.layer != layer || s.links.size() < 2) {
			continue;
		}
		int n = (int)s.links.size();
		in.strands.push_back({ (int)in.pos.size(), n, s.cum ? cum_rgb : white, alpha_of(s), s.max_interp });
		for (int i = 0; i < n; i++) {
			const Link &l = s.links[i];
			in.pos.push_back(l.prev_valid ? l.prev + (l.p - l.prev) * f : l.p);
			in.thick.push_back(thickness(s, i));
			in.dens.push_back(l.density);
		}
	}
}

Array SDTFluids::build_mesh(const MeshInput &in) {
	StrandMesh mesh;
	for (const MeshStrand &s : in.strands) {
		sdt_append_strand_mesh(mesh, in.pos.data() + s.start, in.thick.data() + s.start, in.dens.data() + s.start,
				nullptr, nullptr, s.n, s.rgb, s.alpha, s.max_interp);
	}
	Array r;
	r.push_back(packed<PackedVector2Array>(mesh.points));
	r.push_back(packed<PackedColorArray>(mesh.colors));
	r.push_back(packed<PackedInt32Array>(mesh.indices));
	r.push_back(sdt_points_rect(mesh.points));
	return r;
}

Array SDTFluids::get_mesh(int layer, double fraction) const {
	MeshInput in;
	mesh_input(layer, fraction, in);
	return build_mesh(in);
}

// Settled strands (or several frames at the same fraction) give the same input, so the same mesh: not rebuilt.
Array SDTFluids::get_mesh_changed(int layer, double fraction) {
	if (layer < 0) {
		return get_mesh(layer, fraction);
	}
	if ((int)last_input.size() <= layer) {
		last_input.resize(layer + 1);
		last_valid.resize(layer + 1, 0);
	}
	MeshInput in;
	mesh_input(layer, fraction, in);
	if (last_valid[layer] && in == last_input[layer]) {
		return Array();
	}
	last_input[layer] = std::move(in);
	last_valid[layer] = 1;
	return build_mesh(last_input[layer]);
}

// StrandLink.smear for every anchored link near p: it thins and is dragged along with the smearing point's
// movement in its body part's space (g.smudgeCache).
void SDTFluids::smear(const Vector2 &p, double radius) {
	float r2 = (float)(radius * radius);
	for (int id : order) {
		Strand &s = strands[id];
		if (!s.alive) {
			continue;
		}
		for (Link &l : s.links) {
			if (!l.anchored) {
				continue;
			}
			Vector2 d = anchor_point(l) - p;
			float d2 = std::max(2.0f, d.x * d.x + d.y * d.y);
			if (d2 >= r2) {
				continue;
			}
			l.smear_counter += 1;
			l.mass = std::max(l.min_mass, l.mass - 0.05f);
			l.density = std::max(0.05f, l.density - 0.05f);
			if (l.smear_counter >= l.max_smear) {
				continue;
			}
			int c = l.anchor.container;
			if (c < 0 || c >= (int)containers.size()) {
				continue;
			}
			float amount = std::max(0.0f, std::min(0.1f, (r2 - d2) / r2)) * (1.0f - (float)l.smear_counter / l.max_smear);
			Smudge &sm = smudge[c];
			if (!sm.updated) {
				sm.local = containers[c].from_scene.xform(p);
				if (!sm.has) {
					sm.last = sm.local;
					sm.has = true;
				}
				sm.updated = true;
			}
			l.anchor.local += (sm.local - sm.last) * amount;
			recheck_anchor(l);
		}
	}
	for (Smudge &sm : smudge) { // g.clearSmudgeCache
		if (sm.has) {
			sm.updated = false;
			sm.last = sm.local;
		}
	}
}

void SDTFluids::detach_container(int container) {
	for (int id : order) {
		Strand &s = strands[id];
		if (!s.alive) {
			continue;
		}
		for (Link &l : s.links) {
			if (l.anchored && l.anchor.container == container) {
				detach(l, false);
			}
		}
	}
}

void SDTFluids::clear(bool cum) {
	std::vector<int> ids = order;
	for (int id : ids) {
		if (strands[id].alive && strands[id].listed_cum == cum) {
			kill(id);
		}
	}
	cleanup();
}

bool SDTFluids::kill_oldest(bool cum) {
	for (int id : order) {
		if (strands[id].alive && strands[id].listed_cum == cum) {
			kill(id);
			cleanup();
			return true;
		}
	}
	return false;
}

int SDTFluids::count(bool cum) const {
	int n = 0;
	for (int id : order) {
		if (strands[id].alive && strands[id].listed_cum == cum) {
			n += 1;
		}
	}
	return n;
}

PackedFloat32Array SDTFluids::alphas(bool cum) const {
	PackedFloat32Array out;
	for (int id : order) {
		if (strands[id].alive && strands[id].listed_cum == cum) {
			out.push_back(alpha_of(strands[id]));
		}
	}
	return out;
}

void SDTFluids::add_ages(bool cum, const PackedInt32Array &amounts) {
	int i = 0;
	for (int id : order) {
		if (i >= amounts.size()) {
			break;
		}
		if (strands[id].alive && strands[id].listed_cum == cum) {
			strands[id].age += amounts[i];
			i += 1;
		}
	}
}

PackedVector2Array SDTFluids::get_points(int id) const {
	PackedVector2Array out;
	if (id >= 0 && id < (int)strands.size()) {
		for (const Link &l : strands[id].links) {
			out.push_back(l.p);
		}
	}
	return out;
}

Array SDTFluids::get_state() const {
	Array out;
	for (int id : order) {
		const Strand &s = strands[id];
		if (!s.alive) {
			continue;
		}
		int anchored = 0;
		for (const Link &l : s.links) {
			anchored += l.anchored ? 1 : 0;
		}
		Array e;
		e.push_back(s.layer);
		e.push_back(s.cum);
		e.push_back((int)s.links.size());
		e.push_back(anchored);
		e.push_back(s.age);
		e.push_back(s.age_max);
		e.push_back(alpha_of(s));
		out.push_back(e);
	}
	return out;
}
