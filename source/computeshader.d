import derelict.opengl3.gl3;
import shader;
import std.exception;
import std.file;
import std.stdio;
import std.string;

class ComputeShader
{
    this( string vertexPath, string fragmentPath )
    {
        try
        {
            program = glCreateProgram();
            compile( cast(string)read( vertexPath ) );
            link();
        }
        catch (Exception e)
        {
            writeln( "Could not open or compile " ~ vertexPath ~ " or " ~ fragmentPath );
        }
    }

    public void use()
    {
        glUseProgram( program );
    }

    private void link()
    {
        glLinkProgram( program );
        Shader.printInfoLog( program, shader, GL_LINK_STATUS, GL_LINK_STATUS );
    }

    public void dispatch( int numGroupsX, int numGroupsY, int numGroupsZ )
    {
        glDispatchCompute( numGroupsX, numGroupsY, numGroupsZ );
    }

    private void compile( string source )
    {
        immutable char* sourceCstr = toStringz( source );
        shader = glCreateShader( GL_COMPUTE_SHADER );
        glShaderSource( shader, 1, &sourceCstr, null );

        glCompileShader( shader );
        Shader.printInfoLog( program, shader, GL_COMPILE_STATUS, GL_LINK_STATUS );
        glAttachShader( program, shader );
    }

    /*private void compileSpirV( string path, GLenum shaderType )
    {
        GLuint shader = glCreateShader( shaderType );
        glShaderBinary( 1, &shader, GL_SHADER_BINARY_FORMAT_SPIR_V_ARB, bin, size );
        glSpecializeShaderARB( shader, "main", 0, null, null );
        printInfoLog( shader, GL_COMPILE_STATUS );
        glAttachShader( program, shader );
    }*/

    private GLuint program;
    private GLuint shader;
}

