import core.stdc.string;
import derelict.opengl3.gl3;
//import Font;
import matrix4x4;
import mesh;
import shader;
import std.stdio;
import std.string;
import texture;
import vec3;
import dirlight;

public align(1) struct Vertex
{
    float[ 3 ] pos;
    float[ 2 ] uv;
    float[ 3 ] normal;
}

public align(1) struct Face
{
    ushort a, b, c;
}

extern(System) private
{
    nothrow void loggingCallbackOpenGL( GLenum source, GLenum type, GLuint id, GLenum severity,
                                        GLsizei length, const(GLchar)* message, GLvoid* userParam )
    {
        const int undefinedSeverity = 33387;

        string sourceFmt = "UNDEFINED(0x%04X)";

        switch (source)
        {
            case GL_DEBUG_SOURCE_API_ARB:             sourceFmt = "API"; break;
            case GL_DEBUG_SOURCE_WINDOW_SYSTEM_ARB:   sourceFmt = "WINDOW_SYSTEM"; break;
            case GL_DEBUG_SOURCE_SHADER_COMPILER_ARB: sourceFmt = "SHADER_COMPILER"; break;
            case GL_DEBUG_SOURCE_THIRD_PARTY_ARB:     sourceFmt = "THIRD_PARTY"; break;
            case GL_DEBUG_SOURCE_APPLICATION_ARB:     sourceFmt = "APPLICATION"; break;
            case GL_DEBUG_SOURCE_OTHER_ARB:           sourceFmt = "OTHER"; break;
            default: break;
        }

        string typeFmt = "UNDEFINED(0x%04X)";

        switch (type)
        {
            case GL_DEBUG_TYPE_ERROR_ARB:               typeFmt = "ERROR"; break;
            case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR_ARB: typeFmt = "DEPRECATED_BEHAVIOR"; break;
            case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR_ARB:  typeFmt = "UNDEFINED_BEHAVIOR"; break;
            case GL_DEBUG_TYPE_PORTABILITY_ARB:         typeFmt = "PORTABILITY"; break;
            case GL_DEBUG_TYPE_PERFORMANCE_ARB:         typeFmt = "PERFORMANCE"; break;
            case GL_DEBUG_TYPE_OTHER_ARB:               typeFmt = "OTHER"; break;
            default: break;
        }

        string severityFmt = "UNDEFINED";

        switch (severity)
        {
            case GL_DEBUG_SEVERITY_HIGH_ARB:   severityFmt = "HIGH";   break;
            case GL_DEBUG_SEVERITY_MEDIUM_ARB: severityFmt = "MEDIUM"; break;
            case GL_DEBUG_SEVERITY_LOW_ARB:    severityFmt = "LOW"; break;
            default: break;
        }

        const(char)[] text = fromStringz( message );

        const int nvidiaPerfWarningId = 131185;

        try
        {
            if (id != nvidiaPerfWarningId)
            {
                writefln( "OpenGL: %s [source=%s type=%s severity=%s id=%u", text, sourceFmt, typeFmt, severityFmt, id );
            }
        }
        catch(Exception e)
        {
        }

        if (severity != undefinedSeverity && severity != GL_DEBUG_SEVERITY_LOW_ARB)
        {
            assert( false );
        }
    }
}

private align(1) struct LightUBO
{
    Vec3 lightDirectionInView;
}

public align(1) struct PerObjectUBO
{
    Matrix4x4 modelToClip;
    Matrix4x4 modelToView;
}

public align(1) struct TextureUBO
{
    GLuint64[ 10 ] textures;
}

public class Lines
{
    this( Vec3[] lines )
    {
        assert( lines.length > 0, "empty lines" );

        glCreateVertexArrays( 1, &vao );
        glBindVertexArray( vao );
        glObjectLabel( GL_VERTEX_ARRAY, vao, -1, toStringz( "lineVao" ) );

        uint vbo;
        glCreateBuffers( 1, &vbo );
        glObjectLabel( GL_BUFFER, vbo, -1, toStringz( "lineVbo" ) );

        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( vbo, lines.length * Vec3.sizeof, lines.ptr, flags );
        glVertexArrayVertexBuffer( vao, 0, vbo, 0, Vec3.sizeof );

        glEnableVertexArrayAttrib( vao, 0 );
        glVertexArrayAttribFormat( vao, 0, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 0, 0 );

        elementCount = cast(uint)lines.length;

        glCreateBuffers( 1, &ubo );
        glNamedBufferStorage( ubo, uboStruct.sizeof, &uboStruct, flags );
    }

    public void updateUBO( Matrix4x4 projection, Matrix4x4 view )
    {
        Matrix4x4 mvp;
        mvp.makeIdentity();
        multiply( mvp, view, mvp );
        uboStruct.modelToView = mvp;
        multiply( mvp, projection, mvp );
        uboStruct.modelToClip = mvp;

        GLvoid* mappedMem = glMapNamedBuffer( ubo, GL_WRITE_ONLY );
        memcpy( mappedMem, &uboStruct, PerObjectUBO.sizeof );
        glUnmapNamedBuffer( ubo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 0, ubo );
    }

    public int getElementCount() const
    {
        return elementCount;
    }

    public void bind()
    {
        glBindVertexArray( vao );
    }

    private uint vao;
    private uint elementCount;
    private uint ubo;
    private PerObjectUBO uboStruct;
}

public abstract class Renderer
{
    public static void initGL()
    {
        Texture.loadExtensionFunctions();
        Shader.loadExtensionFunctions();

        glDebugMessageCallback( &loggingCallbackOpenGL, null );
        glDebugMessageControl( GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE );
        glEnable( GL_DEBUG_OUTPUT );
        glEnable( GL_DEBUG_OUTPUT_SYNCHRONOUS );
        glEnable( GL_FRAMEBUFFER_SRGB );
        glEnable( GL_CULL_FACE );
        glEnable( GL_DEPTH_TEST );
        glDepthFunc( GL_LESS );

        glClipControl( GL_LOWER_LEFT, GL_ZERO_TO_ONE );
        glClearColor( 0, 0, 0, 1 );

        glCreateBuffers( 1, &lightUbo );
        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( lightUbo, LightUBO.sizeof, &lightUboStruct, flags );

        glCreateBuffers( 1, &textureUbo );
        glNamedBufferStorage( textureUbo, TextureUBO.sizeof, &textureUboStruct, flags );
    }

    /*public static void drawText( string text, Font font, Texture fontTex, float x, float y )
    {
        if (text != cachedText)
        {     
            Vertex[] vertices;
            Face[] faces;
            font.getGeometry( text, fontTex.getWidth(), fontTex.getHeight(), vertices, faces );
            generateVAO( vertices, faces, "textVAO", textVao );

            cachedText = text;
            textFaceLength = cast(int)faces.length;
        }

        fontTex.Bind();

        shader.Use();

        Matrix4x4 mvp;
        mvp.MakeIdentity();
        //mvp.Scale( xScale, yScale, 1 );
        mvp.Translate( Vec3.Vec3( x, y, 0 ) );
        Matrix4x4.Multiply( mvp, orthoMat, mvp );
        shader.SetMatrix44( "mvp", mvp.m );

        drawVAO( textVAO, textFaceLength * 3, [ 1, 1, 1, 1 ] );
    }*/

    private static void updateLightUbo( Vec3 lightDirectionInView )
    {
        lightUboStruct.lightDirectionInView = lightDirectionInView;

        GLvoid* mappedMem = glMapNamedBuffer( lightUbo, GL_WRITE_ONLY );
        memcpy( mappedMem, &lightUboStruct, LightUBO.sizeof );
        glUnmapNamedBuffer( lightUbo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 1, lightUbo );
    }

    public static void updateTextureUbo( GLuint64[ 10 ] textures )
	{
		textureUboStruct.textures = textures;

		GLvoid* mappedMem = glMapNamedBuffer( textureUbo, GL_WRITE_ONLY );
		memcpy( mappedMem, &textureUboStruct, TextureUBO.sizeof );
        glUnmapNamedBuffer( textureUbo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 2, textureUbo );
	}

    public static void clearScreen()
    {
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    }

    public static void renderLines( Lines lines, Shader shader )
    {
        lines.bind();
        shader.use();
        glDrawArrays( GL_LINES, 0, lines.getElementCount() * 2 );
    }

    public static void renderMesh( Mesh mesh, Texture texture, Shader shader, DirectionalLight light )
    {
        updateLightUbo( Vec3( 0, 1, 0 ) );

        for (int subMeshIndex = 0; subMeshIndex < mesh.getSubMeshCount(); ++subMeshIndex)
        {
            mesh.bind( subMeshIndex );
            texture.bind( 0 );
            shader.use();
            glDrawElements( GL_TRIANGLES, mesh.getElementCount( subMeshIndex ) * 3, GL_UNSIGNED_SHORT, null );
        }
    }

    public static void generateVAO( Vertex[] vertices, Face[] faces, string debugName, out uint vao )
    {
        glCreateVertexArrays( 1, &vao );
        glBindVertexArray( vao );
        glObjectLabel( GL_VERTEX_ARRAY, vao, -1, toStringz( debugName ) );

        uint vbo, ibo;
        glCreateBuffers( 1, &vbo );
        glObjectLabel( GL_BUFFER, vbo, -1, toStringz( "vbo" ) );

        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( vbo, vertices.length * Vertex.sizeof, vertices.ptr, flags );
        glVertexArrayVertexBuffer( vao, 0, vbo, 0, Vertex.sizeof );
        glVertexArrayVertexBuffer( vao, 1, vbo, 3 * 4, Vertex.sizeof );
        glVertexArrayVertexBuffer( vao, 2, vbo, (2 + 3) * 4, Vertex.sizeof );

        glCreateBuffers( 1, &ibo );
        glObjectLabel( GL_BUFFER, ibo, -1, toStringz( "ibo" ) );

        glNamedBufferStorage( ibo, faces.length * Face.sizeof, faces.ptr, flags );
        glVertexArrayElementBuffer( vao, ibo );

        glEnableVertexArrayAttrib( vao, 0 );
        glVertexArrayAttribFormat( vao, 0, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 0, 0 );

        glEnableVertexArrayAttrib( vao, 1 );
        glVertexArrayAttribFormat( vao, 1, 2, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 1, 1 );

        glEnableVertexArrayAttrib( vao, 2 );
        glVertexArrayAttribFormat( vao, 2, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 2, 2 );
    }

    private static LightUBO lightUboStruct;
    private static uint lightUbo;
    private static TextureUBO textureUboStruct;
    private static uint textureUbo;
    private static uint textVao;
}
