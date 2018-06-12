module sdlloader;
public import derelict.sdl2.sdl;
import std.string;
import std.stdio;
import std.conv;

class SDLLoader {
  this( in string title
      , uint width
      , uint height
      , SDL_WindowFlags flags = SDL_WINDOW_SHOWN) {
    SDL_Init(SDL_INIT_VIDEO);
    window   = SDL_CreateWindow( 
      toStringz(title), 0, 0,
      width, height, flags);
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    SDL_VERSION(&systemInfo.version_);
    if(!SDL_GetWindowWMInfo(window, &systemInfo)){
        writeln(systemInfo);
        writeln("ERROR: ", to!string(SDL_GetError()));
        return;
    }
  }

  void loop(void delegate(in SDL_Event event) cicle) {
    bool running = true;
    SDL_Event event;
    while(running)
    {
      if (SDL_PollEvent(&event))
      {
        if (event.type == SDL_QUIT)
          running = false;
      }
      cicle(event);
    }
  }

  ~this(){
    SDL_Quit();
  }

  SDL_SysWMinfo systemInfo; 
  SDL_Window*   window;
  SDL_Renderer* renderer;
}
