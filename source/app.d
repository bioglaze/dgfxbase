import camera;
import derelict.opengl3.gl3;
import derelict.sdl2.sdl;
import derelict.util.exception;
import dirlight;
import mesh;
import octree;
import renderer;
import shader;
import std.stdio;
import std.string;
import texture;
import vec3;

void main()
{
    DerelictSDL2.load();
        
    if (SDL_Init( SDL_INIT_VIDEO ) < 0)
    {
        const(char)* message = SDL_GetError();
        writeln( "Failed to initialize SDL: ", message );
    }
        
    SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE, 24 );
    SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
    SDL_GL_SetAttribute( SDL_GL_CONTEXT_MAJOR_VERSION, 4 );
    SDL_GL_SetAttribute( SDL_GL_CONTEXT_MINOR_VERSION, 5 );
    SDL_GL_SetAttribute( SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE );
    SDL_GL_SetAttribute( SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG | SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG );

    immutable int screenWidth = 1024;
    immutable int screenHeight = 768;

    SDL_Window* win = SDL_CreateWindow( "GFX base", SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, screenWidth, screenHeight, SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN );

    ShouldThrow missingSymFunc( string symName )
    {
        return (symName == "glGetSubroutineUniformLocation" || symName == "glVertexAttribL1d" || symName == "glEnableClientStateiEXT") ? ShouldThrow.No : ShouldThrow.Yes;
    }

    DerelictGL3.missingSymbolCallback = &missingSymFunc;
    DerelictGL3.load();
    const auto context = SDL_GL_CreateContext( win );
        
    if (!context)
    {
        throw new Error( "Failed to create GL context!" );
    }

    DerelictGL3.reload();
      
    Renderer.initGL();

    SDL_GL_SetSwapInterval( 1 );
    
    Mesh cube = new Mesh( "assets/cube.obj" );
    Mesh cube1 = new Mesh( "assets/cube.obj" );
    Mesh cube2 = new Mesh( "assets/cube.obj" );
    Mesh cube3 = new Mesh( "assets/cube.obj" );
    Mesh suzanne = new Mesh( "assets/suzanne.obj" );

    const float xoff = -4;
    const float yoff = 4;
    cube.setPosition( Vec3( 0, 2, -20 ) );
    cube1.setPosition( Vec3( 0 + xoff, -6 + yoff, -20 ) );
    cube2.setPosition( Vec3( 2 + xoff, -8 + yoff, -20 ) );
    cube3.setPosition( Vec3( 2 + xoff, -6 + yoff, -22 ) );
    suzanne.setPosition( Vec3( 0 + xoff, -2 + yoff, -22 ) );
    //suzanne.setScale( 2 );
    
    Shader shader = new Shader( "assets/shader.vert", "assets/shader.frag" );
    Shader lineShader = new Shader( "assets/line_shader.vert.spv", "assets/line_shader.frag.spv" );
    
    Camera camera = new Camera();
    camera.setProjection( 45, screenWidth / cast(float)screenHeight, 1, 300 );
    camera.lookAt( Vec3( 0, 0, 0 ), Vec3( 0, 0, 200 ) );
    float camZ = 0;

    Texture gliderTex = new Texture( "assets/glider.tga" );
    
    GLuint64[ 10 ] textures;
    textures[ 0 ] = gliderTex.getHandle64();
    gliderTex.makeResident();

    Renderer.updateTextureUbo( textures );

    DirectionalLight dirLight = new DirectionalLight( Vec3( 0, 1, 0 ) );

    Vec3[] linePoints = new Vec3[ 4 ];
    linePoints[ 0 ] = Vec3( 0, 0, -20 );
    linePoints[ 1 ] = Vec3( 5, 0, -20 );
    linePoints[ 2 ] = Vec3( 5, 5, -20 );
    linePoints[ 3 ] = Vec3( 0, 5, -20 );
    
    Lines lines = new Lines( linePoints );

    Octree octree = new Octree( suzanne.getSubMeshVertices( 0 ), suzanne.getSubMeshIndices( 0 ), 8, 2 );

    bool grabMouse = false;

    while (true)
    {
        SDL_Event e;

        while (SDL_PollEvent( &e ))
        {
            if (e.type == SDL_WINDOWEVENT)
            {
                if (e.window.event == SDL_WINDOWEVENT_CLOSE)
                {
                    return;
                }
            }
            else if (e.type == SDL_MOUSEBUTTONDOWN)
            {
                grabMouse = true;
            }
            else if (e.type == SDL_MOUSEBUTTONUP)
            {
                grabMouse = false;
            }
            else if (e.type == SDL_MOUSEMOTION)
            {
            
            }
            else if (e.type == SDL_MOUSEWHEEL)
            {
                camZ += (e.wheel.y > 0) ? -1 : 1;
                writeln( "camZ: ", camZ );
                camera.lookAt( Vec3( 0, 0, camZ ), Vec3( 0, 0, 200 ) );
            }
            else if (e.type == SDL_QUIT)
            {
                return;
            }
        }

        Renderer.clearScreen();
        
        cube.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderMesh( cube, gliderTex, shader, dirLight );

        cube1.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderMesh( cube1, gliderTex, shader, dirLight );

        cube2.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderMesh( cube2, gliderTex, shader, dirLight );
        
        cube3.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderMesh( cube3, gliderTex, shader, dirLight );

        suzanne.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderMesh( suzanne, gliderTex, shader, dirLight );

        lines.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderLines( lines, lineShader );

        SDL_GL_SwapWindow( win );
    }
}
