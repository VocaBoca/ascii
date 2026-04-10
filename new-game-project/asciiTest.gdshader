shader_type canvas_item;
render_mode unshaded;

uniform sampler2D source_tex : source_color, repeat_disable, filter_nearest;
uniform sampler2D ascii_atlas : source_color, repeat_disable, filter_nearest;

// Один параметр размера клетки
uniform float cell_size : hint_range(4.0, 64.0) = 16.0;

// Сетка атласа, например 8x1, 4x4 и т.д.
uniform vec2 atlas_grid = vec2(8.0, 1.0);

// Сколько символов реально используем
uniform float glyph_count = 8.0;

// Настройка маппинга яркости -> символ
uniform float atlas_mapping_power : hint_range(0.1, 4.0) = 1.0;
uniform float atlas_mapping_bias : hint_range(-1.0, 1.0) = 0.0;
uniform bool invert_ramp = false;

// Визуальные настройки
uniform float min_cell_fill : hint_range(0.0, 1.0) = 0.35;
uniform float bg_strength : hint_range(0.0, 1.0) = 0.25;
uniform float color_boost : hint_range(0.0, 8.0) = 1.0;

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 cell = vec2(cell_size);

	// Размер входной текстуры
	vec2 tex_size = vec2(textureSize(source_tex, 0));

	// Текущий пиксель в координатах текстуры
	vec2 frag_px = UV * tex_size;

	// Индекс клетки
	vec2 cell_id = floor(frag_px / cell);
	vec2 cell_origin_px = cell_id * cell;

	// 4 сэмпла для усреднения
	vec2 p1 = (cell_origin_px + cell * vec2(0.25, 0.25)) / tex_size;
	vec2 p2 = (cell_origin_px + cell * vec2(0.75, 0.25)) / tex_size;
	vec2 p3 = (cell_origin_px + cell * vec2(0.25, 0.75)) / tex_size;
	vec2 p4 = (cell_origin_px + cell * vec2(0.75, 0.75)) / tex_size;

	vec3 c1 = texture(source_tex, p1).rgb;
	vec3 c2 = texture(source_tex, p2).rgb;
	vec3 c3 = texture(source_tex, p3).rgb;
	vec3 c4 = texture(source_tex, p4).rgb;

	vec3 src_col = (c1 + c2 + c3 + c4) * 0.25;

	// Яркость клетки
	float lum = clamp(luminance(src_col), 0.0, 1.0);

	// Маппинг яркости
	float mapped_lum = clamp(lum + atlas_mapping_bias, 0.0, 1.0);
	mapped_lum = pow(mapped_lum, atlas_mapping_power);

	if (invert_ramp) {
		mapped_lum = 1.0 - mapped_lum;
	}

	// Индекс символа
	float glyph_index = floor(mapped_lum * (glyph_count - 1.0) + 0.0001);

	// Координаты внутри клетки
	vec2 local_uv = fract(frag_px / cell);

	// Координаты символа в атласе
	float gx = mod(glyph_index, atlas_grid.x);
	float gy = floor(glyph_index / atlas_grid.x);
	vec2 glyph_uv = (vec2(gx, gy) + local_uv) / atlas_grid;

	// Символ из атласа
	float glyph = texture(ascii_atlas, glyph_uv).r;

	// Защита от слишком чёрных дыр
	glyph = max(glyph, min_cell_fill);

	// Цвет фона и символа
	vec3 bg = src_col * bg_strength;
	vec3 fg = src_col * color_boost;

	vec3 final_col = mix(bg, fg, glyph);

	COLOR = vec4(final_col, 1.0);
}