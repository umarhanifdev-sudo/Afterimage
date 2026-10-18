shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float focus_blur = 0.0;
uniform float heat = 0.0;
uniform float motion = 1.0;
void fragment(){
 vec2 uv=SCREEN_UV;
 uv.x+=sin(uv.y*85.0+TIME*7.0)*.00025*heat*motion;
 uv.y+=sin(uv.x*75.0-TIME*6.0)*.00015*heat*motion;
 vec2 px=SCREEN_PIXEL_SIZE*focus_blur*3.5;
 vec3 c=texture(screen_texture,uv).rgb;
 if(focus_blur>.01){
 c*=.36;
 c+=(texture(screen_texture,uv+vec2(px.x,0)).rgb+texture(screen_texture,uv-vec2(px.x,0)).rgb+texture(screen_texture,uv+vec2(0,px.y)).rgb+texture(screen_texture,uv-vec2(0,px.y)).rgb)*.10;
 c+=(texture(screen_texture,uv+px).rgb+texture(screen_texture,uv-px).rgb+texture(screen_texture,uv+vec2(px.x,-px.y)).rgb+texture(screen_texture,uv+vec2(-px.x,px.y)).rgb)*.06;
 }
 float luminance=dot(c,vec3(.2126,.7152,.0722));
 c=mix(vec3(luminance),c,.86)*vec3(1.01,1.005,.985);
 float edge=smoothstep(.2,.82,length((uv-.5)*vec2(1.1,.9)));
 float grain=fract(sin(dot(uv*vec2(1280.0,720.0)+fract(TIME)*31.0,vec2(12.9898,78.233)))*43758.5453)-.5;
 c*=1.0-edge*.4;
 COLOR=vec4(c+grain*.004,1.0);
}
