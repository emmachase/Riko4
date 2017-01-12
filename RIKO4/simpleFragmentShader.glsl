// shadertype=glsl

#version 330 core

varying vec4 colorv;

out vec3 color;

void main(){
  color = colorv;//vec3(1,0,0);
}
