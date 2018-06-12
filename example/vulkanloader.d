module vulkanloader;
public import derelict.vulkan;

import std.algorithm.iteration
     , std.string
     , std.conv
     , std.stdio
     , std.array
     , std.meta;
import std.functional : memoize;
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


template enumerate(alias enumerator) {
    auto get(ListType)() {
        uint count;
        enumerator( &count, null );
        auto availableLayers = new ListType[count];
        return !count ? availableLayers : () {
            enumerator( &count, availableLayers.ptr );
            return availableLayers;
        } ();
    }
}

auto availableValidationLayersList() {
    alias validationLayers = 
        enumerate!vkEnumerateInstanceLayerProperties
        .get!VkLayerProperties;
    return memoize!validationLayers;
}

auto availableInstanceExtentionsList(in string layerName = "") {
    const auto
        name = layerName.length
             ? toStringz(layerName) 
             : null;
    alias extentions = (count, data) =>
        vkEnumerateInstanceExtensionProperties(name, count, data);
    alias extentionsList =
        enumerate!extentions
        .get!VkExtensionProperties;
    return memoize!extentionsList;
}

auto physicalDevices(VkInstance instance) {

}

//////////////////////////////////////////////////////////////
import std.range.primitives
     , std.traits;

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