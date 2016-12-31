import camera;
import derelict.sdl2.sdl;
import derelict.util.exception;
import derelict.opengl3.gl3;
import mesh;
import renderer;
import shader;
import std.stdio;
import std.string;
import texture;
import vec3;

void main()
{
    DerelictSDL2.load();
        
    if (SDL_Init( SDL_INIT_EVERYTHING ) < 0)
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
        if (symName == "glGetSubroutineUniformLocation" || symName == "glVertexAttribL1d" || symName == "glEnableClientStateiEXT")
        {
            return ShouldThrow.No;
        }

        return ShouldThrow.Yes;
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
	//Mesh twoMeshes = new Mesh( "assets/pnt_tris_2_meshes.obj" );
    //Mesh sponza = new Mesh( "assets/sponza.obj" );
    
    Shader shader = new Shader( "assets/shader.vert.spv", "assets/shader.frag.spv" );
    shader.use();
    
    Camera camera = new Camera();
    camera.setProjection( 45, screenWidth / cast(float)screenHeight, 1, 300 );

    Texture gliderTex = new Texture( "assets/glider.tga" );

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
            else if (e.type == SDL_QUIT)
            {
                return;
            }
        }

        Renderer.clearScreen();
        cube.updateUBO( camera.getProjection() );
        Renderer.renderMesh( cube, Vec3( 0, 0, -20 ), gliderTex, shader );

		//twoMeshes.updateUBO( camera.getProjection() );
        //Renderer.renderMesh( twoMeshes, Vec3( 0, 0, -20 ), gliderTex, shader );

        SDL_GL_SwapWindow( win );
    }
}
