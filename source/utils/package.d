module utils;
import std.range
     , std.algorithm.iteration
     , std.functional
     , std.traits
     , std.conv
     , std.string
     , std.array;
import derelict.vulkan;
public import utils.functional;


//////////////////////////////////////////////////////////////

template ResultStatusStorage(alias func) {
    alias Type = Unqual!(ReturnType!func);
    static Type value = Type.init;
}

template acquire(alias creator) {
    import std.stdio;
    static assert( isCallable!creator, "Creator is not callable!" );
    static assert( Parameters!creator.length >= 1
                 , "Creator should match patern: `creator(..., Target*)`!" );
    alias Target   = PointerTarget!(Parameters!creator[$-1]);
    enum  isReturn = !is( ReturnType!creator == void );

    auto acquire(Args...)(Args args)
    if(__traits(compiles, creator(args, null)))
    {
        Target target;
        static if(isReturn) {
            auto result = creator(args, &target);
            ResultStatusStorage!creator.value = result;
            return result.to!bool
                 ? target.just
                 : nothing!Target;
        } else {
            creator(args, &target);
            return target;
        }
    }

    T to(T: bool, A)(A a) pure nothrow {
        enum isVkResult = is(A : VkResult);
        static if( isVkResult ) {
            return VkResult.VK_SUCCESS == a;
        } else return a;
    }
}

template enumerate(alias enumerator) {
    static assert( isCallable!enumerator, "Enumerator is not callable!");
    static assert( Parameters!enumerator.length >= 2
                 , "Enumerator should match patern: `enumarator(..., uint* count, Enumerable*)`!");
    alias Enumerable = PointerTarget!(Parameters!enumerator[$-1]);
    alias Target     = Enumerable[];
    auto enumerate(Args...)(Args args)
    if(__traits(compiles, enumerator(args, null, null)))
    {
        uint count;
        enumerator( args, &count, null );
        if(!count) return nothing!Target;
        auto list = new Enumerable[count];
        enumerator( args, &count, list.ptr );
        return list.just;
    }
}