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
out vec4 light_space_position;

flat out vec3 flat_position;
out vec2 v_uv;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;
uniform mat4 normal_view;
uniform mat4 normal_world;
uniform vec3 eye;
uniform mat4 light_space;
uniform sampler2D texture0;
uniform sampler2D texture1;

const float PI = 3.14159265359;

vec2 sphere_uv() {
	vec3 d = normalize(position);
	vec2 m;
	m.x = 0.5 + atan(d.x, d.z)/(2*PI);
	m.y = 0.5 + asin(d.y)/PI;
	return m;
}
void main() {
		
	gl_Position = (projection * view * model) * vec4(position, 1.0);
	v_uv = uv;
   
	vec4 n = normal_world * vec4(normal, 1);
	world_normal = normalize(n.xyz);

	vec4 v = model * vec4(position, 1);
	light_space_position = light_space * v;
	world_position = v.xyz;
	local_position = position;
	flat_position = position;
}


#FRAGMENT

in vec4 v_color;
in vec2 v_uv;

in vec3 local_position;
in vec3 world_normal;
in vec3 world_position;
in vec3 flat_position;
in vec4 light_space_position;
out vec4 f_color;

const vec3 light_position = vec3(0, 3, -4);
const vec3 light_color = vec3(0.2,0.2,0.5);
const float light_value = 40;
const vec3 ambient = vec3(0.05,0.05,0.05);
const vec3 _diffuse = vec3(0.5,0.2,0.2);
const vec3 specular = vec3(0.1,0,0);
const float shininess = 64.0;
uniform vec3 eye;
uniform vec4 tint;
uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;

const float PI = 3.14159265359;

vec4 get_texture_color() {
	/*
	  vec3 d = normalize(local_position);
	  vec2 uv;
	  uv.x = 0.5 + atan(d.x, d.z)/(2*PI);
	 uv.y = 0.5 + asin(d.y)/PI; */
	// return texture(texture0, v_uv);
	return tint;
}

float get_depth() {
	vec4 l = light_space_position;
	vec3 p = l.xyz/l.w;
	p = p*0.5+0.5;
	return texture(texture1, p.xy).r;
}
float get_current_depth() {
	vec4 l = light_space_position;
	vec3 p = l.xyz/l.w;
	p = p*0.5+0.5;
	return p.z;
}
float linear_depth(float d) {
	float ndc = d *2 - 1;
	float near = 1;
	float far  = 7;
	return (2*near*far)/ (far + near - ndc * (far - near));
}
float get_shadow_value(vec3 direction, vec3 normal) {
	float map = get_depth();
	float current = get_current_depth();
	float bias = max(0.05* (1-dot(normal, direction)), 0.005);
	bias = 0.0; // current scene too small :)
	float shadow = current - bias > map ? 1 : 0;
	return shadow;
}
void main() {
	
	vec3 diffuse = get_texture_color().xyz;
	vec3 n = world_normal;
	float len = length(light_position - world_position)*0.1;
	vec3 ldir = normalize(light_position - world_position);
	vec3 vdir = normalize(eye - world_position);
	vec3 hdir = normalize(ldir + vdir);
	float angle = max(0, dot(hdir, n));
	
	float lam = max(0, dot(ldir, n)); 
	float spec_value = 0;
	if (lam > 0) {
		spec_value = pow(angle, shininess);
	}
	float value = get_shadow_value(ldir, world_normal);
	vec3 col = ambient + (1-value)* (
	diffuse*lam*light_color*light_value/len + specular * spec_value * light_color *light_value/len);
   
   

	float depth = get_depth();
	
	f_color = vec4(col, 1);
	
}
