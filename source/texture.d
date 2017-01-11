import derelict.opengl3.gl3;
import renderer;
import std.exception;
import std.stdio;
import std.string;

extern(System) @nogc nothrow
{
    alias da_glGetTextureHandleARB = GLuint function( GLuint );
    alias da_glMakeTextureHandleResidentARB = void function( GLuint64 );
}

__gshared
{
    da_glGetTextureHandleARB glGetTextureHandleARB;
    da_glMakeTextureHandleResidentARB glMakeTextureHandleResidentARB;
}

import derelict.opengl3.wgl;
import derelict.opengl3.internal;

void* loadGLFunc( string symName )
{
    version( Windows )
    {
        return cast( void* )wglGetProcAddress( symName.toStringz() );
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

// Reads a true-color, uncompressed TGA
private void readTGA( string path, out int width, out int height, out byte[] pixelData )
{
    try
    {
        auto f = File( path, "r" );
            
        byte[ 1 ] idLength;
        f.rawRead( idLength );

        byte[ 1 ] colorMapType;
        f.rawRead( colorMapType );

        byte[ 1 ] imageType;
        f.rawRead( imageType );

        if (imageType[ 0 ] != 2)
        {
            throw new Exception( "wrong TGA type: must be uncompressed true-color" );
        }

        byte[ 5 ] colorSpec;
        f.rawRead( colorSpec );

        byte[ 4 ] specBegin;
        short[ 2 ] specDim;
        f.rawRead( specBegin );
        f.rawRead( specDim );
        width = specDim[ 0 ];
        height = specDim[ 1 ];

        byte[ 2 ] specEnd;
        f.rawRead( specEnd );

        if (idLength[ 0 ] > 0)
        {
            byte[] imageId = new byte[ idLength[ 0 ] ];
            f.rawRead( imageId );
        }

        pixelData = new byte[ width * height * 4 ];
        f.rawRead( pixelData );
    }
    catch (Exception e)
    {
        writeln( "could not open ", path, ":", e );
    } 
}

public class Texture
{
    public static void loadExtensionFunctions()
    {
        bindGLFunc( cast(void**)&glGetTextureHandleARB, "glGetTextureHandleARB" );
        bindGLFunc( cast(void**)&glMakeTextureHandleResidentARB, "glMakeTextureHandleResidentARB" );
    }

    this( string path )
    {
        byte[] pixelData;
        readTGA( path, width, height, pixelData );
        
        glCreateTextures( GL_TEXTURE_2D, 1, &handle );
        glBindTextureUnit( 0, handle );

		glTextureStorage2D( handle, 1, GL_RGBA8, width, height );
        glTextureSubImage2D( handle, 0, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_BYTE, pixelData.ptr );

        glTextureParameteri( handle, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTextureParameteri( handle, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTextureParameteri( handle, GL_TEXTURE_WRAP_S, GL_REPEAT );
        glTextureParameteri( handle, GL_TEXTURE_WRAP_T, GL_REPEAT );
        glTextureParameteri( handle, GL_TEXTURE_WRAP_R, GL_REPEAT );

        handle64 = glGetTextureHandleARB( handle );
    }

    public GLuint64 getHandle64() const
    {
        return handle64;
    }

    public void makeResident()
    {
        glMakeTextureHandleResidentARB( handle64 );
    }

    public void bind( int unit )
    {
        glBindTextureUnit( unit, handle );
    }

    public int getWidth()
    {
        return width;
    }

    public int getHeight()
    {
        return height;
    }

    private int width, height;
    private GLuint handle;
    private GLuint64 handle64;
}
