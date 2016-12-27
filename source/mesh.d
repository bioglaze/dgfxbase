import std.format;
import std.string;
import std.stdio;
import std.math;
import derelict.opengl3.gl3;
import vec3;
import renderer;
import matrix4x4;

private struct ObjFace
{
    ushort v1, v2, v3;
    ushort t1, t2, t3;
    ushort n1, n2, n3;
}

public struct PerObjectUBO
{
    Matrix4x4 mvp;
}

public class Mesh
{
    this( string path )
    {
        Vec3[] vertices;
        Vec3[] normals;
        Vec3[] texcoords;
        ObjFace[] faces;

        loadObj( path, vertices, normals, texcoords, faces );
        interleave( vertices, normals, texcoords, faces );
        Renderer.generateVAO( interleavedVertices, indices, path, vao );
    }

    public void updateUBO()
    {
		GLvoid* p = glMapNamedBuffer( ubo, GL_WRITE_ONLY );
		//memcpy( p, &ubo, PerObjectUBO.sizeof );
        glUnmapBuffer( GL_UNIFORM_BUFFER );
    }

    // Tested only with models exported from Blender. File must contain one mesh only,
    // exported with triangulation, texcoords and normals.
    private void loadObj( string path, ref Vec3[] vertices, ref Vec3[] normals, ref Vec3[] texcoords, ref ObjFace[] faces )
    {
        auto file = File( path, "r" );

        if (!file.isOpen())
        {
            writeln( "Could not open ", path );
            return;
        }

        while (!file.eof())
        {
            string line = strip( file.readln() );

            if (line.length > 1 && line[ 0 ] == 'v' && line[ 1 ] != 'n' && line[1] != 't')
            {
                Vec3 vertex;
                string v;
                uint items = formattedRead( line, "%s %f %f %f", &v, &vertex.x, &vertex.y, &vertex.z );
                assert( items == 4, "parse error reading .obj file" );
                vertices ~= vertex;
            }
            else if (line.length > 0 && line[ 0..2 ] == "vn")
            {
                Vec3 normal;
                string v;
                uint items = formattedRead( line, "%s %f %f %f", &v, &normal.x, &normal.y, &normal.z );
                assert( items == 4, "parse error reading .obj file" );
                normals ~= normal;
            }
            else if (line.length > 0 && line[ 0..2 ] == "vt")
            {
                Vec3 texcoord;
                string v;
                uint items = formattedRead( line, "%s %f %f", &v, &texcoord.x, &texcoord.y );
                assert( items == 3, "parse error reading .obj file" );
                texcoords ~= texcoord;
            }
        }

        file.seek( 0 );

        while (!file.eof())
        {
            string line = strip( file.readln() );

            if (line.length > 0 && line[ 0 ] == 'f')
            {
                ObjFace face;
                string v;
                uint items = formattedRead( line, "%s %d/%d/%d %d/%d/%d %d/%d/%d", &v, &face.v1, &face.t1, &face.n1,
                                            &face.v2, &face.t2, &face.n2,
                                            &face.v3, &face.t3, &face.n3 );
                assert( items == 10, "parse error reading .obj file" );

                // OBJ faces are 1-indexed, convert to 0-indexed.
                --face.v1;
                --face.v2;
                --face.v3;

                --face.n1;
                --face.n2;
                --face.n3;

                --face.t1;
                --face.t2;
                --face.t3;

                faces ~= face;
            }
        }
    }

    private bool almostEquals( float[ 3 ] v1, Vec3 v2 ) const
    {
        if (abs( v1[ 0 ] - v2.x ) > 0.0001f) { return false; }
        if (abs( v1[ 1 ] - v2.y ) > 0.0001f) { return false; }
        if (abs( v1[ 2 ] - v2.z ) > 0.0001f) { return false; }
        return true;
    }

    private bool almostEquals( float[ 2 ] v1, Vec3 v2 ) const
    {
        if (abs( v1[ 0 ] - v2.x ) > 0.0001f) { return false; }
        if (abs( v1[ 1 ] - v2.y ) > 0.0001f) { return false; }
        return true;
    }

    private void interleave( ref Vec3[] vertices, ref Vec3[] normals, ref Vec3[] texcoords, ObjFace[] faces )
    {
        Face face;

        for (int f = 0; f < faces.length; ++f)
        {
            Vec3 tvertex = vertices[ faces[ f ].v1 ];
            Vec3 tnormal = normals[ faces[ f ].n1 ];
            Vec3 ttcoord = texcoords[ faces[ f ].t1 ];

            // Searches vertex from vertex list and adds it if not found.

            // Vertex 1
            bool found = false;

            for (int i = 0; i < indices.length; ++i)
            {
                if (almostEquals( interleavedVertices[ indices[ i ].a ].pos, tvertex ) &&
                    almostEquals( interleavedVertices[ indices[ i ].a ].uv, ttcoord ))
                {
                    found = true;
                    face.a = indices[ i ].a;
                    break;
                }
            }

            if (!found)
            {
                Vertex vertex;
                vertex.pos = [ tvertex.x, tvertex.y, tvertex.z ];
                vertex.uv = [ ttcoord.x, ttcoord.y ];

                interleavedVertices ~= vertex;
                face.a = cast( ushort )(interleavedVertices.length - 1);
            }

            // Vertex 2
            tvertex = vertices[ faces[ f ].v2 ];
            tnormal = normals[ faces[ f ].n2 ];
            ttcoord = texcoords[ faces[ f ].t2 ];

            found = false;

            for (int i = 0; i < indices.length; ++i)
            {
                if (almostEquals( interleavedVertices[ indices[ i ].b ].pos, tvertex ) &&
                    almostEquals( interleavedVertices[ indices[ i ].b ].uv, ttcoord ))
                {
                    found = true;
                    face.b = indices[ i ].b;
                    break;
                }
            }

            if (!found)
            {
                Vertex vertex;
                vertex.pos = [ tvertex.x, tvertex.y, tvertex.z ];
                vertex.uv = [ ttcoord.x, ttcoord.y ];

                interleavedVertices ~= vertex;
                face.b = cast( ushort )(interleavedVertices.length - 1);
            }

            // Vertex 3
            tvertex = vertices[ faces[ f ].v3 ];
            tnormal = normals[ faces[ f ].n3 ];
            ttcoord = texcoords[ faces[ f ].t3 ];

            found = false;

            for (int i = 0; i < indices.length; ++i)
            {
                if (almostEquals( interleavedVertices[ indices[ i ].c ].pos, tvertex ) &&
                    almostEquals( interleavedVertices[ indices[ i ].c ].uv, ttcoord ))
                {
                    found = true;
                    face.c = indices[ i ].c;
                    break;
                }
            }

            if (!found)
            {
                Vertex vertex;
                vertex.pos = [ tvertex.x, tvertex.y, tvertex.z ];
                vertex.uv = [ ttcoord.x, ttcoord.y ];

                interleavedVertices ~= vertex;
                face.c = cast( ushort )(interleavedVertices.length - 1);
            }

            indices ~= face;
        }
    }

    public uint getElementCount() const
    {
        return cast( uint )indices.length;
    }

    private Vertex[] interleavedVertices;
    private Face[] indices;

    private uint vao;
    private uint ubo;
}
