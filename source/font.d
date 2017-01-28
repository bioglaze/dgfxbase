module Font;

import std.stdio;
import renderer;

class Font
{
    this( string bmFontBinaryMetadataPath )
    {
        auto f = File( bmFontBinaryMetadataPath, "r" );

        if (!f.isOpen())
        {
            writeln( "Could not open font ", bmFontBinaryMetadataPath );
            return;
        }

        byte[ 4 ] header;
        f.rawRead( header );
        const bool validHeaderHead = header[ 0 ] == 66 && header[ 1 ] == 77 && header[ 2 ] == 70;

        if (!validHeaderHead)
        {
            writeln( "Font loaded from path ", bmFontBinaryMetadataPath, " doesn't contain a valid BMFont binary format header" );
            return;
        }

        const bool validHeaderTail = header[ 3 ] == 3;

        if (!validHeaderTail)
        {
            writeln( "Font loaded from path ", bmFontBinaryMetadataPath, " has wrong BMFont binary format version. Valid is 3." );
            return;
        }

        while (!f.eof)
        {
            ubyte[ 1 ] blockId;
            f.rawRead( blockId );

            uint[ 1 ] blockSize;
            f.rawRead( blockSize );

            ubyte[] blockData = new ubyte[ blockSize[ 0 ] ];

            if (blockId[ 0 ] == 1) // info
            {
                f.rawRead( blockData );

                padding[ 0 ] = blockData[  7 ];
                padding[ 1 ] = blockData[  8 ];
                padding[ 2 ] = blockData[  9 ];
                padding[ 3 ] = blockData[ 10 ];
                
                spacing[ 0 ] = blockData[ 11 ];
                spacing[ 1 ] = blockData[ 12 ];
            }
            else if (blockId[ 0 ] == 2) // common
            {
                CommonBlock block;
                f.rawRead((&block)[0..1]);
                lineHeight = block.lineHeight;
                base = block.base;
            }
            else if (blockId[ 0 ] == 3) // pages
            {
                f.rawRead( blockData );
            }
            else if (blockId[ 0 ] == 4) // chars
            {
                CharacterBlock[] blocks = new CharacterBlock[ blockSize[ 0 ] / CharacterBlock.sizeof ];
                f.rawRead( blocks );

                for (int c = 0; c < blocks.length; ++c)
                {
                    chars[ blocks[ c ].id ].x = blocks[ c ].x;
                    chars[ blocks[ c ].id ].y = blocks[ c ].y;
                    chars[ blocks[ c ].id ].width = blocks[ c ].width;
                    chars[ blocks[ c ].id ].height = blocks[ c ].height;
                    chars[ blocks[ c ].id ].xOffset = blocks[ c ].xOffset;
                    chars[ blocks[ c ].id ].yOffset = blocks[ c ].yOffset;
                    chars[ blocks[ c ].id ].xAdvance = blocks[ c ].xAdvance;
                }
            }
            else if (blockId[ 0 ] == 5) // kerning
            {
                f.rawRead( blockData );
            }            
        }
    }

    public void getGeometry( string text, float texWidth, float texHeight, out Vertex[] vertices, out Face[] faces )
    {
        vertices = new Vertex[ text.length * 6 ];
        faces = new Face[ text.length * 2 ];
        
        float accumX = 0;
        float y = 0;
        
        for (int c = 0; c < text.length; ++c)
        {
            Character* ch = &chars[ cast( int )text[ c ] ];

            if (text[ c ] == '\n')
            {
                Character* charA = &chars[ cast(int)( 'a' )];
                accumX = 0;
                y += charA.height + charA.yOffset;
            }
            else
            {
                accumX += ch.xAdvance;
            }
            
            const float scale = 1;
            const float x = 0;
            const float z = -0.6f;
            
            const float offx = x + ch.xOffset * scale + accumX * scale;
            const float offy = y + ch.yOffset * scale;
            
            const float u0 = ch.x / texWidth;
            const float u1 = (ch.x + ch.width) / texWidth;
            
            const float v0 = (ch.y + ch.height) / texHeight;
            const float v1 = (ch.y) / texHeight;
            
            // Upper triangle.
            faces[ c * 2 + 0 ].c = cast(ushort)(c * 6 + 0);
            faces[ c * 2 + 0 ].b = cast(ushort)(c * 6 + 1);
            faces[ c * 2 + 0 ].a = cast(ushort)(c * 6 + 2);
            
            vertices[ c * 6 + 0 ] = Vertex( [offx, offy, z], [u0, v1] );
            vertices[ c * 6 + 1 ] = Vertex( [offx + ch.width * scale, offy, z], [u1, v1] );
            vertices[ c * 6 + 2 ] = Vertex( [offx, offy + ch.height * scale, z], [u0, v0] );
            
            // Lower triangle.
            faces[ c * 2 + 1 ].c = cast(ushort)(c * 6 + 3);
            faces[ c * 2 + 1 ].b = cast(ushort)(c * 6 + 4);
            faces[ c * 2 + 1 ].a = cast(ushort)(c * 6 + 5);
            
            vertices[ c * 6 + 3 ] = Vertex( [offx + ch.width * scale, offy, z], [u1, v1] );
            vertices[ c * 6 + 4 ] = Vertex( [offx + ch.width * scale, offy + ch.height * scale, z], [u1, v0] );
            vertices[ c * 6 + 5 ] = Vertex( [offx, offy + ch.height * scale, z], [u0, v0] );
        }
    }

    private align(1) struct CharacterBlock
    {
        uint id;
        ushort x;
        ushort y;
        ushort width;
        ushort height;
        short xOffset;
        short yOffset;
        short xAdvance;
        ubyte page;
        ubyte channel;
    }
    
    private align(1) struct CommonBlock
    {
        ushort lineHeight;
        ushort base;
        ushort scaleW;
        ushort scaleH;
        ushort pages;
        ubyte  bitField;
        ubyte  alpha;
        ubyte  red;
        ubyte  green;
        ubyte  blue;
    }
 
    private struct Character
    {
        float x = 0, y = 0;
        float width = 0, height = 0;
        float xOffset = 0, yOffset = 0;
        float xAdvance = 0;
    }
    
    private int[ 2 ] spacing;
    private int[ 4 ] padding;
    private int lineHeight = 32;
    private int base = 32;
    private Character[ 256 ] chars;
}

