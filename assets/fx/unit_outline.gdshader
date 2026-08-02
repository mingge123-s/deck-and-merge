shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.06, 0.04, 0.03, 0.85);
uniform float outline_width = 5.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 offset = outline_width * TEXTURE_PIXEL_SIZE;
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, -offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(offset.x, offset.y)).a);
	COLOR = color.a <= 0.001 && neighbor_alpha > 0.001 ? outline_color : color;
}
