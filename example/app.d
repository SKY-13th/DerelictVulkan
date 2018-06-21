import derelict.vulkan;
import std.stdio;
import std.array
, std.conv;
import sdlloader;
import vulkanloader;
import std.string;
import std.algorithm.iteration;

enum desiredDeviceExtentions    =   [ VK_KHR_SWAPCHAIN_EXTENSION_NAME ];
enum desiredExtentions          =   [ VK_KHR_SURFACE_EXTENSION_NAME
                                    , VK_KHR_WIN32_SURFACE_EXTENSION_NAME ];
enum desiredLayers              =   [ "VK_LAYER_LUNARG_standard_validation"
                                    , "VK_LAYER_LUNARG_core_validation"
                                    , "VK_LAYER_LUNARG_parameter_validation"
                                    , "VK_LAYER_LUNARG_monitor"
                                    , "VK_LAYER_RENDERDOC_Capture" ];
enum queueFlag  = VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT;
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
    auto vulkan  = defaultAppInfo.initVulkan(extentions,layers);
    auto surface = vulkan.createSurface(sdlInfo);
    auto device  = vulkan
        .bind!physicalDevices
        .bind!sortByScore
        .bind!(filter!(d => d.score > 0))
        .bind!(filter!(d => d.surfaceSupport(surface, queueFlag)))
        .demand!"No suitable device found"
        .front;
    const auto queueFamilyIndex = device
        .queueFamilyProperties
        .queueFamilyIndex(queueFlag);
    
    // const auto availableDeviceExtentions = device.availableExtentions(null)
    //     .map!(e => e.extensionName).toStrArray;
    // const auto deviceExtentions = desiredDeviceExtentions
    //     .intersect(availableDeviceExtentions)
    //     .demand!(e => e.length > 0, "No swapchain extension available");

    // writeln("\nAvailable device extentions:\n", availableDeviceExtentions, '\n');
    // writeln("Use device extentions: \n", deviceExtentions);


    // ///////////////////////////////////////////////////////////////
    // // Create Logical Device
    // auto device     = device.createDevice(queueFamilyIndex.to!uint, deviceExtentions);
    // auto graphQueue = device.acquire!vkGetDeviceQueue(0,0);
    // scope(exit) {
    //     vkDestroyDevice(device, null);
    //     vkDestroyInstance(vulkan, null);
    // }
    
//     auto formats      = device.surfaceFormats(surface);
//     auto capabilities = device.surfaceCapabilities(surface);
//     auto presentation = device.surfacePresentations(surface);
//     writeln( "Formats:\n", formats
//            , "\nCapabilities:\n", capabilities
//            , "\nPresentation:\n", presentation );

    // auto swapchain  = device.createSwapchain(surface);
//     auto images     = device.swapchainImages(swapchain);
//     auto imageViews = images.map!(i => device.createImageView(i)).array;
    
//     auto vertModule = device.createShaderModule("./example/shaders/bin/vert.spv");
//     auto fragModule = device.createShaderModule("./example/shaders/bin/frag.spv");

//     VkPipelineShaderStageCreateInfo[2] shaderStages = {
//         sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
//         pName: "main".toStringz
//     };
//     shaderStages[0].stage   = VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT;
//     shaderStages[1].stage   = VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT;
//     shaderStages[0].module_ = vertModule;
//     shaderStages[1].module_ = fragModule;

//     scope(exit) {
//         vkDestroyShaderModule(device, vertModule, null);
//         vkDestroyShaderModule(device, fragModule, null);
//         foreach(view; imageViews) {
//             vkDestroyImageView(device, view, null);
//         }
//         vkDestroySwapchainKHR(device, swapchain, null);
//     }

//     //////////////////////////////////////////////////////////////

//     auto layout       = device.createPipelineLayout;
//     auto renderpass   = device.createRenderPass(layout);
//     auto pipeline     = device.createPipeline(layout,renderpass,shaderStages);
//     auto framebuffers = imageViews
//         .map!( v => device.createFramebuffer(renderpass, v)).array;
//     auto commandPool  = device.createCommandPool;
//     auto commandBuffs = device.createCommandBuffer(commandPool, framebuffers.length);
//     scope(exit) {
//         vkDestroyCommandPool(device, commandPool, null);
//         foreach(buff; framebuffers) {
//             vkDestroyFramebuffer(device, buff, null);
//         }
//         vkDestroyPipeline(device, pipeline, null);
//         vkDestroyRenderPass(device, renderpass, null);
//         vkDestroyPipelineLayout(device, layout, null);
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

//     auto imageAvailableSemaphore = device.createSemaphores;
//     auto renderFinishedSemaphore = device.createSemaphores;
//     scope(exit){
//         vkDestroySemaphore(device, renderFinishedSemaphore, null);
//         vkDestroySemaphore(device, imageAvailableSemaphore, null);
//     }

//     (event){
//         //{ //draw
//             uint imageIndex;
//             VkResult result;
//             result = vkAcquireNextImageKHR(device, swapchain, ulong.max, imageAvailableSemaphore, null, &imageIndex);
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
