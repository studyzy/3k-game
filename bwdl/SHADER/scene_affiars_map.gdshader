shader_type canvas_item;
render_mode unshaded;

uniform vec3 color_rgb = vec3(4,0.8,4);
uniform vec2 area_r = vec2(0,2);
uniform vec2 area_g = vec2(0.8,2.0);
uniform vec2 area_b = vec2(0,2);

void fragment(){
	COLOR = texture(TEXTURE,UV);
	if(COLOR.r>area_r.x && COLOR.r<area_r.y)
		if(COLOR.g>area_g.x && COLOR.g<area_g.y)
			if(COLOR.b>area_b.x && COLOR.b<area_b.y)
				COLOR.rgb*=color_rgb;
}