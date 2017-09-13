import derelict.opengl3.gl3;
import derelict.opengl3.wgl;
import derelict.opengl3.glx;
import derelict.opengl3.internal;
import std.exception;
import std.file;
import std.stdio;
import std.string;

extern(System) @nogc nothrow
{
    alias da_glSpecializeShader = void function( GLuint, const(char)*, GLuint, const(uint)*, const(uint)* );
}

__gshared
{
    da_glSpecializeShader glSpecializeShader;
}

void* loadGLFunc( string symName )
{
    version( Windows )
    {
        return cast( void* )wglGetProcAddress( symName.toStringz() );
    }
    version( linux )
    {
        return cast( void* )glXGetProcAddress( symName.toStringz() );
    }
}

void bindGLFunc( void** ptr, string symName )
{
    import derelict.util.exception : SymbolLoadException;

    auto sym = loadGLFunc( symName );
    if( !sym )
        throw new SymbolLoadException( "Failed to load OpenGL symbol [" ~ symName ~ "]" );
    *ptr = sym;
}

public class Shader
{
    public static void loadExtensionFunctions()
    {
        bindGLFunc( cast(void**)&glSpecializeShader, "glSpecializeShaderARB" );
    }

    this( string vertexPath, string fragmentPath )
    {
        try
        {
            program = glCreateProgram();
            glObjectLabel( GL_PROGRAM, program, -1, toStringz( vertexPath ) );

			if (indexOf( vertexPath, ".spv" ) != -1)
			{
				compileSpirV( vertexPath, fragmentPath );
			}
			else
			{
				compile( cast(string)read( vertexPath ), GL_VERTEX_SHADER );
				compile( cast(string)read( fragmentPath ), GL_FRAGMENT_SHADER );
			}

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
        printInfoLog( program, program, GL_LINK_STATUS, GL_LINK_STATUS );
    }

    public static void printInfoLog( GLuint program, GLuint shader, GLenum status, GLenum getProgramParam )
    {
        assert( status == GL_LINK_STATUS || status == GL_COMPILE_STATUS, "Wrong status!" );

        GLint shaderCompiled = GL_FALSE;

        if (status == GL_COMPILE_STATUS)
        {
            glGetShaderiv( shader, GL_COMPILE_STATUS, &shaderCompiled );
        }
        else
        {
            glGetProgramiv( program, getProgramParam, &shaderCompiled );
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
        printInfoLog( program, shader, GL_COMPILE_STATUS, GL_LINK_STATUS );
        glAttachShader( program, shader );
    }

    private void compileSpirV( string vertexPath, string fragmentPath )
    {
        if (!exists( vertexPath ) || !exists( fragmentPath ))
        {
            writeln( "could not open ", vertexPath, " or ", fragmentPath );
            return;
        }

        auto vertexData = cast(byte[]) read( vertexPath );
        GLuint vertexShader = glCreateShader( GL_VERTEX_SHADER );
        GLenum GL_SHADER_BINARY_FORMAT_SPIR_V_ARB = 0x9551;
        glShaderBinary( 1, &vertexShader, GL_SHADER_BINARY_FORMAT_SPIR_V_ARB, cast(const void*)vertexData, cast(int)(vertexData.length) );
        glSpecializeShader( vertexShader, "main", 0, null, null );
        printInfoLog( program, vertexShader, GL_COMPILE_STATUS, GL_LINK_STATUS );
        glAttachShader( program, vertexShader );

        auto fragmentData = cast(byte[]) read( fragmentPath );
        GLuint fragmentShader = glCreateShader( GL_FRAGMENT_SHADER );
        glShaderBinary( 1, &fragmentShader, GL_SHADER_BINARY_FORMAT_SPIR_V_ARB, cast(const void*)fragmentData, cast(int)(fragmentData.length) );
        glSpecializeShader( fragmentShader, "main", 0, null, null );
        printInfoLog( program, fragmentShader, GL_COMPILE_STATUS, GL_LINK_STATUS );
        glAttachShader( program, fragmentShader );
    }

    public void validate()
    {
        glValidateProgram( program );
        printInfoLog( program, program, GL_LINK_STATUS, GL_VALIDATE_STATUS );
    }

    private GLuint program;
}

