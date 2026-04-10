shader_type canvas_item;
render_mode unshaded;

uniform sampler2D source_tex : source_color, repeat_disable, filter_nearest;
uniform sampler2D ascii_atlas : source_color, repeat_disable, filter_nearest;
uniform sampler2D edge_atlas  : source_color, repeat_disable, filter_nearest;

// Размер клетки
uniform float cell_size : hint_range(4.0, 64.0) = 8.0;

// Обычный ASCII-атлас
uniform vec2 ascii_grid = vec2(8.0, 1.0);
uniform float glyph_count = 8.0;

// Edge-атлас: например 4x1 = | - / \
uniform vec2 edge_grid = vec2(4.0, 1.0);

// Маппинг яркости -> символ
uniform float atlas_mapping_power : hint_range(0.1, 4.0) = 1.0;
uniform float atlas_mapping_bias : hint_range(-1.0, 1.0) = 0.0;
uniform bool invert_ramp = false;

// Визуал
uniform float min_cell_fill : hint_range(0.0, 1.0) = 0.2;
uniform float bg_strength : hint_range(0.0, 1.0) = 0.25;
uniform float color_boost : hint_range(0.0, 8.0) = 1.0;

// Edge-параметры
uniform float edge_threshold : hint_range(0.0, 4.0) = 0.25;
uniform float edge_softness  : hint_range(0.001, 4.0) = 0.15;
uniform float edge_boost     : hint_range(0.0, 8.0) = 1.0;
uniform bool no_edges = false;
uniform bool no_fill = false;
uniform bool debug_edges = false;
uniform bool view_grid = false;

// Упрощённый DoG
uniform float dog_radius_small : hint_range(0.5, 4.0) = 1.0;
uniform float dog_radius_large : hint_range(1.0, 8.0) = 2.0;
uniform float dog_tau : hint_range(0.0, 4.0) = 1.0;

// Тон-коррекция
uniform float exposure : hint_range(0.0, 10.0) = 1.0;
uniform float attenuation : hint_range(0.0, 10.0) = 1.0;

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 clamp_cell_id(vec2 cell_id, vec2 cell_count) {
	return clamp(cell_id, vec2(0.0), cell_count - vec2(1.0));
}

vec3 sample_cell_color(vec2 cell_id, vec2 cell, vec2 tex_size, vec2 cell_count) {
	cell_id = clamp_cell_id(cell_id, cell_count);

	vec2 origin_px = cell_id * cell;

	vec2 p1 = (origin_px + cell * vec2(0.25, 0.25)) / tex_size;
	vec2 p2 = (origin_px + cell * vec2(0.75, 0.25)) / tex_size;
	vec2 p3 = (origin_px + cell * vec2(0.25, 0.75)) / tex_size;
	vec2 p4 = (origin_px + cell * vec2(0.75, 0.75)) / tex_size;

	vec3 c1 = texture(source_tex, p1).rgb;
	vec3 c2 = texture(source_tex, p2).rgb;
	vec3 c3 = texture(source_tex, p3).rgb;
	vec3 c4 = texture(source_tex, p4).rgb;

	return (c1 + c2 + c3 + c4) * 0.25;
}

float sample_cell_luma(vec2 cell_id, vec2 cell, vec2 tex_size, vec2 cell_count) {
	return luminance(sample_cell_color(cell_id, cell, tex_size, cell_count));
}

// Дешёвая box-blur замена Gaussian
float blurred_luma(vec2 cell_id, vec2 cell, vec2 tex_size, vec2 cell_count, float radius) {
	vec2 r = vec2(radius);

	float s = 0.0;
	float w = 0.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offs = vec2(float(x), float(y)) * r;
			s += sample_cell_luma(cell_id + offs, cell, tex_size, cell_count);
			w += 1.0;
		}
	}

	return s / max(w, 1.0);
}

// Упрощённый DoG
float dog_value(vec2 cell_id, vec2 cell, vec2 tex_size, vec2 cell_count) {
	float small_b = blurred_luma(cell_id, cell, tex_size, cell_count, dog_radius_small);
	float large_b = blurred_luma(cell_id, cell, tex_size, cell_count, dog_radius_large);
	return small_b - large_b * dog_tau;
}

float sample_dog(vec2 cell_id, vec2 cell, vec2 tex_size, vec2 cell_count) {
	cell_id = clamp_cell_id(cell_id, cell_count);
	return dog_value(cell_id, cell, tex_size, cell_count);
}

vec2 sobel_on_dog(vec2 cell_id, vec2 cell, vec2 tex_size, vec2 cell_count) {
	float tl = sample_dog(cell_id + vec2(-1.0, -1.0), cell, tex_size, cell_count);
	float tc = sample_dog(cell_id + vec2( 0.0, -1.0), cell, tex_size, cell_count);
	float tr = sample_dog(cell_id + vec2( 1.0, -1.0), cell, tex_size, cell_count);

	float ml = sample_dog(cell_id + vec2(-1.0,  0.0), cell, tex_size, cell_count);
	float mr = sample_dog(cell_id + vec2( 1.0,  0.0), cell, tex_size, cell_count);

	float bl = sample_dog(cell_id + vec2(-1.0,  1.0), cell, tex_size, cell_count);
	float bc = sample_dog(cell_id + vec2( 0.0,  1.0), cell, tex_size, cell_count);
	float br = sample_dog(cell_id + vec2( 1.0,  1.0), cell, tex_size, cell_count);

	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;

	return vec2(gx, gy);
}

// 0 = |
// 1 = -
// 2 = /
// 3 = \
float quantize_edge_dir(vec2 grad) {
	if (length(grad) < 0.00001) {
		return 0.0;
	}

	// Символ должен лежать вдоль линии, а не поперёк градиента
	vec2 t = normalize(vec2(-grad.y, grad.x));

	float ax = abs(t.x);
	float ay = abs(t.y);

	if (ax > ay * 2.0) {
		return 1.0; // -
	} else if (ay > ax * 2.0) {
		return 0.0; // |
	} else {
		return (t.x * t.y > 0.0) ? 3.0 : 2.0; // \ или /
	}
}

float sample_from_grid(sampler2D atlas, vec2 grid, float glyph_index, vec2 local_uv) {
	float gx = mod(glyph_index, grid.x);
	float gy = floor(glyph_index / grid.x);
	vec2 glyph_uv = (vec2(gx, gy) + local_uv) / grid;
	return texture(atlas, glyph_uv).r;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 cell = vec2(cell_size);

	vec2 frag_px = UV * tex_size;
	vec2 cell_id = floor(frag_px / cell);
	vec2 local_uv = fract(frag_px / cell);

	vec2 cell_count = max(floor(tex_size / cell), vec2(1.0));

	vec3 src_col = sample_cell_color(cell_id, cell, tex_size, cell_count);
	float lum = clamp(luminance(src_col), 0.0, 1.0);

	// ===== Fill glyph =====
	float mapped_lum = clamp(lum + atlas_mapping_bias, 0.0, 1.0);
	mapped_lum = pow(mapped_lum, atlas_mapping_power);

	if (invert_ramp) {
		mapped_lum = 1.0 - mapped_lum;
	}

	float fill_glyph_index = floor(mapped_lum * (glyph_count - 1.0) + 0.0001);
	float fill_glyph = sample_from_grid(ascii_atlas, ascii_grid, fill_glyph_index, local_uv);
	fill_glyph = max(fill_glyph, min_cell_fill);

	// ===== Edge glyph =====
	vec2 grad = sobel_on_dog(cell_id, cell, tex_size, cell_count);
	float edge_strength = length(grad) * edge_boost;
	float edge_mask = smoothstep(edge_threshold, edge_threshold + edge_softness, edge_strength);

	if (no_edges) {
		edge_mask = 0.0;
	}

	float edge_index = quantize_edge_dir(grad);
	float edge_glyph = sample_from_grid(edge_atlas, edge_grid, edge_index, local_uv);

	// ===== Комбинация fill + edge =====
	float glyph = fill_glyph;

	if (no_fill) {
		glyph = 0.0;
	}

	glyph = mix(glyph, max(glyph, edge_glyph), edge_mask);

	// ===== Тон-коррекция =====
	vec3 lit_col = src_col * exposure;
	lit_col = lit_col / (vec3(1.0) + lit_col * max(attenuation, 0.0001));

	vec3 bg = lit_col * bg_strength;
	vec3 fg = lit_col * color_boost;

	vec3 final_col = mix(bg, fg, glyph);

	// ===== Debug режимы =====
	if (debug_edges) {
		final_col = vec3(edge_mask);
	} else if (view_grid) {
		vec2 dist_to_center = abs(local_uv - 0.5);
		float g = step(0.48, max(dist_to_center.x, dist_to_center.y));
		final_col = mix(final_col, vec3(1.0, 0.0, 0.0), g * 0.35);
	}

	COLOR = vec4(final_col, 1.0);
}