import derelict.vulkan;
import std.stdio;
import std.array
, std.conv;
import sdlloader;
import vulkanloader;
import std.string;
import std.algorithm;

enum desiredPresentation        =   VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR;
enum fallbackPresentation       =   VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
enum desiredDeviceExtentions    =   [ VK_KHR_SWAPCHAIN_EXTENSION_NAME ];
enum desiredExtentions          =   [ VK_KHR_SURFACE_EXTENSION_NAME
                                    , VK_KHR_WIN32_SURFACE_EXTENSION_NAME ];
enum desiredLayers              =   [ "VK_LAYER_LUNARG_standard_validation"
                                    , "VK_LAYER_LUNARG_core_validation"
                                    , "VK_LAYER_LUNARG_parameter_validation"
                                    , "VK_LAYER_LUNARG_monitor"
                                    , "VK_LAYER_RENDERDOC_Capture" ];
enum queueFlag      = VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT;
enum desiredFormat  = VkSurfaceFormatKHR(
    VkFormat.VK_FORMAT_B8G8R8A8_UNORM, 
    VkColorSpaceKHR.VK_COLORSPACE_SRGB_NONLINEAR_KHR);


void main() {
    ///////////////////////////////////////////////////////////////
    // Init SDL
    auto sdlWindow   = defaultAppName.createWindow;
    auto sdlRenderer = sdlWindow.createRenderer;
    auto sdlInfo     = sdlWindow.info;
    scope(exit) {
        SDL_DestroyRenderer(sdlRenderer);
        SDL_DestroyWindow(sdlWindow);
    }


    ///////////////////////////////////////////////////////////////
    // Prepair Layers and Extentions lists
    const auto availableLayersList     = availableLayers
        .map!(l => l.layerName).toStrArray;
    const auto availableExtentionsList = availableExtentions(null)
        .map!(e => e.extensionName).toStrArray;

    writeln("Available layers:\n"    , availableLayersList);
    writeln("Available extentions:\n", availableExtentionsList, '\n');
    writeln();

    const auto extentions = desiredExtentions.intersect(availableExtentionsList);
    const auto layers     = desiredLayers.intersect(availableLayersList);


    ///////////////////////////////////////////////////////////////
    // Create Vulkan instance and pick Device
    auto vulkan       = defaultAppInfo.initVulkan(extentions,layers);
    scope(exit) vkDestroyInstance(vulkan, null);
    auto surface      = vulkan.createSurface(sdlInfo);
    auto targetDevice = vulkan
        .bind!physicalDevices
        .bind!sortByScore
        .bind!(filter!(d => d.score > 0))
        .bind!(filter!(d => d.isSurfaceSupported(surface, queueFlag)))
        .demand!"No suitable device found"
        .front;

    const auto queueFamilyIndex = targetDevice
        .queueFamilyProperties
        .queueFamilyIndex(queueFlag);
    
    const auto availableDeviceExtentions = targetDevice.availableExtentions(null)
        .map!(e => e.extensionName).toStrArray;
    const auto deviceExtentions = desiredDeviceExtentions
        .intersect(availableDeviceExtentions)
        .demand!(e => e.length > 0, "No swapchain extension available");

    writeln("\nAvailable device extentions:\n", availableDeviceExtentions, '\n');
    writeln("Use device extentions: \n", deviceExtentions);


    ///////////////////////////////////////////////////////////////
    // Create Logical Device
    auto device     = targetDevice.createDevice(queueFamilyIndex, deviceExtentions);
    auto graphQueue = device.acquire!vkGetDeviceQueue(queueFamilyIndex, 0);
    scope(exit) vkDestroyDevice(device, null);

    const auto format       = targetDevice
        .hasSurfaceFormat(surface, desiredFormat)
            ? desiredFormat
            : targetDevice.surfaceFormats(surface).front;
    const auto presentation = targetDevice
        .surfacePresentations(surface)
        .bind!canFind(desiredPresentation)
            ? desiredPresentation
            : fallbackPresentation;
    auto swapchain = device.createSwapchain(surface, format, presentation);
    scope(exit) vkDestroySwapchainKHR(device, swapchain, null);
//     auto images     = targetDevice.swapchainImages(swapchain);
//     auto imageViews = images.map!(i => targetDevice.createImageView(i)).array;
    
//     auto vertModule = targetDevice.createShaderModule("./example/shaders/bin/vert.spv");
//     auto fragModule = targetDevice.createShaderModule("./example/shaders/bin/frag.spv");

//     VkPipelineShaderStageCreateInfo[2] shaderStages = {
//         sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
//         pName: "main".toStringz
//     };
//     shaderStages[0].stage   = VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT;
//     shaderStages[1].stage   = VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT;
//     shaderStages[0].module_ = vertModule;
//     shaderStages[1].module_ = fragModule;

//     scope(exit) {
//         vkDestroyShaderModule(targetDevice, vertModule, null);
//         vkDestroyShaderModule(targetDevice, fragModule, null);
//         foreach(view; imageViews) {
//             vkDestroyImageView(targetDevice, view, null);
//         }
//     }

//     //////////////////////////////////////////////////////////////

//     auto layout       = targetDevice.createPipelineLayout;
//     auto renderpass   = targetDevice.createRenderPass(layout);
//     auto pipeline     = targetDevice.createPipeline(layout,renderpass,shaderStages);
//     auto framebuffers = imageViews
//         .map!( v => targetDevice.createFramebuffer(renderpass, v)).array;
//     auto commandPool  = targetDevice.createCommandPool;
//     auto commandBuffs = targetDevice.createCommandBuffer(commandPool, framebuffers.length);
//     scope(exit) {
//         vkDestroyCommandPool(targetDevice, commandPool, null);
//         foreach(buff; framebuffers) {
//             vkDestroyFramebuffer(targetDevice, buff, null);
//         }
//         vkDestroyPipeline(targetDevice, pipeline, null);
//         vkDestroyRenderPass(targetDevice, renderpass, null);
//         vkDestroyPipelineLayout(targetDevice, layout, null);
//     }

//     foreach (i, buffer; commandBuffs) {
//         VkCommandBufferBeginInfo beginInfo = {
//             sType: VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
//             flags: VkCommandBufferUsageFlagBits.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT
//         };

//         if (vkBeginCommandBuffer(buffer, &beginInfo) != VkResult.VK_SUCCESS) {
//             writeln("ERROR! Start");
//         }

//         VkClearValue clearColor;
//         clearColor.color.float32 = [0.0f, 0.0f, 0.0f, 1.0f];
//         VkRenderPassBeginInfo renderPassInfo = {
//             sType: VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
//             renderPass:  renderpass,
//             framebuffer: framebuffers[i],
//             renderArea:{{0, 0},VkExtent2D(640, 480)},
//             clearValueCount: 1,
//             pClearValues: &clearColor
//         };
//         vkCmdBeginRenderPass(buffer, &renderPassInfo, VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE);
//         vkCmdBindPipeline(buffer, VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline);
//         vkCmdDraw(buffer, 3, 1, 0, 0);
//         vkCmdEndRenderPass(buffer);
//         if (vkEndCommandBuffer(buffer) != VkResult.VK_SUCCESS) {
//             writeln("ERROR! end");
//         }
//     }

//     auto imageAvailableSemaphore = targetDevice.createSemaphores;
//     auto renderFinishedSemaphore = targetDevice.createSemaphores;
//     scope(exit){
//         vkDestroySemaphore(targetDevice, renderFinishedSemaphore, null);
//         vkDestroySemaphore(targetDevice, imageAvailableSemaphore, null);
//     }

//     (event){
//         //{ //draw
//             uint imageIndex;
//             VkResult result;
//             result = vkAcquireNextImageKHR(targetDevice, swapchain, ulong.max, imageAvailableSemaphore, null, &imageIndex);
//             if(result != VkResult.VK_SUCCESS){
//                 throw new StringException(imageIndex.to!string ~ result.to!string);
//             }
//             VkSemaphore[]          waitSemaphores   = [imageAvailableSemaphore];
//             VkPipelineStageFlags[] waitStages       = [VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];
//             VkSemaphore[]          signalSemaphores = [renderFinishedSemaphore];
//             VkSubmitInfo submitInfo = {
//                 sType: VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
//                 waitSemaphoreCount: 1,
//                 pWaitSemaphores:    waitSemaphores.ptr,
//                 pWaitDstStageMask:  waitStages.ptr,
//                 commandBufferCount: 1,
//                 pCommandBuffers: &commandBuffs[imageIndex],
//                 signalSemaphoreCount: 1,
//                 pSignalSemaphores: signalSemaphores.ptr
//             };
//             result = vkQueueSubmit(graphQueue, 1, &submitInfo, null);
//             if(result != VkResult.VK_SUCCESS){
//                 throw new StringException(result.to!string);
//             }

//             VkSwapchainKHR[] swapChains = [swapchain];
//             VkPresentInfoKHR presentInfo = {
//                 sType: VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
//                 waitSemaphoreCount: 1,
//                 pWaitSemaphores: signalSemaphores.ptr,
//                 swapchainCount: 1,
//                 pSwapchains: swapChains.ptr,
//                 pImageIndices: &imageIndex,
//             };
//             vkQueuePresentKHR(graphQueue, &presentInfo);
//         //}
//     }.eventLoop;
}
