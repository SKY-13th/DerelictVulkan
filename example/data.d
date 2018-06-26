module data;
import derelict.vulkan;

enum string  defaultAppName    = "Hello Vulkan!";
enum uint[2] defaultWindowSize = [640, 480];
immutable
VkApplicationInfo defaultAppInfo = {
    sType: VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
    apiVersion:       VK_API_VERSION,
    pApplicationName: defaultAppName.ptr,
    pEngineName:      defaultAppName.ptr,
};


enum queueFlag      = VkQueueFlagBits.VK_QUEUE_GRAPHICS_BIT;
enum desiredFormat  = VkSurfaceFormatKHR(
    VkFormat.VK_FORMAT_B8G8R8A8_UNORM, 
    VkColorSpaceKHR.VK_COLORSPACE_SRGB_NONLINEAR_KHR);

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

immutable
VkClearValue clearColor = { color: { float32: [0.0f, 0.0f, 0.0f, 1.0f] } };

enum VkPipelineStageFlags[] waitStages = [VkPipelineStageFlagBits.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];