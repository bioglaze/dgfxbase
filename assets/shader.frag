#version 450 core
#extension GL_ARB_bindless_texture : require

//layout(binding=0) uniform sampler2D sTexture;

layout(std140, binding=1) uniform LightUbo
{
    vec3 lightDirectionVS;
};

layout(std140, binding=2) uniform TextureUBO
{
    sampler2D samplers[ 10 ];
};

in vec2 vUV;
in vec3 vNormalVS;
out vec4 fragColor;

void main()
{
    //fragColor = vec4( 1.0f, 0.0f, 0.0f, 1.0f );
    vec2 uv = vUV;
    uv.y = 1.0 - uv.y;
    //fragColor = texture( sTexture, uv ) * max( 0.2, dot( lightDirectionVS, vNormalVS ) );
    fragColor = texture( samplers[ 0 ], uv ) * max( 0.2, dot( lightDirectionVS, vNormalVS ) );
}

