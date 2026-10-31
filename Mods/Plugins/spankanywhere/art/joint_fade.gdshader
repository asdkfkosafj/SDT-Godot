shader_type canvas_item;

// A mark in the other map (spankanywhere): faded by how far down her upper arm it lies, so the skin where arm and body
// meet (shoulder, armpit) takes marks from both and a mark goes on over the joint.
uniform vec3 along_row = vec3(0.0);   // map coordinates -> distance down her upper arm (from the joint)
uniform float fade_from = 100.0;
uniform float fade_to = 330.0;
varying float along;

void vertex() {
	along = dot(along_row, vec3((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy, 1.0));
}

void fragment() {
	// COLOR arrives as the image times the mark's tint
	COLOR.a *= 1.0 - smoothstep(fade_from, fade_to, along);
}
