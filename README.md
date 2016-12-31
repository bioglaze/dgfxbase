# dgfxbase
OpenGL 4.5 basecode using D language and Derelict SDL and OpenGL libraries.

## Features

  - SPIR-V shaders
  - GL debug message callback
  - GL object debug labels
  - Direct State Access
  - Uniform buffers
  - NDC depth in range 0-1 like in other APIs

## Building (Windows)

  - Install VulkanSDK 1.0.37.0
  - Run `compile_shaders.bat` to compile GLSL shaders into SPIR-V.
  - Navigate into the project directory in command prompt and run `dub build`
  - If you use VisualD, Run `dub generate visuald`. Now you can open the generated .sln.
  - When you run the project, you should see a spinning, textured cube.
  