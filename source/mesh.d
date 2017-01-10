import core.stdc.string;
import derelict.opengl3.gl3;
import matrix4x4;
import renderer;
import std.format;
import std.math;
import std.stdio;
import std.string;
import vec3;

private struct ObjFace
{
    ushort v1, v2, v3;
    ushort t1, t2, t3;
    ushort n1, n2, n3;
}

private class SubMesh
{
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
                    almostEquals( interleavedVertices[ indices[ i ].a ].uv, ttcoord ) &&
                    almostEquals( interleavedVertices[ indices[ i ].a ].normal, tnormal ))
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
                vertex.normal = [ tnormal.x, tnormal.y, tnormal.z ];

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
                    almostEquals( interleavedVertices[ indices[ i ].b ].uv, ttcoord ) &&
                    almostEquals( interleavedVertices[ indices[ i ].b ].normal, tnormal ))
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
                vertex.normal = [ tnormal.x, tnormal.y, tnormal.z ];

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
                    almostEquals( interleavedVertices[ indices[ i ].c ].uv, ttcoord ) &&
                    almostEquals( interleavedVertices[ indices[ i ].c ].normal, tnormal ))
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
                vertex.normal = [ tnormal.x, tnormal.y, tnormal.z ];

                interleavedVertices ~= vertex;
                face.c = cast( ushort )(interleavedVertices.length - 1);
            }

            indices ~= face;
        }
    }

	public Vertex[] interleavedVertices;
    public Face[] indices;
}

public class Mesh
{
    this( string path )
    {
        loadObj( path );
        
        glCreateBuffers( 1, &ubo );
        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( ubo, uboStruct.sizeof, &uboStruct, flags );
    }

    public Face[] getSubMeshIndices( int subMeshIndex )
    {
        return subMeshes[ subMeshIndex ].indices;
    }

    public Vertex[] getSubMeshVertices( int subMeshIndex )
    {
        return subMeshes[ subMeshIndex ].interleavedVertices;
    }

	public int getSubMeshCount() const
	{
		return cast(int)subMeshes.length;
	}

	public void bind( int subMeshIndex )
	{
		glBindVertexArray( vaos[ subMeshIndex ] );
	}

    public void setPosition( Vec3 position )
    {
        this.position = position;
    }

    public void setScale( float scale )
    {
        this.scale = scale;
    }

    public void updateUBO( Matrix4x4 projection, Matrix4x4 view )
    {
        Matrix4x4 mvp;
        mvp.makeIdentity();
        mvp.scale( scale, scale, scale );
        //++testRotation;
        Matrix4x4 rotation;
        rotation.makeRotationXYZ( testRotation, testRotation, testRotation );
        multiply( mvp, rotation, mvp );
        mvp.translate( position );
        multiply( mvp, view, mvp );
        uboStruct.modelToView = mvp;
        multiply( mvp, projection, mvp );
        uboStruct.modelToClip = mvp;

		GLvoid* mappedMem = glMapNamedBuffer( ubo, GL_WRITE_ONLY );
		memcpy( mappedMem, &uboStruct, PerObjectUBO.sizeof );
        glUnmapNamedBuffer( ubo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 0, ubo );
    }

    // Tested only with models exported from Blender. File must contain one mesh only,
    // exported with triangulation, texcoords and normals.
    private void loadObj( string path )
    {
		subMeshes = new SubMesh[ 1 ];
		subMeshes[ 0 ] = new SubMesh();
		vaos = new uint[ subMeshes.length ];

		Vec3[] vertices;
        Vec3[] normals;
        Vec3[] texcoords;
        ObjFace[] faces;

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

		subMeshes[ 0 ].interleave( vertices, normals, texcoords, faces );
        Renderer.generateVAO( subMeshes[ 0 ].interleavedVertices, subMeshes[ 0 ].indices, path, vaos[ 0 ] );
    }

    public uint getElementCount( int subMeshIndex ) const
    {
        return cast( uint )subMeshes[ subMeshIndex ].indices.length;
    }

    private uint[] vaos;
    private uint ubo;
    private PerObjectUBO uboStruct;
    private float testRotation = 0;
	private SubMesh[] subMeshes;
    private Vec3 position;
    private float scale = 1;
}
