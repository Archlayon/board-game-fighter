shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 base_color : source_color = vec4(0.72, 0.48, 0.16, 1.0);
uniform vec3 rim_color : source_color = vec3(1.0, 0.6, 0.2);
uniform float rim_strength = 0.35;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.82;
	SPECULAR = 0.22;
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	EMISSION = rim_color * rim * rim_strength;
}
