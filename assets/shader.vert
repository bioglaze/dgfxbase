#version 450 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec3 inNormal;

layout(std140, binding=0) uniform PerObject
{
    mat4 modelToClip;
    mat4 modelToView;
    int textureHandle;
};

out vec2 vUV;
out vec3 vNormalVS;

void main()
{
    gl_Position = modelToClip * vec4( inPosition, 1.0 );
    vUV = inUV;
    vNormalVS = (modelToView * vec4( inNormal, 0 )).xyz;
}

