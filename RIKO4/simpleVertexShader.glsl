#version 330 core

layout(location = 0) in vec3 vertexPosition_modelspace;

varying vec4 colorv;

void main() {
  gl_Position.xyz = vertexPosition_modelspace;
  gl_Position.w = 1.0;
  colorv = gl_Color;
}