shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 aura_color : source_color = vec4(0.12, 0.72, 1.0, 0.82);
uniform vec4 core_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float edge_cutoff : hint_range(0.0, 1.0) = 0.18;
uniform float core_radius : hint_range(0.05, 0.95) = 0.42;
uniform float toon_split : hint_range(0.0, 1.0) = 0.52;
uniform float fresnel_power : hint_range(0.1, 8.0) = 2.2;

void vertex() {
	// Preserve each particle's scale while orienting its quad to the viewport.
	vec3 scale = vec3(
		length(MODELVIEW_MATRIX[0].xyz),
		length(MODELVIEW_MATRIX[1].xyz),
		length(MODELVIEW_MATRIX[2].xyz)
	);
	MODELVIEW_MATRIX[0].xyz = INV_VIEW_MATRIX[0].xyz * scale.x;
	MODELVIEW_MATRIX[1].xyz = INV_VIEW_MATRIX[1].xyz * scale.y;
	MODELVIEW_MATRIX[2].xyz = INV_VIEW_MATRIX[2].xyz * scale.z;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float mask = 1.0 - smoothstep(1.0 - edge_cutoff, 1.0, radius);
	if (mask < 0.04) {
		discard;
	}
	float core = step(radius, core_radius);
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), fresnel_power);
	float toon_band = step(toon_split, fresnel);
	vec3 color = mix(aura_color.rgb, core_color.rgb, core);
	color = mix(color, aura_color.rgb, toon_band * (1.0 - core));
	ALBEDO = color;
	EMISSION = color * mix(0.45, 1.8, core + toon_band * 0.35);
	ALPHA = mask * mix(aura_color.a, core_color.a, core);
}
