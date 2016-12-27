#version 450 core

uniform sampler2D sTexture;

in vec2 vUV;
out vec4 fragColor;

void main()
{
    //fragColor = vec4( 1.0f, 0.0f, 0.0f, 1.0f );
    vec2 uv = vUV;
    uv.y = 1.0 - uv.y;
    fragColor = texture( sTexture, uv );
}

