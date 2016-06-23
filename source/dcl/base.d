/++ base classes, functions, public imports,

    `loadCL` load DerelictCL with version 1.2
 +/
module dcl.base;

public import derelict.opencl.cl;
public import dcl.error;

package
{
    import std.string;
    import std.traits;
    import std.range;
    import std.algorithm;
    import std.array;
    import std.exception;

    import dcl.util;
    import dcl.event;
}

///
extern(C)
void loadCL()
{
    if( !DerelictCL.isLoaded ) DerelictCL.load();
    DerelictCL.reload( CLVersion.CL12 );
}

import std.meta;
class CLObject
{
    protected
    {
        CLObject parent;
        Object[] child;
    }

    auto regChild(T)( T[] arr )
    {
        foreach( obj; arr ) regChild( obj );
        return arr;
    }

    auto regChild(T)( T obj ) if( !isArray!T )
    {
        static if( is( T : CLObject ) )
            enforce( noLoop( obj ), "has loop" );
        child ~= obj;
        return obj;
    }

    auto newChild(T,Args...)( Args args )
    { return regChild( new T(args) ); }

    void preChildDestory(){}
    void selfDestroy(){}

    ~this()
    {
        preChildDestory();
        foreach( ch; child )
            ch.destroy();
        selfDestroy();
    }

private:

    bool noLoop( CLObject[] arr... )
    {
        foreach( obj; arr )
            if( obj is this || !noLoop(obj.child.map!(a=>cast(CLObject)a).filter!(a=>a !is null).array) )
                return false;
        return true;
    }
}

unittest
{
    import std.exception;

    auto a = new CLObject;
    auto b = a.newChild!CLObject;
    auto c = a.newChild!CLObject;
    b.regChild(c);

    assertThrown( b.regChild(a) );
    assertThrown( b.regChild([c,a]) );

    a.destroy();
    b.destroy();
    c.destroy();
}

package
{
    ///
    auto getIDsPtr(T)( T[] list... ) pure { return map!(a=>a.id)(list).array.ptr; }

    ///
    auto buildFlags(T=uint)( T[] list... ) pure { return reduce!((a,b)=>a|=b)(T(0),list); }

    unittest
    {
        assert( buildFlags( 0b01, 0b10 ) == 0b11 );
        assert( buildFlags() == 0 );
    }

    ///
    auto parseFlags(T)( ulong mask, T[] without=[] )
    {
        T[] ret;
        foreach( v; [EnumMembers!T] )
        {
            if( without.canFind(v) ) continue;
            if( mask & cast(ulong)v )
                ret ~= v;
        }
        return ret;
    }

    unittest
    {
        enum TT
        {
            ONE = 1<<0,
            TWO = 1<<1,
            THR = 1<<2,
            FOU = 1<<3
        }

        auto mask = buildFlags( TT.ONE, TT.THR );
        auto tt = parseFlags!TT( mask );
        assert( tt == [ TT.ONE, TT.THR ] );
    }

    /// check error code and throw exception if it not `CL_SUCCESS`
    void checkError( int code, lazy string fnc, lazy string[2][] args,
                     lazy string file=__FILE__, lazy size_t line=__LINE__ )
    {
        auto err = cast(CLError)code;
        if( err == CLError.NONE ) return;
        throw new CLCallException( fnc, args, err, file, line );
    }

    /++ check OpenCL `fnc` return value
     +  calls `fnc( args )`
     +/
    void checkCall(alias fnc, string file=__FILE__, size_t line=__LINE__, Args...)( Args args )
    { checkError( fnc( args ), (&fnc).stringof[2..$], argsToStringArray(args), file, line ); }

    /++ check OpenCL `fnc` return value
     +  easy wait_list and event passes
     +  see_also: `checkCall`
     +/
    void checkCallWL(alias fnc, string file=__FILE__, size_t line=__LINE__, Args...)( Args args )
    {
        static assert( is( Args[$-1] : CLEvent* ) );
        static assert( is( Args[$-2] : CLEvent[] ) );
        auto wl = args[$-2];
        auto ev = args[$-1];
        checkCall!(fnc,file,line)( args[0..$-2],
                cast(uint)wl.length, cast(cl_event*)wl.ptr, cast(cl_event*)ev );
    }

    /++ check error code after OpenCL `fnc` call
     + calls `fnc( args, &retcode )`
     + Returns:
     + result of `fnc` call
     +/
    auto checkCode(alias fnc, string file=__FILE__, size_t line=__LINE__, Args...)( Args args )
    {
        int retcode;
        debug
        {
            auto id = fnc( args, &retcode );
            checkError( retcode, (&fnc).stringof[2..$], argsToStringArray(args), file, line );
            return id;
        }
        else
        {
            scope(exit) checkError( retcode, (&fnc).stringof[2..$], argsToStringArray(args), file, line );
            return fnc( args, &retcode );
        }
    }

    /++ check error code after OpenCL `fnc` call
     +  easy wait_list and event passes
     +  see_also: `checkCode`
     +/
    auto checkCodeWL(alias fnc, string file=__FILE__, size_t line=__LINE__, Args...)( Args args )
    {
        static assert( is( Args[$-1] : CLEvent* ) );
        static assert( is( Args[$-2] : CLEvent[] ) );
        auto wl = args[$-2];
        auto ev = args[$-1];
        return checkCode!(fnc,file,line)( args[0..$-2],
                cast(uint)wl.length, cast(cl_event*)wl.ptr, cast(cl_event*)ev );
    }

    string[2][] argsToStringArray(Args...)( Args args )
    {
        static if( Args.length > 1 )
            return argsToStringArray( args[0..$/2] ) ~ argsToStringArray( args[$/2..$] );
        else
        {
            enum tname = Args[0].stringof;
            static if( isIntegral!(Args[0]) )
                return [ [ tname, format( "%1$d (0x%1$x)", args[0] ) ] ];
            else
                return [ [ tname, format( "%s", args[0] ) ] ];
        }
    }
}
