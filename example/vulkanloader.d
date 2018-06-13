module vulkanloader;
public import derelict.vulkan;

import std.algorithm.iteration
     , std.string
     , std.conv
     , std.stdio
     , std.array
     , std.meta;
import derelict.sdl2.sdl;

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

struct VulkanInstanceHandle {
    VkResult   status = VkResult.VK_NOT_READY;
    alias instance this;
    VkInstance instance;
}

VulkanInstanceHandle
    initVulkan( in ref VkApplicationInfo appInfo
              , in string[] extentionsList
              , in string[] layersList )
{
    writeln("Use layers: "    , layersList);
    writeln("Use extentions: ", extentionsList);

    VulkanInstanceHandle handle;
    VkInstanceCreateInfo instanceInfo = {
        sType: VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        pApplicationInfo:        &appInfo,
        enabledLayerCount:       layersList.length.to!uint,
        ppEnabledLayerNames:     layersList.toCStrArray.ptr,
        enabledExtensionCount:   extentionsList.length.to!uint,
        ppEnabledExtensionNames: extentionsList.toCStrArray.ptr
    };
    
    handle.status = vkCreateInstance(&instanceInfo, null, &handle.instance);
    return handle;
}

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