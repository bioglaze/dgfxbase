import camera;
import derelict.opengl3.gl3;
import derelict.sdl2.sdl;
import derelict.util.exception;
import dirlight;
import Font;
import intersection;
import mesh;
import octree;
import renderer;
import shader;
import std.datetime;
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
      
    Renderer.initGL( screenWidth, screenHeight );

    SDL_GL_SetSwapInterval( 1 );
    SDL_SetWindowTitle( win, "DGFXBase" );

    //Mesh cube = new Mesh( "assets/cube.obj", "" );
    //cube.setPosition( Vec3( 9, 2, 180 ) );

    Mesh sponza = new Mesh( "assets/sponza.obj", "assets/sponza_materials.txt" );
    sponza.setScale( 0.5f );

    StopWatch sw;
    sw.start();
    Mesh armadillo = new Mesh( "assets/armadillo.obj", "" );
    long execMs = sw.peek().msecs;
    //writeln( "Armadillo has ", armadillo.getElementCount( 0 ), " triangles" );
    //writeln( "Armadillo loading took ", execMs, " ms" );
    const float xoff = -4;
    const float yoff = 4;
    armadillo.setPosition( Vec3( 0 + xoff, -5 + yoff, -15 ) );
    armadillo.setScale( 0.05f );
    
    Shader shader = new Shader( "assets/shader.vert", "assets/shader.frag" );
    Shader lineShader = new Shader( "assets/line_shader.vert.spv", "assets/line_shader.frag.spv" );
    
    Camera camera = new Camera();
    camera.setProjection( 45, screenWidth / cast(float)screenHeight, 1, 800 );
    camera.lookAt( Vec3( 0, 0, 0 ), Vec3( 0, 0, 200 ) );
    camera.moveForward( -200 );

    Font font = new Font( "assets/font.bin" );
    
    Texture fontTex = new Texture( "assets/font.tga" );
    Texture gliderTex = new Texture( "assets/glider.tga" );
    Texture rleTex = new Texture( "assets/textures/vase_plant_rle.tga" );
    rleTex.makeResident();

    GLuint64[ 32 ] textures;

    int i = 0;
    foreach (texture; sponza.textureFromMaterial)
    {
        textures[ i ] = texture.getHandle64();
        //writeln("index ", i, ": ", texture.path);

        for (int subMeshIndex = 0; subMeshIndex < sponza.subMeshes.length; ++subMeshIndex)
        {
            if (sponza.subMeshes[ subMeshIndex ].texturePath == texture.path)
            {
                sponza.subMeshes[ subMeshIndex ].textureIndex = i;
                continue;
            }
        }

        ++i;
    }

    //textures[ 30 ] = gliderTex.getHandle64();
    textures[ 30 ] = rleTex.getHandle64();
    textures[ 31 ] = fontTex.getHandle64();
    gliderTex.makeResident();
    fontTex.makeResident();

    Renderer.updateTextureUbo( textures );

    DirectionalLight dirLight = new DirectionalLight( Vec3( 0, 1, 0 ) );

    sw.start();
    Octree octree = new Octree( armadillo.getSubMeshVertices( 0 ), armadillo.getSubMeshIndices( 0 ), 2.0f, 0.9f );
    execMs = sw.peek().msecs;
    writeln( "Armadillo voxelization took ", execMs, " ms" );

    sw.start();

    Vec3[] armadilloLinesModelSpace = octree.getLines();
    Vec3[] armadilloLinesWorldSpace;

    for (int lineIndex = 0; lineIndex < armadilloLinesModelSpace.length; ++lineIndex)
    {
        armadilloLinesWorldSpace ~= armadilloLinesModelSpace[ lineIndex ] * armadillo.getScale() + armadillo.getPosition();
    }

    Lines octreeLines = new Lines( armadilloLinesWorldSpace );

    execMs = sw.peek().msecs;
    writeln( "Armadillo line creation took ", execMs, " ms" );

    Vec3 aabbPos = Vec3( 5, 5, -22 );

    Aabb testAabb;
    testAabb.min.x = -1 + aabbPos.x;
    testAabb.min.y = -1 + aabbPos.y;
    testAabb.min.z = -1 + aabbPos.z;
    testAabb.max.x =  1 + aabbPos.x;
    testAabb.max.y =  1 + aabbPos.y;
    testAabb.max.z =  1 + aabbPos.z;
    Lines aabbLines = new Lines( testAabb.getLines() );

    bool grabMouse = false;

    sw.start();

    long startFrameUs;
    long endFrameUs;
    long deltaUs;

    while (true)
    {
        startFrameUs = sw.peek().usecs;

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
            else if (e.type == SDL_MOUSEMOTION && grabMouse)
            {
                float deltaX = e.motion.xrel;
                float deltaY = e.motion.yrel;
                    
                if (e.motion.xrel != 0)
                {
                    camera.offsetRotate( Vec3( 0, 1, 0 ), -deltaX / 20 );
                }
                if (e.motion.yrel != 0)
                {
                    camera.offsetRotate( Vec3( 1, 0, 0 ), -deltaY / 20 );
                }
            }
            else if (e.type == SDL_MOUSEWHEEL)
            {
                camera.moveForward( (e.wheel.y > 0) ? -1 : 1 );
            }
            else if (e.type == SDL_KEYDOWN)
            {
                if (e.key.keysym.sym == SDLK_ESCAPE)
                {
                    return;
                }
                else if (e.key.keysym.sym == SDLK_LEFT)
                {
                    camera.offsetRotate( Vec3( 0, 1, 0 ), 1 );
                }
                else if (e.key.keysym.sym == SDLK_RIGHT)
                {
                    camera.offsetRotate( Vec3( 0, 1, 0 ), -1 );
                }
                else if (e.key.keysym.sym == SDLK_w)
                {
                    camera.moveForward( 0.001f * cast(float)deltaUs );
                }
                else if (e.key.keysym.sym == SDLK_s)
                {
                    camera.moveForward( -0.001f * cast(float)deltaUs );
                }
                else if (e.key.keysym.sym == SDLK_a)
                {
                    camera.moveRight( 0.001f * cast(float)deltaUs );
                }
                else if (e.key.keysym.sym == SDLK_d)
                {
                    camera.moveRight( -0.001f * cast(float)deltaUs );
                }
                else if (e.key.keysym.sym == SDLK_e)
                {
                    camera.moveUp( -0.001f * cast(float)deltaUs );
                }
                else if (e.key.keysym.sym == SDLK_q)
                {
                    camera.moveUp( 0.001f * cast(float)deltaUs );
                }
            }
            else if (e.type == SDL_QUIT)
            {
                return;
            }
        }

        camera.updateMatrix();

        Renderer.clearScreen();
        
        //Renderer.renderMesh( cube, shader, dirLight );

        Renderer.renderMesh( sponza, shader, dirLight, camera.getProjection(), camera.getView() );

        Renderer.renderMesh( armadillo, shader, dirLight, camera.getProjection(), camera.getView() );

        octreeLines.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderLines( octreeLines, lineShader );

        aabbLines.updateUBO( camera.getProjection(), camera.getView() );
        Renderer.renderLines( aabbLines, lineShader );

        Renderer.drawText( "This is text", shader, font, fontTex, 100, 70 );

        SDL_GL_SwapWindow( win );

        endFrameUs = sw.peek().usecs;
        deltaUs = endFrameUs - startFrameUs;
        /*const(char)* error = SDL_GetError();

        if (*error != '\n')
        {
            writeln("SDL error: ", *error);
            assert( false, "SDL error" );
        }*/
    }
}
