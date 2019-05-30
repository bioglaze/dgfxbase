import core.stdc.string;
import derelict.opengl;
import matrix4x4;
import renderer;
import std.file;
import std.format;
import std.math;
import std.regex;
import std.stdio;
import std.string;
import texture;
import vec3;

private struct ObjFace
{
    uint v1, v2, v3;
    uint t1, t2, t3;
    uint n1, n2, n3;
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
            Vec3 tnormal = normals.length > 0 ? normals[ faces[ f ].n1 ] : Vec3( 1, 0, 0 );
            Vec3 ttcoord = texcoords.length > 0 ? texcoords[ faces[ f ].t1 ] : Vec3( 0, 0, 0 );

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
                face.a = cast( uint )(interleavedVertices.length - 1);
            }

            // Vertex 2
            tvertex = vertices[ faces[ f ].v2 ];
            tnormal = normals.length > 0 ? normals[ faces[ f ].n2 ] : Vec3( 1, 0, 0 );
            ttcoord = texcoords.length > 0 ? texcoords[ faces[ f ].t2 ] : Vec3( 0, 0, 0 );

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
                face.b = cast( uint )(interleavedVertices.length - 1);
            }

            // Vertex 3
            tvertex = vertices[ faces[ f ].v3 ];
            tnormal = normals.length > 0 ? normals[ faces[ f ].n3 ] : Vec3( 1, 0, 0 );
            ttcoord = texcoords.length > 0 ? texcoords[ faces[ f ].t3 ] : Vec3( 0, 0, 0 );

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
                face.c = cast( uint )(interleavedVertices.length - 1);
            }

            indices ~= face;
        }
    }

    public Vertex[] interleavedVertices;
    public Face[] indices;
    public ObjFace[] objFaces;
    public string texturePath;
    public string name = "unnamed";
    public int textureIndex;
    private Vec3[] vertices;
    private Vec3[] normals;
    private Vec3[] texcoords;
}

public class Mesh
{
    this( string path, string materialPath )
    {
        loadObj( path );

        if (materialPath != "")
        {
            loadMaterials( materialPath );
        }

        glCreateBuffers( 1, &ubo );
        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( ubo, uboStruct.sizeof, &uboStruct, flags );
    }

    private void loadMaterials( string materialPath )
    {
        auto file = File( materialPath, "r" );

        if (!file.isOpen())
        {
            writeln( "Could not open ", materialPath );
            return;
        }

        bool isReadingMaterials = false;
        bool isReadingMappings = false;

        while (!file.eof())
        {
            string line = strip( file.readln() );

            if (indexOf( line, "materials" ) != -1)
            {
                isReadingMaterials = true;
                isReadingMappings = false;
            }
            else if (indexOf( line, "mappings" ) != -1)
            {
                isReadingMaterials = false;
                isReadingMappings = true;
            }
            else if (isReadingMaterials && line.length > 1)
            {
                string materialName, textureName;
                uint items = formattedRead( line, "%s %s", &materialName, &textureName );
                assert( items == 2, "parse error reading material file" );

                textureFromMaterial[ materialName ] = new Texture( "assets/textures/" ~ textureName );
            }
            else if (isReadingMappings && line.length > 1)
            {
                string subMeshName, materialName;
                uint items = formattedRead( line, "%s %s", &subMeshName, &materialName );
                assert( items == 2, "parse error reading material file" );

                materialFromMeshName[ subMeshName ] = materialName;

                for (int meshIndex = 0; meshIndex < subMeshes.length; ++meshIndex)
                {
                    if (subMeshes[ meshIndex ].name == subMeshName)
                    {
                        subMeshes[ meshIndex ].texturePath = textureFromMaterial[ materialName ].path;
                    }
                }
            }
        }
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

    public Vec3 getPosition() const
    {
        return this.position;
    }

    public float getScale() const
    {
        return this.scale;
    }

    public void setPosition( Vec3 position )
    {
        this.position = position;
    }

    public void setScale( float scale )
    {
        this.scale = scale;
    }

    public string getSubMeshName( int subMeshIndex )
    {
        return subMeshes[ subMeshIndex ].name;
    }

    public void setSubMeshDiffuseMap( int subMeshIndex )
    {

    }

    public void updateUBO( Matrix4x4 projection, Matrix4x4 view, int textureHandle )
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
        uboStruct.textureHandle = textureHandle;

        GLvoid* mappedMem = glMapNamedBuffer( ubo, GL_WRITE_ONLY );
        memcpy( mappedMem, &uboStruct, PerObjectUBO.sizeof );
        glUnmapNamedBuffer( ubo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 0, ubo );
    }

    private void ConvertIndicesFromGlobalToLocal()
    {
        bool hasVNormals = normGlobalLocal.length > 0;
        bool hasTextureCoords = tcoordGlobalLocal.length > 0;

        for (int f = 0; f < subMeshes[ subMeshes.length - 1 ].objFaces.length; ++f)
        {
            subMeshes[ subMeshes.length - 1 ].objFaces[ f ].v1 = vertGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].v1 ];
            subMeshes[ subMeshes.length - 1 ].objFaces[ f ].v2 = vertGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].v2 ];
            subMeshes[ subMeshes.length - 1 ].objFaces[ f ].v3 = vertGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].v3 ];

            if (hasVNormals)
            {
                subMeshes[ subMeshes.length - 1 ].objFaces[ f ].n1 = normGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].n1 ];
                subMeshes[ subMeshes.length - 1 ].objFaces[ f ].n2 = normGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].n2 ];
                subMeshes[ subMeshes.length - 1 ].objFaces[ f ].n3 = normGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].n3 ];
            }

            if (hasTextureCoords)
            {
                subMeshes[ subMeshes.length - 1 ].objFaces[ f ].t1 = tcoordGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].t1 ];
                subMeshes[ subMeshes.length - 1 ].objFaces[ f ].t2 = tcoordGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].t2 ];
                subMeshes[ subMeshes.length - 1 ].objFaces[ f ].t3 = tcoordGlobalLocal[ subMeshes[ subMeshes.length - 1 ].objFaces[ f ].t3 ];
            }
        }
    }

    // Tested only with models exported from Blender. File must be
    // exported with triangulation, texcoords and normals. Does not support smoothing groups.
    private void loadObj( string path )
    {
        subMeshes = new SubMesh[ 1 ];
        subMeshes[ 0 ] = new SubMesh();

		Vec3[] vertices;
        Vec3[] normals;
        Vec3[] texcoords;

        auto file = File( path, "r" );

        if (!file.isOpen())
        {
            writeln( "Could not open ", path );
            return;
        }

        // Reads all vertices, normals and texture coordinates to a vector.
        while (!file.eof())
        {
            string line = strip( file.readln() );

            if (line.length > 1 && line[ 0 ] == 'v' && line[ 1 ] != 'n' && line[1] != 't')
            {
                Vec3 vertex;
                string v;
                uint items = formattedRead( line, "%s %f %f %f", &v, &vertex.x, &vertex.y, &vertex.z );
                assert( items == 4, "parse error reading .obj file" );
             
                //vertex = vertex * Vec3( 0.05f, 0.05f, 0.05f );

                vertices ~= vertex;
            }
            else if (line.length > 0 && line[ 0 ] == '#')
            {
                continue;
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

        if (normals.length == 0)
        {
            writeln( "Warning: file didn't contain normals." );
        }

        while (!file.eof())
        {
            string line = strip( file.readln() );

            if (line.length > 1 && (line[ 0 ] == 'o' || line[ 0 ] == 'g'))
            {
                ConvertIndicesFromGlobalToLocal();
                
                if (subMeshes[ subMeshes.length - 1 ].name != "unnamed")
                {
                    // Some exporters use 'g' without specifying geometry for it, so remove them.
                    if (subMeshes[ subMeshes.length - 1 ].objFaces.empty())
                    {
                        writeln("TODO: Erase empty submesh");
                        //gMeshes.erase( std::begin( gMeshes ) + gMeshes.size() - 1 );
                    }

                    subMeshes ~= new SubMesh();
                    //hasTextureCoords = false;
                }

                string o, name;
                uint items = formattedRead( line, "%s %s", &o, &name );
                subMeshes[ subMeshes.length - 1 ].name = name;
                vertGlobalLocal.clear();
                normGlobalLocal.clear();
                tcoordGlobalLocal.clear();
            }
            else if (line.length > 0 && line[ 0 ] == 'f')
            {
                ObjFace face;
                string v;
                uint items = 0;
                bool hasNormalsAndTexCoords = false;
                auto ctr = ctRegex!(`.[0-9]+ [0-9]+ [0-9]+`);
                auto c2 = matchFirst( line, ctr ); 
                if (!c2.empty)
                {
                    items = formattedRead( line, "%s %d %d %d", &v, &face.v1, &face.v2, &face.v3 );
                    assert( items == 4, "parse error reading .obj file" );
                }
                else if (!line.empty)
                {
                    items = formattedRead( line, "%s %d/%d/%d %d/%d/%d %d/%d/%d", &v, &face.v1, &face.t1, &face.n1,
                                            &face.v2, &face.t2, &face.n2,
                                            &face.v3, &face.t3, &face.n3 );
                    assert( items == 10, "parse error reading .obj file" );
                    hasNormalsAndTexCoords = true;
                }

                // Didn't find the index in index conversion map, so add it.
                if (!((face.v1 - 1) in vertGlobalLocal))
                {
                    subMeshes[ subMeshes.length - 1 ].vertices ~= vertices[ face.v1 - 1 ];
                    vertGlobalLocal[ face.v1 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].vertices.length - 1;
                }
                if (!((face.v2 - 1) in vertGlobalLocal))
                {
                    subMeshes[ subMeshes.length - 1 ].vertices ~= vertices[ face.v2 - 1 ];
                    vertGlobalLocal[ face.v2 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].vertices.length - 1;
                }
                if (!((face.v3 - 1) in vertGlobalLocal))
                {
                    subMeshes[ subMeshes.length - 1 ].vertices ~= vertices[ face.v3 - 1 ];
                    vertGlobalLocal[ face.v3 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].vertices.length - 1;
                }

                if (!((face.t1 - 1) in tcoordGlobalLocal) && hasNormalsAndTexCoords)
                {
                    subMeshes[ subMeshes.length - 1 ].texcoords ~= texcoords[ face.t1 - 1 ];
                    tcoordGlobalLocal[ face.t1 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].texcoords.length - 1;
                }
                if (!((face.t2 - 1) in tcoordGlobalLocal) && hasNormalsAndTexCoords)
                {
                    subMeshes[ subMeshes.length - 1 ].texcoords ~= texcoords[ face.t2 - 1 ];
                    tcoordGlobalLocal[ face.t2 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].texcoords.length - 1;
                }
                if (!((face.t3 - 1) in tcoordGlobalLocal) && hasNormalsAndTexCoords)
                {
                    subMeshes[ subMeshes.length - 1 ].texcoords ~= texcoords[ face.t3 - 1 ];
                    tcoordGlobalLocal[ face.t3 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].texcoords.length - 1;
                }

                if (!((face.n1 - 1) in normGlobalLocal) && hasNormalsAndTexCoords)
                {
                    subMeshes[ subMeshes.length - 1 ].normals ~= normals[ face.n1 - 1 ];
                    normGlobalLocal[ face.n1 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].normals.length - 1;
                }
                if (!((face.n2 - 1) in normGlobalLocal) && hasNormalsAndTexCoords)
                {
                    subMeshes[ subMeshes.length - 1 ].normals ~= normals[ face.n2 - 1 ];
                    normGlobalLocal[ face.n2 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].normals.length - 1;
                }
                if (!((face.n3 - 1) in normGlobalLocal) && hasNormalsAndTexCoords)
                {
                    subMeshes[ subMeshes.length - 1 ].normals ~= normals[ face.n3 - 1 ];
                    normGlobalLocal[ face.n3 - 1 ] = cast(uint)subMeshes[ subMeshes.length - 1 ].normals.length - 1;
                }

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

                subMeshes[ subMeshes.length - 1 ].objFaces ~= face;
            }
        }

        vaos = new uint[ subMeshes.length ];
        writeln("submeshes in ", path, ": ", subMeshes.length);

        ConvertIndicesFromGlobalToLocal();

        for (int subMeshIndex = 0; subMeshIndex < subMeshes.length; ++subMeshIndex)
        {
            subMeshes[ subMeshIndex ].interleave( subMeshes[ subMeshIndex ].vertices, subMeshes[ subMeshIndex ].normals, subMeshes[ subMeshIndex ].texcoords, subMeshes[ subMeshIndex ].objFaces );
            Renderer.generateVAO( subMeshes[ subMeshIndex ].interleavedVertices, subMeshes[ subMeshIndex ].indices, path, vaos[ subMeshIndex ] );
        }
    }

    public uint getElementCount( int subMeshIndex ) const
    {
        return cast( uint )subMeshes[ subMeshIndex ].indices.length;
    }

    // Indices are stored in the .obj file relating to the whole object, not
    // to a mesh, so we need to convert indices so that they point to submeshes'
    // indices. 
    private uint[ uint ] vertGlobalLocal; // (global index, local index)
    private uint[ uint ] normGlobalLocal;
    private uint[ uint ] tcoordGlobalLocal;

    public Texture[ string ] textureFromMaterial;
    public SubMesh[] subMeshes;
    private string[ string ] materialFromMeshName;
    private uint[] vaos;
    private uint ubo;
    private PerObjectUBO uboStruct;
    private float testRotation = 0;
    private Vec3 position = Vec3( 0, 0, 0 );
    private float scale = 1;
}
