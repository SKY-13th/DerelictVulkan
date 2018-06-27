module vulkan.utils.base;

import std.range
     , std.algorithm
     , std.functional
     , std.traits
     , std.conv
     , std.string
     , std.array
     , derelict.vulkan
     , vulkan.utils;

// Store result of call to `acquire`,`request` and `enumerate` functions
// Compleatly thread save due to nature of static variables in `D`
// https://dlang.org/spec/attribute.html#static paragraph 3
static VkResult vulkanResult;

bool isValid(VkResult value) {
    return value >= 0;
}

alias isSurfaceSupported = (device, surface, queueFlag) =>
    device.surfaceFormats(surface)
        .bind!( _ => device.surfacePresentations(surface) )
        .bind!((_) {
            auto properties = device.queueFamilyProperties;
            auto index      = properties.queueFamilyIndex(queueFlag);
            return index < properties.length
                && device.surfaceSupport(index, surface);
        });

alias hasNoPreferedFormat = formats => formats.length == 1
    && formats.front.format == VkFormat.VK_FORMAT_UNDEFINED;

alias hasSurfaceFormatSupport = (formats, desiredFormat) =>
    formats.hasNoPreferedFormat || formats.canFind(desiredFormat)
    ? desiredFormat : formats.front;

alias queueFamilyIndex = (ques,queBit) => 
    cast(uint)ques.countUntil!(q => q.queueCount > 0 && q.queueFlags & queBit);

template acquire(alias creator) {
    static assert( isCallable!creator, "Creator is not callable!" );
    static assert( Parameters!creator.length >= 1
                 , "Creator should match patern: `creator(..., Target*)`!" );
    
    alias Target = PointerTarget!(Parameters!creator[$-1]);

    auto acquire(Args...)(Args args)
    if(__traits(compiles, creator(args, null))) {
        Target target = void;
        return target.request!creator(args);
    }
}

template request(alias creator) {
    auto request(T, Args...)(ref T target, Args args)
    if(__traits(compiles, creator(args, null))) {
        alias getPtr = Select!( isArray!T, t => t.ptr, (ref t) => &t );
        commit!creator(args, getPtr(target));
        return vulkanResult.isValid
             ? target.just
             : nothing!T;
    }
}

template enumerate(alias enumerator) {
    static assert( isCallable!enumerator, "Enumerator is not callable!");
    static assert( Parameters!enumerator.length >= 2
                 , "Enumerator should match patern: `enumarator(..., uint* count, Enumerable*)`!");
    alias Enumerable = PointerTarget!(Parameters!enumerator[$-1]);
    alias Target     = Enumerable[];

    auto enumerate(Args...)(Args args)
    if(__traits(compiles, enumerator(args, null, null))) {
        uint count;
        commit!enumerator( args, &count, null );
        if(!vulkanResult.isValid || count == 0) {
            return nothing!Target;
        }
        auto list = new Enumerable[count];
        commit!enumerator( args, &count, list.ptr );
        return vulkanResult.isValid
             ? list.just
             : nothing!Target;
    }
}

auto commit(alias func, Args...)(Args args) {
    alias ReturnT  = typeof(func(args));
    enum  isReturn = is( ReturnT == VkResult );
    static if(isReturn) {
        vulkanResult = func(args);
    } else {
        vulkanResult = VkResult.VK_SUCCESS;
        func(args);
    }
    return vulkanResult;
}