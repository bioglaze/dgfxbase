# dgfxbase
OpenGL 4.5 basecode using D language and Derelict SDL and OpenGL libraries.

## Features

  - SPIR-V shaders
  - GL debug message callback
  - GL object debug labels
  - Direct State Access
  - Uniform buffers
  - Gamma-correct rendering
  - NDC depth in range 0-1 like in other APIs
  - Bindless textures (not for SPIR-V shaders, as they don't support it)
  
## Building (Windows)

  - (optional) If you want to modify the SPIR-V shaders, Install VulkanSDK 1.0.46.0
  - (optional) If you want to modify the SPIR-V shaders, Run `compile_shaders.bat` to compile GLSL shaders into SPIR-V.
  - If you use VisualD, navigate into the project directory in command prompt and run `dub generate visuald`. Else run `dub build`
  - When you run the project, you should see some meshes and lines.
  
## Misc

  - Sponza downloaded from http://graphics.cs.williams.edu/data/meshes.xml