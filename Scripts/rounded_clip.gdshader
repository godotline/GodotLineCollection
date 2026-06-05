shader_type canvas_item;

uniform float radius : hint_range(0, 500) = 14.0;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform vec4 bg_color : source_color = vec4(0.08, 0.08, 0.13, 0.85);
uniform vec4 border_color : source_color = vec4(0.25, 0.3, 0.45, 0.4);
uniform float border_width : hint_range(0, 50) = 1.0;

// 圆角矩形 SDF (Inigo Quilez)
float sd_rounded_rect(vec2 p, vec2 size, float r) {
	vec2 half = size * 0.5;
	vec2 q = abs(p - half) - half + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * rect_size;

	// ---- 宽高比校正 (keep-aspect-cover) ----
	vec2 tps = TEXTURE_PIXEL_SIZE;
	vec4 tex_color;
	if (tps.x > 0.0 && tps.y > 0.0) {
		vec2 tex_size = 1.0 / tps;
		float tex_aspect = tex_size.x / tex_size.y;
		float r_aspect = rect_size.x / rect_size.y;

		vec2 cover_uv = UV;
		if (tex_aspect > r_aspect) {
			// 纹理更宽：匹配高度，左右裁剪
			float s = tex_aspect / r_aspect;
			cover_uv.x = (UV.x - 0.5) * s + 0.5;
		} else if (tex_aspect < r_aspect) {
			// 纹理更高：匹配宽度，上下裁剪
			float s = r_aspect / tex_aspect;
			cover_uv.y = (UV.y - 0.5) * s + 0.5;
		}
		tex_color = texture(TEXTURE, clamp(cover_uv, 0.0, 1.0));
	} else {
		tex_color = texture(TEXTURE, UV);
	}

	// ---- 圆角裁剪 ----
	float d_outer = sd_rounded_rect(px, rect_size, radius);
	float outer_a = 1.0 - smoothstep(0.0, 1.5, max(d_outer, 0.0));

	float inner_r = max(0.0, radius - border_width);
	float d_inner = sd_rounded_rect(px, rect_size, inner_r);
	float inner_a = 1.0 - smoothstep(0.0, 1.5, max(d_inner, 0.0));

	// ---- 合成 ----
	vec4 bg = bg_color;
	bg.a *= outer_a;

	tex_color.a *= inner_a;

	float border_a = outer_a - inner_a;
	tex_color = mix(tex_color, vec4(border_color.rgb, border_color.a), border_a);

	COLOR = mix(bg, tex_color, tex_color.a);
}
