import derelict.vulkan;
import std.stdio;
import std.array
     , std.conv;
import sdlloader;
import vulkanloader;
import std.string;
import std.algorithm;
import data;

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


    ///////////////////////////////////////////////////////////////
    // Create Swapchain
    const auto format = targetDevice.surfaceFormats(surface)
        .bind!hasSurfaceFormatSupport(desiredFormat)
        .demand!"Can't obtain surface formats";
    const auto presentation = targetDevice
        .surfacePresentations(surface)
        .bind!find(desiredPresentation)
        .bind!front
        .fallback(fallbackPresentation);
    const auto extent = targetDevice.surfaceCapabilities(surface)
        .demand!"Can't obtain surface capabilities"
        .maxImageExtent;
    auto swapchain  = device.createSwapchain(surface, format, presentation, extent);
    scope(exit) vkDestroySwapchainKHR(device, swapchain, null);


    ///////////////////////////////////////////////////////////////
    // Prepair Shader Stages
    auto vertModule = device
        .createShaderModule("./example/shaders/bin/vert.spv")
        .demand!"No vertex shader found";
    auto fragModule = device
        .createShaderModule("./example/shaders/bin/frag.spv")
        .demand!"No fragment shader found";

    VkPipelineShaderStageCreateInfo[2] shaderStages = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        pName: "main".toStringz
    };
    shaderStages[0].stage   = VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[1].stage   = VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[0].module_ = vertModule;
    shaderStages[1].module_ = fragModule;


    //////////////////////////////////////////////////////////////
    // Setup Pipeline
    auto layout       = device.createPipelineLayout;
    auto renderpass   = device.createRenderPass(layout, format.format);
    auto pipeline     = device.createPipeline(layout, renderpass, extent, shaderStages);
    vkDestroyShaderModule(device, vertModule, null);
    vkDestroyShaderModule(device, fragModule, null);
    scope(exit) {
        vkDestroyPipeline(device, pipeline, null);
        vkDestroyRenderPass(device, renderpass, null);
        vkDestroyPipelineLayout(device, layout, null);
    }

    ///////////////////////////////////////////////////////////////
    // Prepair Framebuffers
    auto images       = device.swapchainImages(swapchain);
    auto imageViews   = images.map!( i => device
        .createImageView(i, format.format)
        .demand!"Can't create Image View" ).array;
    auto framebuffers = imageViews.map!( v => device
        .createFramebuffer(renderpass, v)
        .demand!"Can't create Framebuffer" ).array;
    scope(exit) {
        framebuffers.each!(b => vkDestroyFramebuffer(device, b, null));
        imageViews  .each!(v => vkDestroyImageView(device, v, null));
    }


    //////////////////////////////////////////////////////////////
    // Setup Command Buffers
    auto commandPool  = device.createCommandPool(queueFamilyIndex);
    scope(exit) vkDestroyCommandPool(device, commandPool, null);
    auto commandBuffs = device.createCommandBuffer(commandPool, framebuffers.length);

    {
        enum context   = VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE;
        enum bindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS;
        const VkCommandBufferBeginInfo beginInfo = {
            sType: VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            flags: VkCommandBufferUsageFlagBits.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT
        };
        VkRenderPassBeginInfo renderPassInfo = {
            sType: VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            renderPass:  renderpass,
            renderArea:{{0, 0},extent},
            clearValueCount: 1,
            pClearValues: &clearColor
        };

        commandBuffs.each!((i, buffer) =>
            vkBeginCommandBuffer(buffer, &beginInfo).just
            .bind!((_) {
                VkRenderPassBeginInfo info = renderPassInfo;
                info.framebuffer           = framebuffers[i];
                vkCmdBeginRenderPass(buffer, &info, context);
                vkCmdBindPipeline(buffer, bindPoint, pipeline);
                vkCmdDraw(buffer, 3, 1, 0, 0);
                vkCmdEndRenderPass(buffer);
                return _; })
            .bind!(_ => vkEndCommandBuffer(buffer))
            .expect!"Failed to write a command buffer");
    }


    //////////////////////////////////////////////////////////////
    // Setup Semaphores
    auto imageAvailableSemaphore = device.createSemaphore.demand;
    auto renderFinishedSemaphore = device.createSemaphore.demand;
    scope(exit) {
        vkDestroySemaphore(device, renderFinishedSemaphore, null);
        vkDestroySemaphore(device, imageAvailableSemaphore, null);
    }

    //////////////////////////////////////////////////////////////
    // Draw
    VkSemaphore[]    waitSemaphores   = [imageAvailableSemaphore];
    VkSemaphore[]    signalSemaphores = [renderFinishedSemaphore];
    VkSwapchainKHR[] swapChains       = [swapchain];
    VkSubmitInfo      submitInformation = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        waitSemaphoreCount: 1,
        pWaitSemaphores:    waitSemaphores.ptr,
        pWaitDstStageMask:  waitStages.ptr,
        commandBufferCount: 1,
        signalSemaphoreCount: 1,
        pSignalSemaphores: signalSemaphores.ptr
    };
    VkPresentInfoKHR presentInformation = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        waitSemaphoreCount: 1,
        pWaitSemaphores: signalSemaphores.ptr,
        swapchainCount: 1,
        pSwapchains: swapChains.ptr,
    };

    (event) { device
        .acquireNextImage(swapchain, ulong.max, imageAvailableSemaphore, null)
        .bind!((imageIndex) {
            VkSubmitInfo submitInfo    = submitInformation;
            submitInfo.pCommandBuffers = &commandBuffs[imageIndex];
            return vkQueueSubmit(graphQueue, 1, &submitInfo, null).just
                .bind!( _ => imageIndex ); })
        .bind!((imageIndex) {
            VkPresentInfoKHR presentInfo = presentInformation;
            presentInfo.pImageIndices    = &imageIndex;
            return vkQueuePresentKHR(graphQueue, &presentInfo); })
        .expect!"Can't draw frame";
    }.eventLoop;
}
