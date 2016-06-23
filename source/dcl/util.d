module dcl.util;

import std.string;
import std.range;
import std.exception;
import std.algorithm;

version(unittest)
{
    import std.stdio;
    import dcl.error;
}

package:

/// generate propertyes for subject
string infoMixin( string subject, string enumname, in string[] list, string[] ids=null )
{
    string[] ret;

    foreach( ln; list )
    {
        auto tpl = splitInfoLine( ln );

        ret ~= fformat(
        q{%D_TYPE% %PROP_NAME%() @property {

            if( %IDSISNULL% )
                throw new CLException( "id is null" );

            import std.traits;
            import std.algorithm;
            import std.array;
            import std.conv;

            alias T=%CL_TYPE%;
            alias R=%D_TYPE%;

            // TODO: it's for strings
            static if( isDynamicArray!T )
            {
                size_t len;
                checkCall!clGet%CC_SUBJ%Info( %IDS%, %CL_PARAM_NAME%, 0, null, &len );
                alias ueT = Unqual!(ElementEncodingType!T);
                auto buf = new ueT[]( len );
                if( len == 0 ) return null;
                checkCall!clGet%CC_SUBJ%Info( %IDS%,
                        %CL_PARAM_NAME%, len * ueT.sizeof, buf.ptr, &len );

                return to!R(buf[0 .. len/ueT.sizeof - cast(size_t)isSomeString!T ]);
            }
            else
            {
                T val;

                checkCall!clGet%CC_SUBJ%Info( %IDS%,
                        %CL_PARAM_NAME%, typeof(val).sizeof, &val, null );

                static if( is( R == class ) ) return R.getFromID( val );
                else static if( is( R == enum ) ) return cast(R)val;
                else return to!R(val);
            }
        }},

        [
            "CC_SUBJ": toCamelCase( subject ),
            "CL_TYPE": tpl.cl_type,
            "D_TYPE": tpl.d_type,
            "CL_PARAM_NAME": paramEnumName( "CL" ~ "_" ~ enumname.toUpper, tpl.cl_param_name ),
            "PROP_NAME": tpl.prop_name,
            "IDS": ids is null ? "id" : ids.map!(a=>a ~ ".id").array.join(", "),
            "IDSISNULL": ids is null ? "id is null" : ids.map!(a=>a ~ ".id is null").array.join(" || ")
        ]
        );
    }

    return ret.join("\n");
}

/// ditto
string infoMixin( string subject, in string[] list )
{
    return infoMixin( subject, subject, list );
}

unittest
{
    import std.stdio;
    auto info_list =
    [
        "cl_command_type:Command command_type:command",
        "cl_int:Status command_execution_status:status",
        "uint reference_count:ref_count",
        "uint max_block"
    ];
    //writeln( infoMixin( "event", info_list ) );
}

/++ split info line
    +
    + Rules:
    + ---
    +      property:
    +          type name
    +
    +      type:
    +          d_type
    +          cl_type:d_type
    +
    +      name:
    +          prop_name
    +          cl_param_name:prop_name
    + ---
    +/
auto splitInfoLine( string ln )
{
    static struct Result { string d_type, cl_type, prop_name, cl_param_name; }

    auto splt = ln.strip.split(" ");
    enforce( splt.length == 2,
            format( "bad info format '%s', need one space between type and name", ln.strip ) );

    auto types = splt[0].split(":").cycle;

    Result ret;

    ret.d_type = types[1];
    ret.cl_type = types[0];

    auto names = splt[1].split(":").cycle;

    ret.prop_name = names[1];
    ret.cl_param_name = names[0];

    return ret;
}

///
unittest
{
    auto r = splitInfoLine( "uint param" );
    assertEq( r.d_type, "uint" );
    assertEq( r.cl_type, "uint" );
    assertEq( r.prop_name, "param" );
    assertEq( r.cl_param_name, "param" );
}

///
unittest
{
    auto r = splitInfoLine( "cl_uint:MyEnum param" );
    assertEq( r.d_type, "MyEnum" );
    assertEq( r.cl_type, "cl_uint" );
    assertEq( r.prop_name, "param" );
    assertEq( r.cl_param_name, "param" );
}

///
unittest
{
    auto r = splitInfoLine( "uint param:prop" );
    assertEq( r.d_type, "uint" );
    assertEq( r.cl_type, "uint" );
    assertEq( r.prop_name, "prop" );
    assertEq( r.cl_param_name, "param" );
}

///
unittest
{
    auto r = splitInfoLine( "cl_uint:MyEnum param:prop" );
    assertEq( r.d_type, "MyEnum" );
    assertEq( r.cl_type, "cl_uint" );
    assertEq( r.prop_name, "prop" );
    assertEq( r.cl_param_name, "param" );
}

string paramEnumName( string prefix, string name )
{
    if( name.startsWith("!") ) return "CL_" ~ name[1..$].toUpper;
    return prefix ~ "_" ~ name.toUpper;
}

unittest
{
    assertEq( paramEnumName( "CL_PLATFORM", "name" ), "CL_PLATFORM_NAME" );
    assertEq( paramEnumName( "CL_PLATFORM", "nAmE" ), "CL_PLATFORM_NAME" );
    assertEq( paramEnumName( "CL_DEVICE", "max_work_item_dimensions" ),
                              "CL_DEVICE_MAX_WORK_ITEM_DIMENSIONS" );
    assertEq( paramEnumName( "CL_DEVICE", "!driver_version" ), "CL_DRIVER_VERSION" );
}

string fformat( string input, string[string] dict )
{
    //string rplc( Captures!string m )
    //{ return dict[ m.hit[1..$-1] ]; }
    //return replaceAll!(rplc)( input, ctRegex!( r"%\w*%" ) );

    string rplc( string m )
    {
        //import std.stdio;
        //stderr.writeln( m );
        return dict[m[1..$-1]];
    }
    return replaceWords!(rplc)( input );
}


unittest
{
    auto input =
        q{ hello %NAME%
           i have %SUBJ% for you };

    auto expect =
        q{ hello Ivan
           i have question for you };

    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );

    assertEq( result, expect );
}

unittest
{
    auto input = q{ hello %NAME% i have %SUBJ% for you};
    auto expect = q{ hello Ivan i have question for you};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{ hello %NAME% i have %SUBJ% for you %s};
    auto expect = q{ hello Ivan i have question for you %s};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{ hello %NAME% i have %SUBJ% for you %s };
    auto expect = q{ hello Ivan i have question for you %s };
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{%NAME% i have %SUBJ% for you};
    auto expect = q{Ivan i have question for you};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{%NAME% i %% have %SUBJ% for you};
    auto expect = q{Ivan i %% have question for you};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{%%%NAME% i have %SUBJ% for you};
    auto expect = q{%%Ivan i have question for you};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{%NAME% i have %SUBJ% for you%%};
    auto expect = q{Ivan i have question for you%%};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{%NAME% i have%%%};
    auto expect = q{Ivan i have%%%};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

unittest
{
    auto input = q{%NAME %i have %SUBJ%%};
    auto expect = q{%NAME %i have question%};
    auto result = fformat( input, [ "NAME": "Ivan", "SUBJ": "question" ] );
    assertEq( result, expect );
}

///
string toSnakeCase( in string str, bool ignore_first=true ) @property pure @trusted
{
    string[] buf;
    buf ~= "";
    foreach( i, ch; str )
    {
        if( [ch].toUpper == [ch] ) buf ~= "";
        buf[$-1] ~= [ch].toLower;
    }
    if( buf[0].length == 0 && ignore_first )
        buf = buf[1..$];
    return buf.join("_");
}

///
unittest
{
    assertEq( "SomeVar".toSnakeCase, "some_var" );
    assertEq( "SomeVar".toSnakeCase(false), "_some_var" );

    assertEq( "someVar".toSnakeCase, "some_var" );
    assertEq( "someVar".toSnakeCase(false), "some_var" );

    assertEq( "ARB".toSnakeCase, "a_r_b" );
    assertEq( "ARB".toSnakeCase(false), "_a_r_b" );

    // not alphabetic chars in upper case looks like lower, func separate by them
    assertEq( "A.B.r.A".toSnakeCase, "a_._b_.r_._a" );
    assertEq( "A_B_r_A".toSnakeCase, "a___b__r___a" );
}

///
string toCamelCaseBySep( in string str, string sep="_", bool first_capitalize=true ) pure @trusted
{
    auto arr = str.split(sep).filter!(a=>a.length>0).array;
    string[] ret;
    foreach( i, v; arr )
    {
        auto bb = v.capitalize;
        if( i == 0 && !first_capitalize )
            bb = v.toLower;
        ret ~= bb;
    }
    return ret.join("");
}

///
unittest
{
    assertEq( toCamelCaseBySep( "single-precision-constant", "-", false ), "singlePrecisionConstant" );
    assertEq( toCamelCaseBySep( "one.two.three", ".", true ), "OneTwoThree" );
    assertEq( toCamelCaseBySep( "one..three", ".", true ), "OneThree" );
    assertEq( toCamelCaseBySep( "one/three", "/" ), "OneThree" );
    assertEq( toCamelCaseBySep( "one_.three", ".", false ), "one_Three" );

    // `_` in upper case looks equals as lower case
    assertEq( toCamelCaseBySep( "one._three", ".", true ), "One_three" );
}

///
string toCamelCase( in string str, bool first_capitalize=true ) @property pure @trusted
{ return toCamelCaseBySep( str, "_", first_capitalize ); }

///
unittest
{
    assertEq( "some_class".toCamelCase, "SomeClass" );
    assertEq( "_some_class".toCamelCase, "SomeClass" );
    assertEq( "some_func".toCamelCase(false), "someFunc" );
    assertEq( "_some_func".toCamelCase(false), "someFunc" );
    assertEq( "a_r_b".toCamelCase, "ARB" );
    assertEq( toCamelCase( "program_build" ), "ProgramBuild" );
    assertEq( toCamelCase( "program__build" ), "ProgramBuild" );

    assertEq( toCamelCase( "program__build", false ), toCamelCaseBySep( "program__build", "_", false ) );
}

private:

string replaceWords(alias fun)( string s )
{
    string ret;
    size_t p0 = 0, p1 = 0;

    void inc() { p1++; }
    void dump() { ret ~= s[min(p0,$)..min(p1,$)]; p0 = p1; }
    void dumpfun() { ret ~= fun( s[p0..p1] ); p0 = p1; }

    m:while( p1 < s.length )
    {
        if( s[p1] == '%' )
        {
            dump; inc;
            while( p1 < s.length )
            {
                if( s[p1] == '%' )
                {
                    inc;
                    if( p1-2 == p0 ) // if no symbol between %%
                        continue m;
                    else
                        dumpfun;
                    break;
                }
                else if( !identitySymbol(s[p1]) ) { inc; break; }
                inc;
            }
        }
        inc;
        if( p1 >= s.length ) dump();
    }
    if( p0 != p1 ) ret ~= s[p0..$]; // in case endWith("%%")
    return ret;
}

bool identitySymbol( char c )
{
    switch(c)
    {
        case 'a': .. case 'z': case 'A': .. case 'Z':
        case '_': case '0': .. case '9': return true;
        default: return false;
    }
}
