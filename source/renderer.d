import core.stdc.string;
import bindbc.opengl;
import Font;
import matrix4x4;
import mesh;
import shader;
import std.stdio;
import std.string;
import texture;
import vec3;
import dirlight;

public align(1) struct Vertex
{
    float[ 3 ] pos;
    float[ 2 ] uv;
    float[ 3 ] normal;
}

public align(1) struct Face
{
    uint a, b, c;
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
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SOURCE_API:             sourceFmt = "API"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SOURCE_WINDOW_SYSTEM:   sourceFmt = "WINDOW_SYSTEM"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SOURCE_SHADER_COMPILER: sourceFmt = "SHADER_COMPILER"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SOURCE_THIRD_PARTY:     sourceFmt = "THIRD_PARTY"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SOURCE_APPLICATION:     sourceFmt = "APPLICATION"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SOURCE_OTHER:           sourceFmt = "OTHER"; break;
            default: break;
        }

        string typeFmt = "UNDEFINED(0x%04X)";

        switch (type)
        {
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_TYPE_ERROR:               typeFmt = "ERROR"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: typeFmt = "DEPRECATED_BEHAVIOR"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:  typeFmt = "UNDEFINED_BEHAVIOR"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_TYPE_PORTABILITY:         typeFmt = "PORTABILITY"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_TYPE_PERFORMANCE:         typeFmt = "PERFORMANCE"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_TYPE_OTHER:               typeFmt = "OTHER"; break;
            default: break;
        }

        string severityFmt = "UNDEFINED";

        switch (severity)
        {
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SEVERITY_HIGH:   severityFmt = "HIGH";   break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SEVERITY_MEDIUM: severityFmt = "MEDIUM"; break;
            case bindbc.opengl.bind.arb.core_43.GL_DEBUG_SEVERITY_LOW:    severityFmt = "LOW"; break;
            default: break;
        }

        const(char)[] text = fromStringz( message );

        const int nvidiaPerfWarningId = 131185;

        try
        {
            if (id != nvidiaPerfWarningId)
            {
                writefln( "OpenGL: %s [source=%s type=%s severity=%s id=%u", text, sourceFmt, typeFmt, severityFmt, id );
            }
        }
        catch(Exception e)
        {
        }

        if (severity != undefinedSeverity && severity != bindbc.opengl.bind.arb.core_43.GL_DEBUG_SEVERITY_LOW && severity != bindbc.opengl.bind.arb.core_43.GL_DEBUG_SEVERITY_MEDIUM)
        {
            assert( false );
        }
    }
}

private align(1) struct LightUBO
{
    Vec3 lightDirectionInView;
}

public align(1) struct PerObjectUBO
{
    Matrix4x4 modelToClip;
    Matrix4x4 modelToView;
    int textureHandle;
}

public /*align(1)*/ struct TextureUBO
{
    GLuint64[ 32 ] textures;
}

public class Lines
{
    this( Vec3[] lines )
    {
        assert( lines.length > 0, "empty lines" );

        glCreateVertexArrays( 1, &vao );
        glBindVertexArray( vao );
        glObjectLabel( GL_VERTEX_ARRAY, vao, -1, toStringz( "lineVao" ) );

        uint vbo;
        glCreateBuffers( 1, &vbo );
        glObjectLabel( GL_BUFFER, vbo, -1, toStringz( "lineVbo" ) );

        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( vbo, lines.length * Vec3.sizeof, lines.ptr, flags );
        glVertexArrayVertexBuffer( vao, 0, vbo, 0, Vec3.sizeof );

        glEnableVertexArrayAttrib( vao, 0 );
        glVertexArrayAttribFormat( vao, 0, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 0, 0 );

        elementCount = cast(uint)lines.length;

        glCreateBuffers( 1, &ubo );
        glNamedBufferStorage( ubo, uboStruct.sizeof, &uboStruct, flags );
    }

    public void updateUBO( Matrix4x4 projection, Matrix4x4 view )
    {
        Matrix4x4 mvp;
        mvp.makeIdentity();
        multiply( mvp, view, mvp );
        uboStruct.modelToView = mvp;
        multiply( mvp, projection, mvp );
        uboStruct.modelToClip = mvp;

        GLvoid* mappedMem = glMapNamedBuffer( ubo, GL_WRITE_ONLY );
        memcpy( mappedMem, &uboStruct, PerObjectUBO.sizeof );
        glUnmapNamedBuffer( ubo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 0, ubo );
    }

    public int getElementCount() const
    {
        return elementCount;
    }

    public void bind()
    {
        glBindVertexArray( vao );
    }

    private uint vao;
    private uint elementCount;
    private uint ubo;
    private PerObjectUBO uboStruct;
}

public abstract class Renderer
{
    public static void initGL( int screenWidth, int screenHeight )
    {
        //Texture.loadExtensionFunctions();
        //Shader.loadExtensionFunctions();

        bindbc.opengl.bind.arb.core_43.glDebugMessageCallback( &loggingCallbackOpenGL, null );
        bindbc.opengl.bind.arb.core_43.glDebugMessageControl( GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE );
        glEnable( bindbc.opengl.bind.arb.core_43.GL_DEBUG_OUTPUT );
        glEnable( bindbc.opengl.bind.arb.core_43.GL_DEBUG_OUTPUT_SYNCHRONOUS );
        //glEnable( GL_FRAMEBUFFER_SRGB );
        glEnable( GL_CULL_FACE );
        glEnable( GL_DEPTH_TEST );
        glDepthFunc( GL_LESS );

        glClipControl( GL_LOWER_LEFT, GL_ZERO_TO_ONE );
        glClearColor( 0, 0, 0, 1 );

        glCreateBuffers( 1, &lightUbo );
        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( lightUbo, LightUBO.sizeof, &lightUboStruct, flags );

        glCreateBuffers( 1, &textureUbo );
        glNamedBufferStorage( textureUbo, TextureUBO.sizeof, &textureUboStruct, flags );

        glCreateBuffers( 1, &textUbo );
        glNamedBufferStorage( textUbo, PerObjectUBO.sizeof, &textUboStruct, flags );

        orthoMat.makeProjection( 0, screenWidth, screenHeight, 0, -1, 1 );

        glCreateQueries( GL_TIME_ELAPSED, 4, queries.ptr );
    }

    public static void drawText( string text, Shader shader, Font font, Texture fontTex, float x, float y )
    {
        if (text != cachedText)
        {     
            Vertex[] vertices;
            Face[] faces;
            font.getGeometry( text, fontTex.getWidth(), fontTex.getHeight(), vertices, faces );
            generateVAO( vertices, faces, "textVAO", textVao );

            cachedText = text;
            textFaceLength = cast(int)faces.length;
        }

        shader.use();

        Matrix4x4 mvp;
        mvp.makeIdentity();
        //mvp.scale( xScale, yScale, 1 );
        mvp.translate( Vec3( x, y, 0 ) );
        multiply( mvp, orthoMat, mvp );
        updateTextUbo( mvp );

        glBlendFuncSeparate( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE );
        glEnable( GL_BLEND );
        renderVAO( textVao, textFaceLength * 3, [ 1, 1, 1, 1 ] );
        glDisable( GL_BLEND );
    }

    private static void updateLightUbo( Vec3 lightDirectionInView )
    {
        lightUboStruct.lightDirectionInView = lightDirectionInView;

        GLvoid* mappedMem = glMapNamedBuffer( lightUbo, GL_WRITE_ONLY );
        memcpy( mappedMem, &lightUboStruct, LightUBO.sizeof );
        glUnmapNamedBuffer( lightUbo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 1, lightUbo );
    }

    public static void updateTextureUbo( GLuint64[ 32 ] textures )
    {
        textureUboStruct.textures = textures;
        //writeln("0: ", textureUboStruct.textures[0]);
        //writeln("1: ", textureUboStruct.textures[1]);

        GLvoid* mappedMem = glMapNamedBuffer( textureUbo, GL_WRITE_ONLY );
        memcpy( mappedMem, textureUboStruct.textures.ptr, TextureUBO.sizeof );
        //memcpy( mappedMem, &textureUboStruct, textureUBO.sizeof );
        glUnmapNamedBuffer( textureUbo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 2, textureUbo );
    }

    public static void updateTextUbo( Matrix4x4 mvp )
    {
        textUboStruct.modelToClip = mvp;
        textUboStruct.textureHandle = 0;

        GLvoid* mappedMem = glMapNamedBuffer( textUbo, GL_WRITE_ONLY );
        memcpy( mappedMem, &textUboStruct, PerObjectUBO.sizeof );
        glUnmapNamedBuffer( textUbo );

        glBindBufferBase( GL_UNIFORM_BUFFER, 0, textUbo );
    }

    public static void clearScreen()
    {
        //glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

        static const float[] black = [ 0.2f, 0.2f, 0.2f, 0.0f ];
        glClearBufferfv( GL_COLOR, 0, black.ptr );

        static const float[] clear = [ 1 ];
        glClearBufferfv( GL_DEPTH, 0, clear.ptr );
    }

    public static void renderLines( Lines lines, Shader shader )
    {
        lines.bind();
        shader.use();
        glDrawArraysInstancedBaseInstance( GL_LINES, 0, lines.getElementCount() * 2, 1, 0 );
    }

    public static void renderVAO( uint vaoID, int elementCount, float[ 4 ] tintColor )
    {
        glBindVertexArray( vaoID );
        glDrawElementsInstancedBaseVertexBaseInstance( GL_TRIANGLES, elementCount, GL_UNSIGNED_INT, null, 1, 0, 0 );
    }

    public static void renderMesh( Mesh mesh, Shader shader, DirectionalLight light, Matrix4x4 viewToClip, Matrix4x4 worldToView )
    {
        updateLightUbo( Vec3( 0, 1, 0 ) );
        
        for (int subMeshIndex = 0; subMeshIndex < mesh.getSubMeshCount(); ++subMeshIndex)
        {
            //writeln("mesh.subMeshes[ ", subMeshIndex, " ].textureIndex: ", mesh.subMeshes[ subMeshIndex ].textureIndex, ", path: ", mesh.subMeshes[ subMeshIndex ].texturePath );
            mesh.bind( subMeshIndex );
            mesh.updateUBO( viewToClip, worldToView, mesh.subMeshes[ subMeshIndex ].textureIndex );
            shader.use();
            glDrawElementsInstancedBaseVertexBaseInstance( GL_TRIANGLES, mesh.getElementCount( subMeshIndex ) * 3, GL_UNSIGNED_INT, null, 1, 0, 0 );
        }
    }

    public static void generateVAO( Vertex[] vertices, Face[] faces, string debugName, out uint vao )
    {
        float[] positions = new float[ vertices.length * 3 ];
        float[] texcoords = new float[ vertices.length * 2 ];
        float[] normals   = new float[ vertices.length * 3 ];

        for (int vertexIndex = 0; vertexIndex < vertices.length; ++vertexIndex)
        {
            positions[ vertexIndex * 3 + 0 ] = vertices[ vertexIndex ].pos[ 0 ];
            positions[ vertexIndex * 3 + 1 ] = vertices[ vertexIndex ].pos[ 1 ];
            positions[ vertexIndex * 3 + 2 ] = vertices[ vertexIndex ].pos[ 2 ];
            
            texcoords[ vertexIndex * 2 + 0 ] = vertices[ vertexIndex ].uv[ 0 ];
            texcoords[ vertexIndex * 2 + 1 ] = vertices[ vertexIndex ].uv[ 1 ];
            
            normals[ vertexIndex * 3 + 0 ] = vertices[ vertexIndex ].normal[ 0 ];
            normals[ vertexIndex * 3 + 1 ] = vertices[ vertexIndex ].normal[ 1 ];
            normals[ vertexIndex * 3 + 2 ] = vertices[ vertexIndex ].normal[ 2 ];
        }

        glCreateVertexArrays( 1, &vao );
        glBindVertexArray( vao );
        glObjectLabel( GL_VERTEX_ARRAY, vao, -1, toStringz( debugName ) );

        uint positionVBO, uvVBO, normalVBO, ibo;
        glCreateBuffers( 1, &positionVBO );
        glObjectLabel( GL_BUFFER, positionVBO, -1, toStringz( "positionVBO" ) );
        glCreateBuffers( 1, &uvVBO );
        glObjectLabel( GL_BUFFER, uvVBO, -1, toStringz( "uvVBO" ) );
        glCreateBuffers( 1, &normalVBO );
        glObjectLabel( GL_BUFFER, normalVBO, -1, toStringz( "normalVBO" ) );

        const GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        glNamedBufferStorage( positionVBO, positions.length * 4, positions.ptr, flags );
        glNamedBufferStorage( uvVBO, texcoords.length * 4, texcoords.ptr, flags );
        glNamedBufferStorage( normalVBO, normals.length * 4, normals.ptr, flags );
        glVertexArrayVertexBuffer( vao, 0, positionVBO, 0, 3 * 4 );
        glVertexArrayVertexBuffer( vao, 1, uvVBO, 0, 2 * 4 );
        glVertexArrayVertexBuffer( vao, 2, normalVBO, 0, 3 * 4 );

        glCreateBuffers( 1, &ibo );
        glObjectLabel( GL_BUFFER, ibo, -1, toStringz( "ibo" ) );

        glNamedBufferStorage( ibo, faces.length * Face.sizeof, faces.ptr, flags );
        glVertexArrayElementBuffer( vao, ibo );

        glEnableVertexArrayAttrib( vao, 0 );
        glVertexArrayAttribFormat( vao, 0, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 0, 0 );

        glEnableVertexArrayAttrib( vao, 1 );
        glVertexArrayAttribFormat( vao, 1, 2, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 1, 1 );

        glEnableVertexArrayAttrib( vao, 2 );
        glVertexArrayAttribFormat( vao, 2, 3, GL_FLOAT, GL_FALSE, 0 );
        glVertexArrayAttribBinding( vao, 2, 2 );
    }

    public static void beginQuery()
    {
        glBeginQuery( GL_TIME_ELAPSED, queries[ frameIndex & 3 ] );
    }

    public static void endQuery()
    {
        glEndQuery( GL_TIME_ELAPSED );

        if (frameIndex > 3)
        {
            GLuint64 timeStamp;
            const uint index = ((frameIndex & 3) - 3) & 3;
            glGetQueryObjectui64v( queries[ index ], GL_QUERY_RESULT, &timeStamp );
            queryTime = timeStamp / 1000000.0f;
        }
    }

    private static LightUBO lightUboStruct;
    private static uint lightUbo;
    private static TextureUBO textureUboStruct;
    private static uint textureUbo;
    private static PerObjectUBO textUboStruct;
    private static uint textUbo;
    private static uint textVao;
    private static string cachedText;
    private static int textFaceLength;
    private static Matrix4x4 orthoMat;
    private static uint[ 4 ] queries;
    public static int frameIndex;
    public static float queryTime;
}
