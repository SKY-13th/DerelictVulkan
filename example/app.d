import derelict.vulkan;
import std.stdio;
import std.array;
import sdlloader;
import vulkanloader;
import std.string;
import std.algorithm.iteration;

void main() {
    uint width  = 640
       , height = 480;

    const auto availableLayers     = availableValidationLayersList
        .map!(l => l.layerName).toStrArray;
    const auto availableExtentions = availableInstanceExtentionsList
        .map!(e => e.extensionName).toStrArray;
    writeln("Available layers:\n"    , availableLayers);
    writeln("Available extentions:\n", availableExtentions);
    writeln();

    const auto extentions =
        [ VK_KHR_SURFACE_EXTENSION_NAME
        , VK_KHR_WIN32_SURFACE_EXTENSION_NAME ]
        .intersect(availableExtentions);
    const auto layers =
        [ "VK_LAYER_LUNARG_standard_validation"
        , "VK_LAYER_LUNARG_core_validation"
        , "VK_LAYER_LUNARG_parameter_validation"
        , "VK_LAYER_LUNARG_monitor"
        , "VK_LAYER_RENDERDOC_Capture" ]
        .intersect(availableLayers);

    auto vulkan      = defaultAppInfo.initVulkan(extentions, layers);
    writeln("Vulkan status: ", vulkan.status);
    auto sdlWindow   = defaultAppName.createWindow;
    auto sdlRenderer = sdlWindow.createRenderer;
    auto sdlInfo     = sdlWindow.info;

    (event) {
        // TODO: some stuff
    }.loop;

    vkDestroyInstance(vulkan, null);
    SDL_DestroyWindow(sdlWindow);
}
