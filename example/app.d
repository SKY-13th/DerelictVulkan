import derelict.vulkan;
import std.stdio;
import std.array;
import sdlloader;
import vulkanloader;
import std.string;
import std.algorithm.iteration;

void main() {
    auto sdlWindow   = defaultAppName.createWindow;
    auto sdlRenderer = sdlWindow.createRenderer;
    auto sdlInfo     = sdlWindow.info;
    scope(exit) {
        SDL_DestroyRenderer(sdlRenderer);
        SDL_DestroyWindow(sdlWindow);
    }

    const auto availableLayers     = availableValidationLayers
        .map!(l => l.layerName).toStrArray;
    const auto availableExtentions = availableInstanceExtentions
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


    auto vulkan      = defaultAppInfo.initVulkan(extentions,layers);
    auto physDevice  = vulkan.physicalDevices[0];
    writeln("QueueFamilyProperties: ", physDevice.queueFamilyProperties);
    auto logicDevice = physDevice.createDevice;
    auto surface     = vulkan.createSurface(sdlInfo);
    auto formats     = physDevice.surfaceFormats(surface);
    writeln("Surface formats: ", formats);
    
    scope(exit) {
        vkDestroyDevice(logicDevice, null);
        vkDestroyInstance(vulkan, null);
    }

    // (event) {
    //     // TODO: some stuff
    // }.eventLoop;
}
