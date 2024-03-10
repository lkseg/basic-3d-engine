#version 330 core
#VERTEX

layout(location=0) in vec3 position;
layout(location=1) in vec2 uv;
layout(location=2) in vec3 normal;
layout(location=3) in vec4 color;

out vec2 v_uv;


void main() {
	
	gl_Position = vec4(position.x, position.y,0, 1); 
	
	v_uv = uv;  
	
}

#FRAGMENT
in vec2 v_uv;
out vec4 f_color;


uniform sampler2D texture0; // screen

void main() {
	vec2 uv = v_uv;
	f_color =  texture(texture0, uv);
}
