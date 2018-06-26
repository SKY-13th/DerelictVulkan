module vulkan.utils.functional;

import std.range
     , std.algorithm
     , std.functional
     , std.traits
     , std.string
     , std.array;
import derelict.vulkan;

pure nothrow {
    private mixin template MaybeBase(T) {
        alias   Payload = T;
        alias   payload this;
        Payload payload;
    }

    struct Maybe(T) {
        mixin MaybeBase!T;

        static if(!isRange) {
            bool opCast(A : bool)() inout { return _value; }
            private this(T p) {
                payload = p;
                _value  = true;
            }
            private bool _value = false;
        } else {
            // Hack for FilterResult
            // FilterResult has no `const`/`inout` implementaion of `empty` parameter
            // So to answer is it empty it shoud execut deferred filtration process
            static if(isConstAble) { 
                bool opCast(A : bool)() const { return !payload.empty; }
            } else {
                bool opCast(A : bool)() { return !payload.empty; }
            }
        }

        private {
            enum isRange     = isInputRange!(Unqual!T);
            enum isConstAble = isRange && __traits(compiles, ConstOf!T.init.empty);
        }
    }

    struct Maybe(T : bool)  { mixin MaybeBase!T; }
    struct Maybe(P : T*, T) { mixin MaybeBase!P; }


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
    return maybe ? F(maybe.payload, args).just : nothing!Result;
}

alias fallback    = (maybe, backup) => maybe ? maybe.payload : backup;
alias intersect   = (left , right)  => left.filter!(a => right.canFind(a)).array;
alias toCStrArray = data => data.map!(a => toStringz(a)).array;
alias toStrArray  = data => data.map!(a => fromStringz(a.ptr).idup).array;