#version 450 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;

layout(std140, binding=0) uniform PerObject
{
    mat4 mvp;
};

out vec2 vUV;

void main()
{
    gl_Position = mvp * vec4( inPosition, 1.0 );
    vUV = inUV;
}

