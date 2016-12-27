import derelict.opengl3.gl3;
import std.stdio;
import std.string;

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

        if (severity != undefinedSeverity)
        {
            assert( false );
        }
    }
}

public class Renderer
{
    this()
    {
        if (KHR_debug())
        {
            glDebugMessageCallback( &loggingCallbackOpenGL, null );
            glEnable( GL_DEBUG_OUTPUT );
            glDebugMessageControl( GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE );
        }
        else
        {
            writeln( "Could not enable debug logging." );
        }

        glClipControl( GL_LOWER_LEFT, GL_ZERO_TO_ONE );
        glClearColor( 1, 0, 0, 1 );
    }

    public static void generateVAO( Vertex[] vertices, Face[] faces, string debugName, out uint vao )
    {
        glGenVertexArrays( 1, &vao );
        glBindVertexArray( vao );

        uint vbo, ibo;
        glGenBuffers( 1, &vbo );
        glBindBuffer( GL_ARRAY_BUFFER, vbo );
        const(char*) str = "vbo";
        //glObjectLabel( GL_BUFFER, vbo, -1, 1, str );

        GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glBufferStorage( GL_ARRAY_BUFFER, vertices.length * Vertex.sizeof, vertices.ptr, flags );

        glGenBuffers( 1, &ibo );
        glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, ibo );
        const(char*) str2 = "ibo";
        //glObjectLabel( GL_BUFFER, ibo, -1, 1, str2 );

        flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glBufferStorage( GL_ELEMENT_ARRAY_BUFFER, faces.length * Face.sizeof, faces.ptr, flags );

        glEnableVertexAttribArray( 0 );
        glVertexAttribPointer( 0, 3, GL_FLOAT, GL_FALSE, Vertex.sizeof, null );

        glEnableVertexAttribArray( 1 );
        glVertexAttribPointer( 1, 2, GL_FLOAT, GL_FALSE, Vertex.sizeof, cast(char*)0 + 3 * 4 );
    }
}
