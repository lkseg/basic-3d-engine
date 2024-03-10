#version 330 core
layout (triangles) in;
layout (line_strip, max_vertices = 6) out;
uniform mat4 projection;
				   
in V_OUT {
   vec3 normal;
} var[];


out vec3 normal;
out float test;

const float magnitude = 0.2;

void make_line(int i) {
	gl_Position = projection * gl_in[i].gl_Position;
	EmitVertex();
	gl_Position = projection * (gl_in[i].gl_Position +  vec4(var[i].normal, 0) * magnitude);
	EmitVertex();
	normal = normalize(var[0].normal + var[1].normal + var[2].normal);
	test = 0.5;
	EndPrimitive();
}

void main() {
	make_line(0);
	make_line(1);
	make_line(2);
	
	
	
}
