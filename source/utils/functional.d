module utils.functional;

import std.range
     , std.algorithm.iteration
     , std.functional
     , std.traits
     , std.string
     , std.array;
import derelict.vulkan;

pure nothrow {

    struct Maybe(T) {
        alias   Payload = T;
        alias   payload this;
        Payload payload;

        this(T p) {
            payload = p;
            static if(!isOdd) {
                _value = true;
            }
        }
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

    auto  just(T)(T t) { return Maybe!T(t); }
    alias just(M: Maybe!T, T) = m => m;

    enum nothing(Type) = select!(isMaybe!Type)( Type.init, Maybe!Type.init);
    enum isMaybe(Type) = false;
    enum isMaybe(M: Maybe!T, T) = true;
}

auto demand(alias F, string info = "", A: Maybe!T, T)(A a)
if(__traits(compiles, F(a))) {
    import std.exception;
    debug { assert (a && F(a), info); }
    else  { enforce(a && F(a), info); }
    return a;
}

auto demand(alias F, string info = "", T)(T a)
if(__traits(compiles, F(a))) {
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
    if (!a) {
        import std.stdio;
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

auto intersect(Range)( in Range left, in Range right ) pure
if (isInputRange!(Unqual!Range)) {
    import std.algorithm.searching : canFind;
    return left.filter!(a => right.canFind(a)).array;
}

auto toCStrArray(Range)(Range data) pure
if (isInputRange!(Unqual!Range)) {
    return data.map!(a => toStringz(a)).array;
}

auto toStrArray(Range)(Range data) pure
if (isInputRange!(Unqual!Range)) {
    return data.map!(a => fromStringz(a.ptr).idup).array;
}