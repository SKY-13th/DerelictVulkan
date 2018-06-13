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
}

alias VulkanInstance      = VulkanHandle!VkInstance;
alias VulkanLogicalDevice = VulkanHandle!VkDevice;
alias VulkanSurface       = VulkanHandle!VkSurfaceKHR;

alias physicalDevices           = enumerate!vkEnumeratePhysicalDevices;
alias queueFamilyProperties     = enumerate!vkGetPhysicalDeviceQueueFamilyProperties;
alias availableValidationLayers = enumerate!vkEnumerateInstanceLayerProperties;
auto  availableInstanceExtentions(in string layerName = "") {
    return layerName.toStringz.enumerate!vkEnumerateInstanceExtensionProperties;
}

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

    VulkanInstance handle;
    VkInstanceCreateInfo instanceInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pApplicationInfo:        &appInfo,
        enabledLayerCount:       layersList.length.to!uint,
        ppEnabledLayerNames:     layersList.toCStrArray.ptr,
        enabledExtensionCount:   extentionsList.length.to!uint,
        ppEnabledExtensionNames: extentionsList.toCStrArray.ptr
    };
    
    handle.status = vkCreateInstance(&instanceInfo, null, &handle.handle);
    return handle;
}

auto createDevice(VkPhysicalDevice physicalDevice) {
    auto queuePriorities = [1.0f];
    VkDeviceQueueCreateInfo deviceQueueInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        queueFamilyIndex: 0,
        queueCount:       1,
        pQueuePriorities: queuePriorities.ptr
    };
    VkDeviceCreateInfo deviceInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        queueCreateInfoCount: 1,
        pQueueCreateInfos:    &deviceQueueInfo
    };
    VulkanLogicalDevice handle;
    handle.status = vkCreateDevice(physicalDevice, &deviceInfo, null, &handle.handle);
    return handle;
}

auto createSurface(VulkanInstance instance, SDL2WMInfo info) in {
    assert(VkResult.VK_SUCCESS == instance.status);
    assert(info.isValid);
} out (result) {
    assert(VkResult.VK_SUCCESS == result.status);
} do {
    VkWin32SurfaceCreateInfoKHR surfaceCreateInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        hwnd:      info.info.win.window,
        hinstance: info.info.win.hinstance
    };
    VulkanSurface handle;
    handle.status = vkCreateWin32SurfaceKHR(instance, &surfaceCreateInfo, null, &handle.handle);
    return handle;
}

//////////////////////////////////////////////////////////////
import std.range.primitives
     , std.traits;

template enumerate(alias enumerator) {
    import std.traits;
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