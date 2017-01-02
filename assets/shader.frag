#version 450 core

layout(binding=0) uniform sampler2D sTexture;

layout(std140, binding=1) uniform LightUbo
{
    vec3 lightDirectionInView;
};

in vec2 vUV;
in vec3 vNormalInView;
out vec4 fragColor;

void main()
{
    //fragColor = vec4( 1.0f, 0.0f, 0.0f, 1.0f );
    vec2 uv = vUV;
    uv.y = 1.0 - uv.y;
    fragColor = texture( sTexture, uv ) * max( 0.2, dot( lightDirectionInView, vNormalInView ) );
}

