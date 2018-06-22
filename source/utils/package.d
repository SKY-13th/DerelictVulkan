module utils;
import std.range
     , std.algorithm.iteration
     , std.functional
     , std.traits
     , std.conv
     , std.string
     , std.array;
import derelict.vulkan;

pure nothrow {

    struct Maybe(T) {
        this(T p) {
            payload = p;
            static if(!isOdd) {
                _value = true;
            }
        }
        alias payload this;
        T     payload;
        ref A opCast(A : T)() inout {
            return payload;
        }

        private {
            enum bool isRange    = isInputRange!(Unqual!T);
            enum bool isPtr      = isPointer!(Unqual!T);
            enum bool isVkResult = is(T : VkResult);
            enum bool isOdd      = isRange || isPtr || isVkResult;
        }

        static if (isRange) {
            private enum bool isConstAble = __traits(compiles, ConstOf!T.init.empty);
            static if(isConstAble) {
                bool opCast(A : bool)() inout { return !payload.empty; }
            } else {
                bool opCast(A : bool)() { return !payload.empty; }
            }
        } 
        static if (isPtr) {
            bool opCast(A : bool)() inout { return cast(bool)payload; }
        }
        static if (isVkResult) {
            bool opCast(A : bool)() inout { return payload == VkResult.VK_SUCCESS; }
        }
        static if (!isOdd) {
            bool opCast(A : bool)() inout { return _value; }
            private bool _value = false;
        }
    }

    auto just(T)(T t) {
        return Maybe!T(t);
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

    template nothing(alias example) if(!isType!example){
        enum nothing = nothing!(typeof(example));
    }

    template nothing(Type) {
        enum nothing = select!(isMaybe!Type)(Type.init, Maybe!Type.init);
    }
}

auto demand(alias F, string info = "", A: Maybe!T, T)(A a) if(__traits(compiles, F(a))) {
    import std.exception;
    debug { assert (a && F(a), info); }
    else  { enforce(a && F(a), info); }
    return a;
}

auto demand(alias F, string info = "", T)(T a) if(__traits(compiles, F(a))) {
    import std.exception;
    debug { assert (F(a), info); }
    else  { enforce(F(a), info); }
    return a;
}

auto demand(string info = "", T)(T a)
    if(is(T:bool) || isMaybe!T) {
    import std.exception;
    debug { assert (a, info); }
    else  { enforce(a, info); }
    return a;
}

auto expect(alias F, string info = "", A: Maybe!T, T)(A a) 
    if(__traits(compiles, F(a))) {
    import std.stdio;
    if (!(a && F(a))) {
        stderr.writeln(info);
    }
    return a;
}

auto expect(alias F, string info = "", T)(T a) 
    if(__traits(compiles, F(a))) {
    import std.stdio;
    if (!F(a)) {
        stderr.writeln(info);
    }
    return a;
}

auto expect(string info = "", T)(T a)
    if(is(T:bool) || isMaybe!T) {
    import std.stdio;
    if (!a) {
        stderr.writeln(info);
    }
    return a;
}

auto bind(alias F, T, Args...)(auto ref Maybe!T maybe, Args args) {
    alias Result = typeof(F(maybe.payload, args));
    static if( is(Result == bool) ) {
        return maybe ? F(maybe.payload, args) : false;
    } else {
        return maybe ? F(maybe.payload, args).just : nothing!Result;
    }
}

auto fallback(T)(auto ref Maybe!T maybe, auto ref T fBack) {
    return maybe ? maybe.payload : fBack;
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
            // writeln( "Create `"   , Target.stringof
            //        , "`| result: ", result );
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