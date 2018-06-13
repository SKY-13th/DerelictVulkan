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
    // const auto layers =
    //     [ "VK_LAYER_LUNARG_standard_validation"
    //     , "VK_LAYER_LUNARG_core_validation"
    //     , "VK_LAYER_LUNARG_parameter_validation"
    //     , "VK_LAYER_LUNARG_monitor"
    //     , "VK_LAYER_RENDERDOC_Capture" ]
    //     .intersect(availableLayers);


    auto vulkan      = defaultAppInfo.initVulkan(extentions);
    writeln("Vulkan status: ", vulkan.status);
    auto physDevice  = vulkan.physicalDevices[0];
    auto logicDevice = physDevice.createDevice;
    writeln("Device status: ", logicDevice.status);
    auto surface     = vulkan.createSurface(sdlInfo);
    writeln("Surface status: ", surface.status);

    (event) {
        // TODO: some stuff
    }.eventLoop;

    vkDestroyInstance(vulkan, null);
    SDL_DestroyWindow(sdlWindow);
}
