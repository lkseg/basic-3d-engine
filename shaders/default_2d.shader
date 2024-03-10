#version 330 core
#VERTEX

layout(location=0) in vec3 position;
layout(location=1) in vec2 uv;
layout(location=2) in vec3 normal;
layout(location=3) in vec4 color;

out vec2 v_uv;
out vec4 v_color;
void main() {
	
	vec3 v = position;
	// v += vec3(-0.5, 0.5,0);
    gl_Position = vec4(v.xy, 0, 1);
	// gl_Position = vec4(position, 1);
	v_uv = uv;
	v_color = color;
}

#FRAGMENT

in vec3 local_position;
in vec3 world_normal;
in vec3 world_position;

in vec2 v_uv;
in vec4 v_color;
out vec4 f_color;


uniform sampler2D texture0;
uniform vec4 tint;
// const float PI = 3.14159265359;

void main() {
	
	f_color = v_color;
}
