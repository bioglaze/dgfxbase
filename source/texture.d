import core.stdc.string;
import derelict.opengl3.gl3;
import derelict.opengl3.wgl;
import derelict.opengl3.glx;
import derelict.opengl3.internal;
import renderer;
import std.exception;
import std.stdio;
import std.string;

private immutable bool useBindless = false;

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

private void readTGA( string path, out int width, out int height, out int bits, out byte[] pixelData )
{
    try
    {
        auto f = File( path, "r" );
            
        byte[ 1 ] idLength;
        f.rawRead( idLength );

        byte[ 1 ] colorMapType;
        f.rawRead( colorMapType );

        if (colorMapType[ 0 ] != 0)
        {
            throw new Exception( "wrong TGA type: must not have color map" );
        }

        byte[ 1 ] imageType;
        f.rawRead( imageType );

        if (imageType[ 0 ] != 2 && imageType[ 0 ] != 10)
        {
            throw new Exception( "Wrong TGA type: Must not be color-mapped" );
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

        bits = specEnd[ 0 ];
        writeln( path, " has ", bits, " bits, width ", width, ", height ", height );

        if (idLength[ 0 ] > 0)
        {
            byte[] imageId = new byte[ idLength[ 0 ] ];
            f.rawRead( imageId );
        }

        pixelData = new byte[ width * height * (bits == 24 ? 3 : 4) ];

        if (imageType[ 0 ] == 2)
        {
            f.rawRead( pixelData );
            return;
        }

        // RLE

        int size = width * height;
        int loaded = 0;
        void* pos = &pixelData[ 0 ];

        while ((loaded < size) && !f.eof)
        {
            enum RLE_BIT = 1 << 7;

            ubyte[ 1 ] packetBit;
            f.rawRead( packetBit );

            immutable ubyte count = (packetBit[ 0 ] & ~RLE_BIT) + 1;

            if (packetBit[ 0 ] & RLE_BIT)
            {
                // RLE packet

                ubyte[] tmp = new ubyte[ bits / 8 ];
                f.rawRead( tmp );

                for (int i = 0; i < count; ++i)
                {
                    ++loaded;

                    if (loaded > size)
                    {
                        writeln( "loaded: ", loaded, ", size: ", size );
                        assert( false, "TGA file reader error reading an RLE-encoded file: loaded more than its size in an RLE packet" );
                    }

                    memcpy( pos, tmp.ptr, bits / 8 );
                    pos += bits / 8;
                }
            }
            else
            {
                // RAW packet

                if (loaded + count > size)
                {
                    assert( false, "TGA file reader error reading an RLE-encoded file: loaded more than its size in a non-RLE packet" );
                }

                loaded += count;
                ubyte[] tmp = new ubyte[ (bits / 8) * count ];
                f.rawRead( tmp );
                memcpy( pos, tmp.ptr, (bits / 8) * count );
                pos += (bits / 8) * count;
            }
        }

        for (int i = 0; i < width * height; i += 3)
        {
            pixelData[ i * 3 + 0 ] = cast(byte)127;
            pixelData[ i * 3 + 1 ] = cast(byte)0;
            pixelData[ i * 3 + 2 ] = cast(byte)127;
        }
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

    this( string path2 )
    {
        this.path = path2;

        byte[] pixelData;
        int bits;
        readTGA( path2, width, height, bits, pixelData );

        glCreateTextures( GL_TEXTURE_2D, 1, &handle );
        glBindTextureUnit( 0, handle );

        glPixelStorei( GL_UNPACK_ALIGNMENT, bits == 32 ? 4 : 1 );

        glTextureStorage2D( handle, 1, GL_SRGB8_ALPHA8, width, height );
        glTextureSubImage2D( handle, 0, 0, 0, width, height, bits == 32 ? GL_BGRA : GL_BGR, GL_UNSIGNED_BYTE, pixelData.ptr );

        glTextureParameteri( handle, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTextureParameteri( handle, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR );
        glTextureParameteri( handle, GL_TEXTURE_WRAP_S, GL_REPEAT );
        glTextureParameteri( handle, GL_TEXTURE_WRAP_T, GL_REPEAT );
        glTextureParameteri( handle, GL_TEXTURE_WRAP_R, GL_REPEAT );

        glGenerateTextureMipmap( handle );

        if (useBindless)
        {
            handle64 = glGetTextureHandleARB( handle );
        }
        
        glObjectLabel( GL_TEXTURE, handle, -1, toStringz( path2 ) );
    }

    public GLuint64 getHandle64() const
    {
        return handle64;
    }

    public void makeResident()
    {
        if (useBindless)
        {
            glMakeTextureHandleResidentARB( handle64 );
        }
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
    public string path;
}
