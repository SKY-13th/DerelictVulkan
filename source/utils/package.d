module utils;
import std.range.primitives
     , std.algorithm.iteration
     , std.traits
     , std.conv
     , std.string
     , std.array;
import derelict.vulkan;

@safe @nogc pure nothrow {

    struct Maybe(T) {
        alias payload this;
        T     payload;
        ref A opCast(A : T)() {
            return payload;
        }
        bool opCast(A : bool)() inout {
            return _just;
        }
    private:
        bool  _just;
    }

    auto just(T)(T t) {
        return Maybe!T(t, true);
    }

    auto just(M: Maybe!T, T)(M m) {
        return m;
    }

    template isMaybe(Type) {
        enum isMaybe = false;
    }

    template isMaybe(M: Maybe!T, T) {
        enum isMaybe = true;
    }

    template nothing(alias example) {
        alias Type   = Select!(isType!example, example, typeof(example));
        enum nothing = nothing!Type;
    }

    template nothing(Type) {
        enum nothing = select!(isMaybe!Type)(Type.init, Maybe!Type.init);
    }
}

auto bind(alias F, T, Args...)(auto ref Maybe!T maybe, Args args) {
    alias Result = typeof(F(maybe.payload, args));
    static if( is(Result : bool) ) {
        return maybe ? F(maybe.payload, args) : false;
    } else {
        return maybe ? F(maybe.payload, args) : nothing!Result;
    }
}

//////////////////////////////////////////////////////////////

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
            const auto result = creator(args, &target);
            writeln( "Create `"   , Target.stringof
                   , "`| result: ", result );
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
        } else static if( isPointer!A ) {
            return cast(bool) a;
        } else return true;
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

auto intersect(Range)( in Range left, in Range right ) pure
if (isInputRange!(Unqual!Range))
{
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