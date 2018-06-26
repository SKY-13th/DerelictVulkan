module sdlloader;
public import derelict.sdl2.sdl;
import std.string;
import std.stdio;
import std.conv;
import data;

struct SDL2Window {
    alias window this;
    SDL_Window*   window;
}
struct SDL2Renderer {
    alias renderer this;
    SDL_Renderer* renderer;
}

struct SDL2WMInfo {
    alias data this;
    SDL_SysWMinfo data;
    bool          isValid = false;
}

auto createWindow( in string        appName
                  , SDL_WindowFlags flags = SDL_WINDOW_SHOWN
                  , uint[2]         size  = Default.windowSize )
{
    SDL2Window output = {
        window: SDL_CreateWindow( 
            appName.toStringz, 0, 0,
            size[0],
            size[1],
            flags )
    };
    return output;
}

auto createRenderer( SDL2Window        window
                   , SDL_RendererFlags flags = SDL_RENDERER_ACCELERATED )
{
    SDL2Renderer output = {
        renderer: SDL_CreateRenderer(window, -1, flags)
    };
    return output;
}

auto info( SDL2Window window ) {
    SDL2WMInfo info;
    SDL_VERSION(&info.version_);
    info.isValid = SDL_GetWindowWMInfo(window, &info.data).to!bool;
    return info;
}

void eventLoop(void delegate(in SDL_Event event) cicle) {
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

static this() {
    DerelictSDL2.load();
    SDL_Init(SDL_INIT_VIDEO);
}

static ~this() {
    if(DerelictSDL2.isLoaded) {
        SDL_Quit();
    }
};