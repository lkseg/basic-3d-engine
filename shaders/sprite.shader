#version 330 core
#VERTEX

layout(location=0) in vec3 position;
layout(location=1) in vec2 uv;
layout(location=2) in vec3 normal;
layout(location=3) in vec4 color;



out vec4 v_color;
out vec3 world_normal;
out vec3 world_position;
out vec3 local_position;
out vec2 v_uv;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;
uniform mat4 view_2d;

void main() {
	vec2 ulc = position.xy; //+ vec2(0.5, -0.5);
	mat4 model_2d = model;
	// transform the position from our screen_space to gl_style screen_space first
	vec2 half_screen = vec2(view_2d[0].x, view_2d[1].y);
	
	vec2 pos = model[3].xy - 1/half_screen;
	
	model_2d[3].xy = vec2(pos.x, -pos.y);
	// model_2d[0].x = model_2d[0].x;
	//  model_2d[3].y = -model[3].y;
	mat4 clip = view_2d * model_2d;
	// clip[3].y = -clip[3].y;
	vec4 p = clip * vec4(ulc, 0, 1);
	// gl_Position = vec4(p, 0);
	gl_Position = vec4(p.x, p.y,0, 1); 
	 
	v_uv = uv;  
	v_color = color;
	//vec4(gl_Position.z, 0, 0, 1);
	// vec4 n = transpose(inverse(view * model))* vec4(normal, 1);
	//vec4 n = transpose(inverse(view*model)) * vec4(normal, 1);
 	    
	// vec4 v = model * vec4(position, 1);
	// world_position = v.xyz;//vec3(v)/v.w;  
	// local_position = position;   
}

#FRAGMENT

in vec4 v_color;
in vec3 local_position;
in vec3 world_normal;
in vec3 world_position;

in vec2 v_uv;
out vec4 f_color;


uniform sampler2D texture0;
uniform vec4 tint;
// const float PI = 3.14159265359;

void main() {
	vec2 uv = v_uv;
	
	f_color =  texture(texture0, uv) * tint;
	// f_color = vec4(1,1,1,1);
}
