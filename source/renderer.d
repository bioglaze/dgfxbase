import derelict.opengl3.gl3;
import mesh;
import shader;
import std.stdio;
import std.string;
import texture;
import vec3;

public align(1) struct Vertex
{
    float[ 3 ] pos;
    float[ 2 ] uv;
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

        try
        {
            writefln( "OpenGL: %s [source=%s type=%s severity=%s id=%u", text, sourceFmt, typeFmt, severityFmt, id );
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

struct AllTextures
{
    GLuint64[ 200 ] textures;
};

public abstract class Renderer
{
    public static void initGL()
    {
        glDebugMessageCallback( &loggingCallbackOpenGL, null );
        glDebugMessageControl( GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE );
        glEnable( GL_DEBUG_OUTPUT );
        glEnable( GL_DEBUG_OUTPUT_SYNCHRONOUS );
        glEnable( GL_CULL_FACE );

        glClipControl( GL_LOWER_LEFT, GL_ZERO_TO_ONE );
        glClearColor( 1, 0, 0, 1 );
    }

    public static void clearScreen()
    {
        glClear( GL_COLOR_BUFFER_BIT );
    }

    public static void renderMesh( Mesh mesh, Vec3 position, Texture texture, Shader shader )
    {
        texture.bind( 0 );
        shader.use();
        glDrawElements( GL_TRIANGLES, mesh.getElementCount() * 3, GL_UNSIGNED_SHORT, null );
    }

    public static void generateVAO( Vertex[] vertices, Face[] faces, string debugName, out uint vao )
    {
        glCreateVertexArrays( 1, &vao );
        glBindVertexArray( vao );

        uint vbo, ibo;
        glCreateBuffers( 1, &vbo );
        const(char*) str = "vbo";
        glObjectLabel( GL_BUFFER, vbo, -1, str );

        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( vbo, vertices.length * Vertex.sizeof, vertices.ptr, flags );
        glVertexArrayVertexBuffer( vao, 0, vbo, 0, Vertex.sizeof );
        glVertexArrayVertexBuffer( vao, 1, vbo, 3 * 4, Vertex.sizeof );

        glCreateBuffers( 1, &ibo );
        const(char*) str2 = "ibo";
        glObjectLabel( GL_BUFFER, ibo, -1, str2 );

        glNamedBufferStorage( ibo, faces.length * Face.sizeof, faces.ptr, flags );
        glVertexArrayElementBuffer( vao, ibo );

        glEnableVertexArrayAttrib( vao, 0 );
        glVertexArrayAttribFormat( vao, 0, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 0, 0 );

        glEnableVertexArrayAttrib( vao, 1 );
        glVertexArrayAttribFormat( vao, 1, 2, GL_FLOAT, GL_FALSE, 0/*3 * 4*/ );
        glVertexArrayAttribBinding( vao, 1, 0 );
    }
}
