shader_type spatial;

// Screen-space outline expansion technique adapted from eldskald/godot4-cel-shader.
// Copyright (c) 2023 Rafael de Lima Bordoni. See assets/licenses/eldskald-cel-shader-MIT.txt.
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 outline_color : source_color = vec4(0.035, 0.025, 0.04, 1.0);
uniform float outline_width_pixels = 1.5;

void vertex() {
	vec4 mv_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_position = PROJECTION_MATRIX * mv_position;
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	clip_position.xy += normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_position.w * outline_width_pixels;
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
