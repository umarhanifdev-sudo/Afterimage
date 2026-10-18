shader_type spatial;
render_mode cull_back;
uniform float illumination = 0.0;
uniform float agitation = 0.0;
uniform float hurt = 0.0;
varying vec3 local_pos;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void vertex(){local_pos=VERTEX;}
void fragment(){
 float soot=hash(floor(local_pos*55.0));
 float seam=pow(abs(sin(local_pos.y*23.0+sin(local_pos.x*19.0)*3.0)),28.0);
 ALBEDO=vec3(.006,.008,.007)*(0.5+soot*.8)+vec3(.009,.008,.006)*seam;
 ROUGHNESS=.87+soot*.12;
 METALLIC=.08;
 EMISSION=vec3(.045,.008,.002)*agitation*seam+vec3(.018,.012,.007)*hurt;
}
