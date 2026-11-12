#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/transform2d.hpp>

#include <deque>
#include <vector>

using namespace godot;

// The spit / cum strands (obj.Strand, obj.StrandLink) simulated in one place, as plain data: links are structs,
// not objects, and one call ticks every strand. Positions are in scene space (the strand layers share the scene
// layer's transform). Body parts are "containers" registered once by GDScript (StrandControl), which sends their
// transforms (container space -> scene space) every tick, plus the collision targets in test order. Game effects
// (cum on her face, eye hits, the tongue, drips) come back as events for GDScript to apply.
class SDTFluids : public RefCounted {
	GDCLASS(SDTFluids, RefCounted)

public:
	struct Anchor {
		int container = -1;
		int hit_target = -1; // the original hit target (the tongue for its tip point), else -1 = the container
		Vector2 local;
		bool force = true;
		bool eye = false;
	};

	struct Link {
		Vector2 p, speed;
		Vector2 prev;            // position at the start of the tick (drawing interpolates prev -> p like the body)
		bool prev_valid = false;
		float mass = 0.01f, density = 1.0f;
		float min_mass = 0.01f, min_density = 0.2f;
		int anchor_age = 0, collision_free = 0, anchor_delay = 0;
		int slide_counter = 0, slide_max = 45, smear_counter = 0, max_smear = 150;
		bool on_eye = false, anchored = false, just_anchored = false, source = false, on_tongue = false, freed = false;
		bool slide_on_anchor = false, sliding = false, generate_mass = false, expanded = false;
		Anchor anchor;
	};

	struct Strand {
		std::vector<Link> links;
		int layer = 0;
		bool alive = false, cum = false, listed_cum = false, has_source = false, disappear = false, handle = false;
		int age = 0, age_max = 600, dist_split_delay = 0, collision_free = 0;
		float gravity = 0.0f, lm = 0.0f, move_smoothing = 8.0f, max_dist = 120.0f * 120.0f, max_interp = 1000.0f;
	};

	struct Container {
		ObjectID obj;
		Transform2D to_scene, from_scene;
		int flags = 0;
	};

	struct Target {
		ObjectID obj;           // shape-tested object
		Transform2D from_scene; // scene space -> its space
		int anchor = -1;        // container the link anchors to
		int hit_target = -1;
		bool force = false;
		int kind = 0;           // TARGET_*
		std::vector<Rect2> need; // the point must be inside all of these (scene space bounds pre-tests)
		ObjectID exclude;        // ... and must not hit this one (shape)
		Transform2D exclude_from_scene;
		Rect2 eye;               // KIND_FACE: eye hit box bounds (scene space)
	};

	enum ContainerFlags { IN_HEAD = 1, HIM = 2, SCENE = 4, TONGUE_TIP = 8 };
	enum TargetKind { TARGET_PLAIN = 0, TARGET_FACE = 1, TARGET_TONGUE = 2 };
	enum EventType { EV_CUM_ON_FACE = 0, EV_EYE_HIT = 1, EV_EYE_CLEAR = 2, EV_TONGUE_CUM_HIT = 3, EV_TONGUE_CUM_REMOVED = 4,
		EV_DROPLET = 5 };

private:
	std::deque<Strand> strands;     // id = index (a deque: references stay valid while splits add strands)
	std::vector<int> free_ids;
	std::vector<int> order;         // ids in creation order (drawing order)
	std::vector<Container> containers;
	std::vector<Target> targets;
	Array events;
	// tick parameters (set_params)
	float gravity = 0.0f, friction = 1.0f, max_mass = 1.0f, mass_generate_speed = 0.0f, mass_flow = 0.0f;
	int max_strand_length = 1000;
	float kill_y = 1e9f, floor_y = 1220.0f;
	bool him_ejaculating = false;
	Color cum_rgb = Color(1, 1, 1);
	float cum_min_thickness = 1.0f; // a cum link is drawn at least this thick (the game: 1, like spit)
	int face = -1, jaw = -1, eye_box = -1, scene = -1;
	int64_t tick_key = 0;
	// smear cache (g.smudgeCache): per container, the smear point in its space this tick and last tick
	struct Smudge {
		Vector2 local, last;
		bool has = false, updated = false;
	};
	std::vector<Smudge> smudge;
	// Everything a layer's mesh is built from (the build is a pure function of it), to skip identical rebuilds.
	struct MeshStrand {
		int start, n;
		Color rgb;
		float alpha, max_interp;
	};
	struct MeshInput {
		std::vector<Vector2> pos;
		std::vector<float> thick, dens;
		std::vector<MeshStrand> strands;
		bool operator==(const MeshInput &o) const; // bitwise
	};
	std::vector<MeshInput> last_input; // per layer, of the last get_mesh_changed build
	std::vector<uint8_t> last_valid;

	void mesh_input(int layer, double fraction, MeshInput &in) const;
	static Array build_mesh(const MeshInput &in);

	int alloc();
	Link make_link(float mass, float density, Vector2 speed, int collision_free, bool slide) const;
	Link clone_link(const Link &l);
	Vector2 anchor_point(const Link &l) const;
	bool shape_hit(int container, Vector2 p) const;
	bool obj_hit(const ObjectID &obj, const Transform2D &from_scene, Vector2 p) const;
	void anchor_to(Strand &s, int li, const Anchor &a, bool is_source = false, bool delay_on_detach = true, bool keep_counter = false);
	void detach(Link &l, bool free_ = true, bool delay = true);
	bool anchorable(const Link &l) const;
	void recheck_anchor(Link &l);
	void link_tick(Strand &s, int li);
	bool collide(Strand &s, int li, Anchor &out);
	bool tongue_collide(Strand &s, int li);
	int split(int id, int at, bool add_middle = true, bool remove_first = false); // returns 1 if the strand died
	void expand(int id, int li);
	void kill(int id);
	void cleanup(); // drops dead strands from the order, frees the slots nobody holds
	void update(int id);
	void event(int type, const Array &args = Array());
	float alpha_of(const Strand &s) const;
	float thickness(const Strand &s, int li) const;

protected:
	static void _bind_methods();

public:
	int add_container(Object *obj, int flags);
	void set_container_object(int index, Object *obj);
	void set_special(int face, int jaw, int eye_box, int scene);
	void set_transforms(const Array &transforms); // Transform2D per container (container -> scene)
	void set_targets(const Array &targets);       // Dictionaries, see StrandControl
	void set_params(const Dictionary &params);

	int new_strand(int layer, int links, double mass, const Variant &top, const Variant &bottom, bool top_source,
			bool disappear, const Variant &initial_speed);
	int new_cum_strand(int layer, double mass, const Vector2 &p, int container);
	void add_source_link(int id, const Vector2 &p, int container, bool cum);
	void insert_link(int id, const Vector2 &v, int delay, double mass);
	void detach_source_link(int id, const Vector2 &v, int delay);
	void set_gravity(int id, double gravity);
	double get_gravity(int id) const;
	void set_collision_free(int id, int n);
	int get_collision_free(int id) const;
	void release(int id);
	bool is_alive(int id) const;

	Array tick();                       // events of this tick (and of smear / clear since the last call)
	Array take_events();
	Array get_mesh(int layer, double fraction) const; // [points, colors, indices, bounds] of all strands in that
	                                                   // layer, links at prev + (p - prev) * fraction
	Array get_mesh_changed(int layer, double fraction); // get_mesh, or an empty Array when that would be bit for bit
	                                                     // the mesh this returned last time for the layer
	void smear(const Vector2 &p, double radius);
	void detach_container(int container);
	void clear(bool cum);
	bool kill_oldest(bool cum); // the oldest live spit / cum strand; false when there is none
	int count(bool cum) const;
	PackedFloat32Array alphas(bool cum) const;               // live spit / cum strands' alpha, oldest first
	void add_ages(bool cum, const PackedInt32Array &amounts); // ages the oldest live ones: amounts[i] to the i-th
	PackedVector2Array get_points(int id) const; // tests
	Array get_state() const;                     // tests / dumps: per alive strand [layer, cum, links, anchored]
};
