shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D palette : source_color, filter_nearest;
void fragment() {
	vec3 c=texture(palette,UV).rgb;
	float l=dot(c,vec3(0.2126,0.7152,0.0722));
	vec3 steel=mix(vec3(0.025,0.034,0.045),vec3(0.32,0.35,0.33),l);
	float accent=step(c.g*1.65,c.r)*step(0.25,c.r)*step(c.b*1.4,c.r);
	ALBEDO=mix(steel,vec3(0.08,0.075,0.062),accent);
	ROUGHNESS=0.53; METALLIC=0.65; SPECULAR=0.4;
}
