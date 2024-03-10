#version 330 core
#VERTEX

layout(location=0) in vec3 position;
layout(location=1) in vec2 uv;
layout(location=2) in vec3 normal;
layout(location=3) in vec4 color;

out vec4 v_color;
out vec4 v_tint;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;
uniform mat4 normal_view;
uniform mat4 normal_world;
uniform vec3 eye;
uniform vec4 tint;

uniform sampler2D texture0;
uniform sampler2D texture1;

const float PI = 3.14159265359;


void main() {
	
	v_color = color;
	v_tint = tint;
	gl_Position = (projection * view * model) * vec4(position, 1.0);
}

#FRAGMENT
in vec4 v_color;
in vec2 v_uv;
in vec4 v_tint;

out vec4 f_color;







uniform sampler2D texture0;
uniform sampler2D texture1;

const float PI = 3.14159265359;

void main() {
	f_color = v_color*v_tint;
}
