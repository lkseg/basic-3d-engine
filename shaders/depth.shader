#version 330 core
#VERTEX
layout(location=0) in vec3 position;
uniform mat4 light_space;
uniform mat4 model;
uniform mat4 projection;
uniform mat4 view;
void main() {
	gl_Position = light_space * model * vec4(position, 1);

}

#FRAGMENT

void main () {
	// gl_FragDepth = 0.8;
}
