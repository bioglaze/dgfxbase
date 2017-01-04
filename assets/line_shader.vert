#version 450 core

layout(location = 0) in vec3 inPosition;

layout(std140, binding=0) uniform PerObject
{
    mat4 modelToClip;
};

void main()
{
    gl_Position = modelToClip * vec4( inPosition, 1.0 );
}

