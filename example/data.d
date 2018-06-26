module data;
import derelict.vulkan;


struct Default {

enum string  appName    = "Hello Vulkan!";
enum uint[2] windowSize = [640, 480];
enum
VkApplicationInfo appInfo = {
    sType: VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
    apiVersion:       VK_API_VERSION,
    pApplicationName: appName.ptr,
    pEngineName:      appName.ptr,
};


enum queueFlag  = VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT;
enum format     = VkSurfaceFormatKHR(
    VkFormat.VK_FORMAT_B8G8R8A8_UNORM, 
    VkColorSpaceKHR.VK_COLORSPACE_SRGB_NONLINEAR_KHR);

enum presentation           =   VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR;
enum fallbackPresentation   =   VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;
enum deviceExtentions       =   [ VK_KHR_SWAPCHAIN_EXTENSION_NAME ];
enum extentions             =   [ VK_KHR_SURFACE_EXTENSION_NAME
                                , VK_KHR_WIN32_SURFACE_EXTENSION_NAME ];
enum layers                 =   [ "VK_LAYER_LUNARG_standard_validation"
                                , "VK_LAYER_LUNARG_core_validation"
                                , "VK_LAYER_LUNARG_parameter_validation"
                                , "VK_LAYER_LUNARG_monitor"
                                , "VK_LAYER_RENDERDOC_Capture" ];

static immutable
VkClearValue clearColor = { color: { float32: [0.0f, 0.0f, 0.0f, 1.0f] } };

enum VkPipelineStageFlags[] waitStages = [VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];

enum VkPipelineVertexInputStateCreateInfo 
vertexInputInfo = {
    sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
};
enum VkPipelineInputAssemblyStateCreateInfo 
inputAssembly = {
    sType:    VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    topology: VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST
};

enum VkPipelineRasterizationStateCreateInfo 
rasterizer  = {
    sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    polygonMode: VkPolygonMode.VK_POLYGON_MODE_FILL,
    lineWidth: 1.0f,
    cullMode: VkCullModeFlagBits.VK_CULL_MODE_NONE,
    frontFace: VkFrontFace.VK_FRONT_FACE_CLOCKWISE,
    depthBiasClamp: .0f
};

enum VkPipelineMultisampleStateCreateInfo 
multisampling = {
    sType: VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    rasterizationSamples: VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
};

enum VkAttachmentDescription 
colorAttachment = {
    samples: VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
    loadOp:  VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
    storeOp: VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
    stencilLoadOp:  VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
    stencilStoreOp: VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
    initialLayout:  VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
    finalLayout:    VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
};

enum VkSubpassDependency 
dependency = {
    srcSubpass: VK_SUBPASS_EXTERNAL,
    dstSubpass: 0,
    dstStageMask:  VkPipelineStageFlagBits.VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
    srcStageMask:  VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
    srcAccessMask: VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_READ_BIT
                 | VkAccessFlagBits.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
};

}