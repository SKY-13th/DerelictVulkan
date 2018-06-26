module vulkanloader;
public import derelict.vulkan;
public import vulkan.utils;

import std.algorithm
     , std.functional
     , std.string
     , std.conv
     , std.stdio
     , std.array
     , std.meta;
import data;
import sdlloader;

static this() {
    DerelictVulkan.load();
}

alias sortByScore = d => d.sort!((a,b) => a.score < b.score).array;
alias score       = (VkPhysicalDevice device) =>
    device.queueFamilyProperties
        .bind!( q => q.queueFamilyIndex(VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT) )
        .bind!( _ => device.features.geometryShader 
                ? device.properties.just
                : nothing!(typeof(device.properties)))
        .bind!((properties) {
            bool isDiscreteGPU = properties.deviceType == VkPhysicalDeviceType.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
            return properties.limits.maxImageDimension2D
                    + ( isDiscreteGPU ? 1000 : 0 );
        });

auto initVulkan( in VkApplicationInfo appInfo
               , in string[] extentionsList = []
               , in string[] layersList     = [] )
{
    writeln("Use layers: "    , layersList);
    writeln("Use extentions: ", extentionsList);

    VkInstanceCreateInfo instanceInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pApplicationInfo:        &appInfo,
        enabledLayerCount:       layersList.length.to!uint,
        ppEnabledLayerNames:     layersList.toCStrArray.ptr,
        enabledExtensionCount:   extentionsList.length.to!uint,
        ppEnabledExtensionNames: extentionsList.toCStrArray.ptr
    };
    return acquire!vkCreateInstance(&instanceInfo, null);
}

auto createDevice( VkPhysicalDevice physicalDevice
                 , uint             queueFamilyIndex
                 , in string[]      extentionsList = [] ) {
    auto queuePriorities = [1.0f];
    VkDeviceQueueCreateInfo deviceQueueInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        queueFamilyIndex: queueFamilyIndex,
        queueCount:       1,
        pQueuePriorities: queuePriorities.ptr
    };
    VkDeviceCreateInfo deviceInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        queueCreateInfoCount:    1,
        pQueueCreateInfos:       &deviceQueueInfo,
        enabledExtensionCount:   extentionsList.length.to!uint,
        ppEnabledExtensionNames: extentionsList.toCStrArray.ptr
    };
    return physicalDevice.acquire!vkCreateDevice(&deviceInfo, null);
}

auto createSurface(VkInstance instance, SDL2WMInfo info) {
    VkWin32SurfaceCreateInfoKHR surfaceCreateInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        hwnd:      info.info.win.window,
        hinstance: info.info.win.hinstance
    };
    return instance.acquire!vkCreateWin32SurfaceKHR(&surfaceCreateInfo, null);
}

auto createSwapchain( VkDevice           device
                    , VkSurfaceKHR       surface
                    , VkSurfaceFormatKHR format
                    , VkPresentModeKHR   present
                    , VkExtent2D         extent ) 
{
    VkSwapchainCreateInfoKHR createInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        surface:     surface,
        imageExtent: extent,
        minImageCount:    3,
        imageArrayLayers: 1,
        imageFormat:      format.format,
        imageColorSpace:  format.colorSpace,
        imageUsage:       VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        imageSharingMode: VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
        preTransform:     VkSurfaceTransformFlagBitsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        compositeAlpha:   VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        presentMode:      present,
        clipped:      true,
        oldSwapchain: null
    };
    return device.acquire!vkCreateSwapchainKHR(&createInfo, null);
}

auto createImageView( VkDevice device
                    , VkImage image
                    , VkFormat format )
{
    VkImageViewCreateInfo createInfo = {
        sType:    VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        image:    image,
        format:   format,
        viewType: VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
        subresourceRange: {
            aspectMask: VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
            levelCount: 1,
            layerCount: 1
        }
    };
    return device.acquire!vkCreateImageView(&createInfo, null);
}

auto createShaderModule(VkDevice device, string path) {
    import std.file : read;
    scope(failure) return nothing!VkShaderModule;
    const auto data = read(path);
    VkShaderModuleCreateInfo createInfo = {
        sType:    VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        codeSize: data.length.to!uint,
        pCode:    cast(const(uint)*) data.ptr
    };
    return device.acquire!vkCreateShaderModule(&createInfo, null);
}

auto createPipeline( VkDevice         device
                   , VkPipelineLayout pipelineLayout 
                   , VkRenderPass     renderPass
                   , VkExtent2D       extent
                   , VkPipelineShaderStageCreateInfo[] shaderStages)
{
    auto vertexInputInfo = Default.vertexInputInfo;
    auto inputAssembly   = Default.inputAssembly;
    auto rasterizer      = Default.rasterizer;
    auto multisampling   = Default.multisampling;
    
    VkViewport viewport = {
        x:0, y:0,
        width:  extent.width,
        height: extent.height,
        maxDepth: 1,
        minDepth: 0
    };
    VkRect2D scissor = {
        extent: extent
    };
    VkPipelineViewportStateCreateInfo viewportState = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount: 1,
        scissorCount:  1,
        pViewports:    &viewport,
        pScissors:     &scissor
    };

    VkPipelineColorBlendAttachmentState colorBlendAttachment = {
        colorWriteMask: 0xf,
    };
    VkPipelineColorBlendStateCreateInfo colorBlending = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        attachmentCount: 1,
        pAttachments:  &colorBlendAttachment,
    };

    VkGraphicsPipelineCreateInfo pipelineInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount:          shaderStages.length.to!uint,
        pStages:             shaderStages.ptr,
        pVertexInputState:   &vertexInputInfo,
        pInputAssemblyState: &inputAssembly,
        pViewportState:      &viewportState,
        pRasterizationState: &rasterizer,
        pMultisampleState:   &multisampling,
        pColorBlendState:    &colorBlending,
        layout: pipelineLayout,
        renderPass: renderPass
    };
    return device.acquire!vkCreateGraphicsPipelines(null, 1, &pipelineInfo, null);
}

auto createPipelineLayout(VkDevice device) {
    VkPipelineLayoutCreateInfo pipelineLayoutInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
    };
    return device.acquire!vkCreatePipelineLayout(&pipelineLayoutInfo, null);
}

auto createRenderPass(VkDevice device, VkPipelineLayout pipeline, VkFormat format) {
    auto colorAttachment   = Default.colorAttachment;
    colorAttachment.format = format;
    auto dependency        = Default.dependency;

    VkAttachmentReference colorAttachmentRef = {
        layout: VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
    };
    VkSubpassDescription subpass = {
        pipelineBindPoint: VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
        colorAttachmentCount: 1,
        pColorAttachments: &colorAttachmentRef
    };

    VkRenderPassCreateInfo renderPassInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        attachmentCount: 1,
        pAttachments: &colorAttachment,
        subpassCount: 1,
        pSubpasses:   &subpass,
        dependencyCount: 1,
        pDependencies:   &dependency
    };
    return device.acquire!vkCreateRenderPass(&renderPassInfo, null);
}

auto createFramebuffer( VkDevice     device
                      , VkRenderPass renderPass
                      , VkImageView  view )
{
    VkFramebufferCreateInfo framebufferInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        renderPass: renderPass,
        attachmentCount: 1,
        pAttachments:    &view,
        width:  Default.windowSize[0],
        height: Default.windowSize[1],
        layers: 1
    };
    return device.acquire!vkCreateFramebuffer(&framebufferInfo, null);
}

auto createCommandPool(VkDevice device, uint queueFamilyIndex){
    VkCommandPoolCreateInfo poolInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        queueFamilyIndex: queueFamilyIndex
    };
    return device.acquire!vkCreateCommandPool(&poolInfo, null);
}

auto createCommandBuffer(VkDevice device, VkCommandPool commandPool, ulong count) {
    VkCommandBufferAllocateInfo allocInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool: commandPool,
        level: VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount: count.to!uint,
    };
    VkCommandBuffer[] target = new VkCommandBuffer[count];
    return target.request!vkAllocateCommandBuffers(device, &allocInfo);
}

auto createSemaphore(VkDevice device){
    VkSemaphoreCreateInfo semaphoreInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
    };
    return device.acquire!vkCreateSemaphore(&semaphoreInfo, null);
}