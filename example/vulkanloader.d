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
    bool opCast(T : bool)() inout {
        static if(isPointer!Handle) {
            return VkResult.VK_SUCCESS == status
                && cast(bool)handle;
        } else {
            return VkResult.VK_SUCCESS == status;
        }
    }
}

alias VulkanInstance      = VulkanHandle!VkInstance;
alias VulkanLogicalDevice = VulkanHandle!VkDevice;
alias VulkanSurface       = VulkanHandle!VkSurfaceKHR;
alias VulkanQueue         = VulkanHandle!VkQueue;

alias surfacePresentations        = enumerate!vkGetPhysicalDeviceSurfacePresentModesKHR;
alias surfaceFormats              = enumerate!vkGetPhysicalDeviceSurfaceFormatsKHR;
alias physicalDevices             = enumerate!vkEnumeratePhysicalDevices;
alias queueFamilyProperties       = enumerate!vkGetPhysicalDeviceQueueFamilyProperties;
alias availableExtentions         = enumerate!vkEnumerateDeviceExtensionProperties;
alias availableValidationLayers   = enumerate!vkEnumerateInstanceLayerProperties;
alias availableInstanceExtentions = enumerate!vkEnumerateInstanceExtensionProperties;

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

//////////////////////////////////////////////////////////////
import std.range.primitives
     , std.traits;

template create(alias creator) {
    alias Target = PointerTarget!(Parameters!creator[$-1]);
    auto create(A...)(A a) out(result) {
        assert(result);
    } do {
        VulkanHandle!Target target;
        target.status = creator(a, &target.handle);
        writeln("Create `", Target.stringof, "`: ", target.status);
        return target;
    }
}

template enumerate(alias enumerator) {
    static assert( isCallable!enumerator, "Enumerator is not callable!");
    static assert( Parameters!enumerator.length >= 2, "Enumerator should match patern: `enumarator(..., uint* count, Enumerable*)`!");
    alias Enumerable = PointerTarget!(Parameters!enumerator[$-1]);

    auto enumerate(A...)(A a) {
        uint count;
        enumerator( a, &count, null );
        auto list = new Enumerable[count];
        return !count ? list : () {
            enumerator( a, &count, list.ptr );
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