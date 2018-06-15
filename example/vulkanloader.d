module vulkanloader;
public import derelict.vulkan;

import std.algorithm.iteration
     , std.string
     , std.conv
     , std.stdio
     , std.array
     , std.meta;
import sdlloader;

static this() {
    DerelictVulkan.load();
}

alias defaultAppName = Alias!"Hello Vulkan!";
immutable VkApplicationInfo defaultAppInfo = {
    sType: VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
    apiVersion:       VK_API_VERSION,
    pApplicationName: defaultAppName.ptr,
    pEngineName:      defaultAppName.ptr,
};

struct VulkanHandle(Handle) {
    alias    handle this;
    Handle   handle;
    VkResult status = VkResult.VK_NOT_READY;
    ref Handle opCast(T : Handle)() inout {
        return handle;
    }

    bool opCast(T : bool)() inout {
        static if(isPointer!Handle) {
            return VkResult.VK_SUCCESS == status
                && cast(bool)handle;
        } else {
            return VkResult.VK_SUCCESS == status;
        }
    }
}

alias VulkanInstance       = VulkanHandle!VkInstance;
alias VulkanLogicalDevice  = VulkanHandle!VkDevice;
alias VulkanSurface        = VulkanHandle!VkSurfaceKHR;
alias VulkanQueue          = VulkanHandle!VkQueue;
alias VulkanPipelineLayout = VulkanHandle!VkPipelineLayout;

alias surfacePresentations        = enumerate!vkGetPhysicalDeviceSurfacePresentModesKHR;
alias surfaceFormats              = enumerate!vkGetPhysicalDeviceSurfaceFormatsKHR;
alias physicalDevices             = enumerate!vkEnumeratePhysicalDevices;
alias queueFamilyProperties       = enumerate!vkGetPhysicalDeviceQueueFamilyProperties;
alias availableExtentions         = enumerate!vkEnumerateDeviceExtensionProperties;
alias availableValidationLayers   = enumerate!vkEnumerateInstanceLayerProperties;
alias availableInstanceExtentions = enumerate!vkEnumerateInstanceExtensionProperties;
alias swapchainImages             = enumerate!vkGetSwapchainImagesKHR;

alias surfaceCapabilities = create!vkGetPhysicalDeviceSurfaceCapabilitiesKHR;

auto properties(VkPhysicalDevice device) {
    VkPhysicalDeviceProperties properties;
    vkGetPhysicalDeviceProperties(device, &properties);
    return properties;
}

auto initVulkan( in ref VkApplicationInfo appInfo
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
    return create!vkCreateInstance(&instanceInfo, null);
}

auto createDevice( VkPhysicalDevice physicalDevice
                 , in string[]      extentionsList = [] ) {
    auto queuePriorities = [1.0f];
    VkDeviceQueueCreateInfo deviceQueueInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        queueFamilyIndex: 0,
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
    return physicalDevice.create!vkCreateDevice(&deviceInfo, null);
}

auto createSurface(VulkanInstance instance, SDL2WMInfo info) in {
    assert(instance);
    assert(info.isValid);
} do {
    VkWin32SurfaceCreateInfoKHR surfaceCreateInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        hwnd:      info.info.win.window,
        hinstance: info.info.win.hinstance
    };
    return instance.create!vkCreateWin32SurfaceKHR(&surfaceCreateInfo, null);
}

auto createSwapchain(VulkanLogicalDevice device, VulkanSurface surface) in {
    assert(device);
    assert(surface);
} do {
    VkSwapchainCreateInfoKHR createInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        surface:     surface,
        imageExtent: VkExtent2D(640, 480),
        minImageCount:    3,
        imageArrayLayers: 1,
        imageFormat:      VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
        imageColorSpace:  VkColorSpaceKHR.VK_COLORSPACE_SRGB_NONLINEAR_KHR,
        imageUsage:       VkImageUsageFlagBits.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        imageSharingMode: VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
        preTransform:     VkSurfaceTransformFlagBitsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        compositeAlpha:   VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        presentMode:      VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR,
        clipped:      true,
        oldSwapchain: null
    };
    return device.create!vkCreateSwapchainKHR(&createInfo, null);
}

auto createImageView(VulkanLogicalDevice device, VkImage image) in {
    assert(device);
    assert(image);
} do {
    VkImageViewCreateInfo createInfo = {
        sType:    VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        image:    image,
        format:   VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
        viewType: VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
        subresourceRange: {
            aspectMask: VkImageAspectFlagBits.VK_IMAGE_ASPECT_COLOR_BIT,
            levelCount: 1,
            layerCount: 1
        }
    };
    return device.create!vkCreateImageView(&createInfo, null);
}

auto createShaderModule(VulkanLogicalDevice device, string path) {
    import std.file : read;
    const auto data = read(path);
    VkShaderModuleCreateInfo createInfo = {
        sType:    VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        codeSize: data.length.to!uint,
        pCode:    cast(const(uint)*) data.ptr
    };
    return device.create!vkCreateShaderModule(&createInfo, null);
}

auto createPipeline( VulkanLogicalDevice  device
                   , VulkanPipelineLayout pipelineLayout 
                   , VkRenderPass         renderPass 
                   , VkPipelineShaderStageCreateInfo[] shaderStages)
{
    VkPipelineVertexInputStateCreateInfo vertexInputInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    };
    VkPipelineInputAssemblyStateCreateInfo inputAssembly = {
        sType:    VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology: VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
    };
    VkViewport viewport = {
        width:  defaultWindowSize.x,
        height: defaultWindowSize.y,
        maxDepth: 1
    };
    VkRect2D scissor = {
        extent: VkExtent2D(640, 480)
    };

    VkPipelineViewportStateCreateInfo viewportState = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount: 1,
        scissorCount:  1,
        pViewports:    &viewport,
        pScissors:     &scissor
    };

    VkPipelineRasterizationStateCreateInfo rasterizer  = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        polygonMode: VkPolygonMode.VK_POLYGON_MODE_FILL,
        lineWidth: 1.0f,
        cullMode: VkCullModeFlagBits.VK_CULL_MODE_BACK_BIT,
        frontFace: VkFrontFace.VK_FRONT_FACE_CLOCKWISE,
    };

    VkPipelineMultisampleStateCreateInfo multisampling = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        rasterizationSamples: VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        minSampleShading: 1.0f, // Optional
    };

    VkPipelineColorBlendAttachmentState colorBlendAttachment = {
        colorWriteMask: VkColorComponentFlagBits.VK_COLOR_COMPONENT_R_BIT
                      | VkColorComponentFlagBits.VK_COLOR_COMPONENT_G_BIT
                      | VkColorComponentFlagBits.VK_COLOR_COMPONENT_B_BIT
                      | VkColorComponentFlagBits.VK_COLOR_COMPONENT_A_BIT,
        srcColorBlendFactor: VkBlendFactor.VK_BLEND_FACTOR_ONE,  // Optional
        dstColorBlendFactor: VkBlendFactor.VK_BLEND_FACTOR_ZERO, // Optional
        colorBlendOp:        VkBlendOp.VK_BLEND_OP_ADD,      // Optional
        srcAlphaBlendFactor: VkBlendFactor.VK_BLEND_FACTOR_ONE,  // Optional
        dstAlphaBlendFactor: VkBlendFactor.VK_BLEND_FACTOR_ZERO, // Optional
        alphaBlendOp:        VkBlendOp.VK_BLEND_OP_ADD       // Optional
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
    return device.create!vkCreateGraphicsPipelines(null, 1, &pipelineInfo, null);
}

auto createPipelineLayout(VulkanLogicalDevice device){
    VkPipelineLayoutCreateInfo pipelineLayoutInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
    };

    return device.create!vkCreatePipelineLayout(&pipelineLayoutInfo, null);
}

auto createRenderPass(VulkanLogicalDevice device, VulkanPipelineLayout pipeline) in {
    assert(device);
    assert(pipeline);
} do {
    VkAttachmentDescription colorAttachment = {
        format:  VkFormat.VK_FORMAT_B8G8R8A8_UNORM,
        samples: VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        loadOp:  VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
    };
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
        pSubpasses: &subpass
    };
    return device.create!vkCreateRenderPass(&renderPassInfo, null);
}

auto createFramebuffer( VulkanLogicalDevice device
                      , VkRenderPass        renderPass
                      , VkImageView         view ) 
{
    VkFramebufferCreateInfo framebufferInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        renderPass: renderPass,
        attachmentCount: 1,
        pAttachments:    &view,
        width:  defaultWindowSize.x,
        height: defaultWindowSize.y,
        layers: 1
    };
    return device.create!vkCreateFramebuffer(&framebufferInfo, null);
}

auto createCommandPool(VulkanLogicalDevice device){
    VkCommandPoolCreateInfo poolInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        queueFamilyIndex: 0
    };
    return device.create!vkCreateCommandPool(&poolInfo, null);
}

auto createCommandBuffer(VulkanLogicalDevice device, VkCommandPool commandPool, ulong size) {
    VkCommandBufferAllocateInfo allocInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool: commandPool,
        level: VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        commandBufferCount: size.to!uint,
    };
    VkCommandBuffer[] target = new VkCommandBuffer[size];
    vkAllocateCommandBuffers(device, &allocInfo, target.ptr);
    return target;
}

//////////////////////////////////////////////////////////////
import std.range.primitives
     , std.traits;

template create(alias creator) {
    static assert( isCallable!creator, "Creator is not callable!" );
    static assert( Parameters!creator.length >= 1
                 , "Creator should match patern: `creator(..., Target*)`!" );
    alias Target = PointerTarget!(Parameters!creator[$-1]);
    
    auto create(Args...)(Args args) 
    if(__traits(compiles, creator(args, null)))
    out(result) {
        assert(result);
    } do {
        VulkanHandle!Target target;
        target.status = creator(args, &target.handle);
        writeln("Create `", Target.stringof, "`: ", target.status);
        return target;
    }
}

template enumerate(alias enumerator) {
    static assert( isCallable!enumerator, "Enumerator is not callable!");
    static assert( Parameters!enumerator.length >= 2
                 , "Enumerator should match patern: `enumarator(..., uint* count, Enumerable*)`!");
    alias Enumerable = PointerTarget!(Parameters!enumerator[$-1]);

    auto enumerate(Args...)(Args args)
    if(__traits(compiles, enumerator(args, null, null)))
    {
        uint count;
        enumerator( args, &count, null );
        auto list = new Enumerable[count];
        return !count ? list : () {
            enumerator( args, &count, list.ptr );
            return list;
        } ();
    }
}

auto intersect( in string[] left, in string[] right ) pure {
    import std.algorithm.searching : canFind;
    return left.filter!(a => right.canFind(a)).array;
}

auto toCStrArray(Range)(Range data) pure
if (isInputRange!(Unqual!Range))
{
    return data.map!(a => toStringz(a)).array;
}

auto toStrArray(Range)(Range data) pure 
if (isInputRange!(Unqual!Range))
{
    return data.map!(a => fromStringz(a.ptr).idup).array;
}