module vulkan.utils;
import std.range
     , std.algorithm.iteration
     , std.functional
     , std.traits
     , std.conv
     , std.string
     , std.array;
import derelict.vulkan;
public import vulkan.utils.functional;

static VkResult vulkanResult;

template acquire(alias creator) {
    static assert( isCallable!creator, "Creator is not callable!" );
    static assert( Parameters!creator.length >= 1
                 , "Creator should match patern: `creator(..., Target*)`!" );
    alias Target   = PointerTarget!(Parameters!creator[$-1]);

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

bool isValid(VkResult value) {
    return value >= 0;
}

private auto commit(alias func, Args...)(Args args) {
    alias ReturnT  = typeof(func(args));
    enum  isReturn = is( ReturnT == VkResult );
    static if(isReturn) {
        vulkanResult = func(args);
    } else {
        vulkanResult = VkResult.VK_SUCCESS;
        func(args);
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