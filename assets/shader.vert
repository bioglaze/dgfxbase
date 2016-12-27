#version 450 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;

uniform PerObjectBlock
{
    mat4 mvp;
} PerObject;

out vec2 vUV;

void main()
{
    gl_Position = PerObject.mvp * vec4( inPosition, 1.0 );
    vUV = inUV;
}

