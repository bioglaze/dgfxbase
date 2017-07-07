#version 450 core
#extension GL_ARB_bindless_texture : require

//layout(binding=0) uniform sampler2D sTexture;

layout(std140, binding=0) uniform PerObject
{
    mat4 modelToClip;
    mat4 modelToView;
    int textureHandle;
};

layout(std140, binding=1) uniform LightUbo
{
    vec3 lightDirectionVS;
};

layout(std140, binding=2) uniform TextureUBO
{
    sampler2D samplers[ 32 ];
};

layout(location = 0) in vec2 vUV;
layout(location=0) out vec4 fragColor;

void main()
{
    //fragColor = vec4( 1.0f, 0.0f, 0.0f, 1.0f );
    vec2 uv = vUV;
    uv.y = 1.0 - uv.y;
    //fragColor = texture( sTexture, uv ) * max( 0.2, dot( lightDirectionVS, vNormalVS ) );
    fragColor = texture( samplers[ textureHandle ], uv );// * max( 0.2, dot( lightDirectionVS, vNormalVS ) );
}

