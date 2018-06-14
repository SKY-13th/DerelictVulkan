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
    const auto availableExtentions = availableInstanceExtentions(null)
        .map!(e => e.extensionName).toStrArray;
    writeln("Available layers:\n"    , availableLayers);
    writeln("Available extentions:\n", availableExtentions);
    writeln();

    const auto extentions =
        [ VK_KHR_SURFACE_EXTENSION_NAME
        , VK_KHR_WIN32_SURFACE_EXTENSION_NAME ]
        .intersect(availableExtentions);
    const auto layers =
        [ "VK_LAYER_RENDERDOC_Capture"
        //, "VK_LAYER_LUNARG_standard_validation"
        // , "VK_LAYER_LUNARG_core_validation"
        // , "VK_LAYER_LUNARG_parameter_validation"
        // , "VK_LAYER_LUNARG_monitor" 
        ].intersect(availableLayers);


    auto vulkan      = defaultAppInfo.initVulkan(extentions,layers);
    auto physDevice  = vulkan.physicalDevices[0];
    writeln("QueueFamilyProperties: ", physDevice.queueFamilyProperties);
    
    const auto availableDeviceExtentions = physDevice.availableExtentions(null)
        .map!(e => e.extensionName).toStrArray;
    writeln("Available device extentions:\n", availableExtentions, "\n");
    const auto deviceExtentions = [ VK_KHR_SWAPCHAIN_EXTENSION_NAME ]
        .intersect(availableDeviceExtentions);

    auto logicDevice  = physDevice.createDevice(deviceExtentions);
    auto surface      = vulkan.createSurface(sdlInfo);
    auto formats      = physDevice.surfaceFormats(surface);
    auto capabilities = physDevice.surfaceCapabilities(surface);
    auto presentation = physDevice.surfacePresentations(surface);
    writeln( "Formats:\n", formats
           , "\nCapabilities:\n", capabilities
           , "\nPresentation:\n", presentation );

    auto swapchain  = logicDevice.createSwapchain(surface);
    auto images     = logicDevice.swapchainImages(swapchain);
    auto imageViews = images.map!(i => logicDevice.createImageView(i)).array;

    scope(exit) {
        foreach(view; imageViews) {
            vkDestroyImageView(logicDevice, view, null);
        }
        vkDestroySwapchainKHR(logicDevice, swapchain, null);
        vkDestroyDevice(logicDevice, null);
        vkDestroyInstance(vulkan, null);
    }

    // (event) {
    //     // TODO: some stuff
    // }.eventLoop;
}
