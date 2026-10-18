shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D silhouette : source_color;
uniform float seed = 0.0;
uniform float agitation = 0.0;
uniform float dissolve = 0.0;
uniform float illumination = 0.0;
uniform float variant = 0.0;
uniform float hurt = 0.0;
void vertex() {
 float h=1.0-UV.y;
 VERTEX.x+=sin(TIME*2.4+VERTEX.y*4.0+seed)*.026*h;
 VERTEX.x+=sin(TIME*39.0+seed)*.012*agitation*h;
}
void fragment() {
 vec2 uv=UV;
 uv.x+=sin(uv.y*36.0+TIME*2.0+seed)*.0017;
 vec4 c=texture(silhouette,uv);
 float grit=fract(sin(dot(floor(uv*200.0),vec2(12.9898,78.233)))*43758.5453);
 vec3 tint=variant>2.5?vec3(.67,.57,.45):(variant>1.5?vec3(.53,.65,.75):(variant>.5?vec3(.75,.55,.48):vec3(.68,.72,.71)));
 ALBEDO=c.rgb*tint*(.45+illumination*.85);
 ROUGHNESS=.95;
 EMISSION=c.rgb*.018 + vec3(.16,.012,.002)*agitation*c.a+vec3(.1,.09,.07)*hurt*c.a;
 float eyes=(1.0-smoothstep(.002,.006,distance(uv,vec2(.554,.074))))+(1.0-smoothstep(.002,.006,distance(uv,vec2(.592,.092))));
 EMISSION+=eyes*(variant>2.5?vec3(.4,.15,.04):vec3(.22,.27,.24));
 ALPHA=min(1.0,c.a*1.4)*step(dissolve,grit);
 ALPHA_SCISSOR_THRESHOLD=.065;
}
