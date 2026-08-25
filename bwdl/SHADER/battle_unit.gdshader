shader_type canvas_item;
render_mode unshaded;

uniform vec3 color_rgb = vec3(0.41,0.41,0.41);

void fragment(){
	COLOR = texture(TEXTURE,UV);
	COLOR.rgb=color_rgb;
}
