import derelict.opengl3.gl3;
import std.exception;
import std.file;
import std.stdio;
import std.string;

class Shader
{
    this( string vertexPath, string fragmentPath )
    {
        try
        {
            program = glCreateProgram();
            compile( cast(string)read( vertexPath ), GL_VERTEX_SHADER );
            compile( cast(string)read( fragmentPath ), GL_FRAGMENT_SHADER );
            link();
        }
        catch (Exception e)
        {
            writeln( "Could not open or compile " ~ vertexPath ~ " or " ~ fragmentPath );
        }
    }

    public void setFloat( string name, float value )
    {
        immutable char* nameCstr = toStringz( name );
        auto loc = glGetUniformLocation( program, nameCstr );

        if (loc != -1)
        {
            glProgramUniform1f( program, loc, value );
        }
    }

    public void setInt( string name, int value )
    {
        immutable char* nameCstr = toStringz( name );
        auto loc = glGetUniformLocation( program, nameCstr );

        if (loc != -1)
        {
            glProgramUniform1i( program, loc, value );
        }
    }
    
    public void setFloat2( string name, float value1, float value2 )
    {
        immutable char* nameCstr = toStringz( name );
        auto loc = glGetUniformLocation( program, nameCstr );

        if (loc != -1)
        {
            glProgramUniform2f( program, loc, value1, value2 );
        }
    }

    public void setFloat3( string name, float value1, float value2, float value3 )
    {
        immutable char* nameCstr = toStringz( name );
        auto loc = glGetUniformLocation( program, nameCstr );

        if (loc != -1)
        {
            glProgramUniform3f( program, loc, value1, value2, value3 );
        }
    }

    public void setFloat4( string name, float value1, float value2, float value3, float value4 )
    {
        immutable char* nameCstr = toStringz( name );
        auto loc = glGetUniformLocation( program, nameCstr );
        if (loc != -1)
        {
            glProgramUniform4f( program, loc, value1, value2, value3, value4 );
        }
    }

    public void setMatrix44( string name, float[] matrix )
    {
        immutable char* nameCstr = toStringz( name );
        auto loc = glGetUniformLocation( program, nameCstr );

        if (loc != -1)
        {
            glProgramUniformMatrix4fv( program, loc, 1, GL_FALSE, matrix.ptr );
        }
    }

    public void use()
    {
        glUseProgram( program );
    }

    private void link()
    {
        glLinkProgram( program );
        printInfoLog( program, GL_LINK_STATUS, GL_LINK_STATUS );
    }

    private void printInfoLog( GLuint shader, GLenum status, GLenum getProgramParam )
    {
        assert( status == GL_LINK_STATUS || status == GL_COMPILE_STATUS, "Wrong status!" );

        GLint shaderCompiled = GL_FALSE;

        if (status == GL_COMPILE_STATUS)
        {
            glGetShaderiv( shader, GL_COMPILE_STATUS, &shaderCompiled );
        }
        else
        {
            glGetProgramiv( shader, getProgramParam, &shaderCompiled );
        }

        if (shaderCompiled != GL_TRUE)
        {
            writeln("Shader could not be " ~ (status == GL_LINK_STATUS ? "linked!" : "compiled!"));

            char[1000] errorLog;
            auto info = errorLog.ptr;

            if (status == GL_COMPILE_STATUS)
            {
                glGetShaderInfoLog( shader, GL_INFO_LOG_LENGTH, null, info );
            }
            else
            {
                glGetProgramInfoLog( program, GL_INFO_LOG_LENGTH, null, info );
            }

            writeln( errorLog );
        }
    }

    private void compile( string source, GLenum shaderType )
    {
        assert( shaderType == GL_VERTEX_SHADER || shaderType == GL_FRAGMENT_SHADER, "Wrong shader type!" );

        immutable char* sourceCstr = toStringz( source );
        GLuint shader = glCreateShader( shaderType );
        glShaderSource( shader, 1, &sourceCstr, null );

        glCompileShader( shader );
        printInfoLog( shader, GL_COMPILE_STATUS, GL_LINK_STATUS );
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

    public void validate()
    {
        glValidateProgram( program );
        printInfoLog( program, GL_LINK_STATUS, GL_VALIDATE_STATUS );
    }

    private GLuint program;
}

