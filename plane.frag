#version 400 core
in vec3 coord;

out vec3 color;

void main() {
    color = vec3(1-8*coord.x,1-8*coord.x,0.6);
}
