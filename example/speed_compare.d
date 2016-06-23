#!/usr/bin/env dub
/+ dub.sdl:
    name "speed_compare"
    dependency "dcl" path=".."
 +/
// RUN: dub speed_compare.d
import std.random;

import std.stdio;
import std.datetime;
import std.typecons;
import std.algorithm;
import std.string;

import dcl;
import dcl.helpers;

enum string KERNEL_SOURCES = q{
#define GGI(a) get_global_id(a)
#define GGS(a) get_global_size(a)

kernel void sum( const global float2* a,
                 const global float2* b,
                 global float2* c,
                 const uint size )
{
    for( int i = GGI(0); i < size; i += GGS(0) )
        c[i] = a[i] + b[i];
}
};

struct vec2
{
    float[2] data;
    this( float x, float y ) { data[0] = x; data[1] = y; }

    vec2 opBinary(string op)( ref const(vec2) rhs ) const
    {
        mixin( format( `return vec2( data[0] %1$s rhs.data[0],
                                     data[1] %1$s rhs.data[1] );`, op ) );
    }
}

void main()
{
    auto count = 8 * 1024 * 1024;

    writeln( "perform: c[] = a[] + b[]" );
    auto size = count * vec2.sizeof;
    writeln( "buffers size: ", size, " bytes (", size / (1024 * 1024.0f), "MiB)" );
    writeln();

    auto a_data = new vec2[]( count );
    auto b_data = new vec2[]( count );
    auto c_data = new vec2[]( count );

    // fill source data
    foreach( i; 0 .. count )
    {
        a_data[i] = vec2( i, i*2 );
        b_data[i] = vec2( i, i*i );
    }

    testOCL( a_data, b_data, c_data, 1 );

    testCPU( a_data, b_data, c_data, iota(count) );

    import std.parallelism;
    testCPU( a_data, b_data, c_data,
             parallel(iota(count)),
             "with std.parallelism" );
}

void testCPU(R)( vec2[] a, vec2[] b, vec2[] c, R rng, string msg="" )
{
    StopWatch sw;
    sw.start();

    foreach( i; rng ) c[i] = a[i] + b[i];

    sw.stop();
    writeln( "platform: CPU " ~ msg );
    writeln( "  time: ", sw.peek().hnsecs * 1e-7, " sec" );
    writeln();
}

void testOCL( vec2[] a, vec2[] b, vec2[] c, int info_level=0 )
{
    loadCL();

    auto platforms = CLPlatform.getAll();

    foreach( pl; platforms )
    {
        printInfo( pl, info_level );

        // copy memory to device test
        auto tm = copyTestPlatform( pl, a, b, c );
        writeln( "copy memory" );
        writeln( "kernel: ", tm[0] , " sec" );
        writeln( "  full: ", tm[1] , " sec" );

        // use host memory test
        tm = hostTestPlatform( pl, a, b, c );
        writeln( "host memory" );
        writeln( "kernel: ", tm[0] , " sec" );
        writeln( "  full: ", tm[1] , " sec" );

        writeln();
    }
}

void printInfo( CLPlatform pl, int info_level )
{
    if( info_level == 0 ) return;
    else if( info_level == 1 )
        writeln( "platform: ", getCLPlatformFullInfo(pl).assocArray["platform"] );
    else writeln( getCLPlatformFullInfoString( pl, "% 9s : %s" ) ~ "\n" );

    foreach( i, dev; pl.devices )
    {
        if( info_level == 1 )
        {
            auto tn = getCLDeviceFullInfo(dev)[0][1];
            writefln( "device #%d: %s", i, tn );
        }
        else
        {
            writeln( "device #", i );
            writeln( getCLDeviceFullInfoString(dev) ~ "\n" );
        }
    }
}

auto testPlatform( CLPlatform platform, uint length,
    void delegate( CLContext, ref CLMemory, ref CLMemory, ref CLMemory ) createMem,
    void delegate( CLCommandQueue cq, CLMemory, CLMemory, CLMemory ) prepareMem,
    void delegate( CLCommandQueue cq, CLMemory, CLMemory, CLMemory ) finishMem )
{
    // create context for all platform devices
    auto ctx = new CLContext( platform );

    // create command queue for first device in list
    // with profiling for measuring execution time
    auto cq = ctx.newChild!CLCommandQueue( ctx, ctx.devices[0],
            [CLCommandQueue.Properties.PROFILING] );

    // create and build program in context for all devices in context
    auto prog = ctx.buildProgram( KERNEL_SOURCES );

    // aux object
    auto sum = new CLKernelCaller( prog["sum"], cq );

    // work group size
    sum.setWorkGroupSize( 1024 );

    CLMemory a, b, c;
    // create buffers, flags describe access from kernel
    createMem( ctx, a, b, c );

    StopWatch sw; sw.start();

    prepareMem( cq, a, b, c );

    sum.setArgs( a, b, c, length );
    sum.range(); // clEnqueueNDRangeKernel : run kernels

    finishMem( cq, a, b, c );

    sw.stop();

    ctx.destroy();

    return tuple( ( sum.exec_inst.end - sum.exec_inst.queued ) * 1e-9,
                   sw.peek().hnsecs * 1e-7 );
}

auto copyTestPlatform( CLPlatform platform, vec2[] a, vec2[] b, vec2[] c )
{
    auto size = a.length * vec2.sizeof;

    return testPlatform( platform, cast(uint)(a.length),
    ( CLContext ctx, ref CLMemory amem, ref CLMemory bmem, ref CLMemory cmem ){
        amem = CLMemory.createBuffer( ctx, [ CLMemory.Flag.READ_ONLY ], size );
        bmem = CLMemory.createBuffer( ctx, [ CLMemory.Flag.READ_ONLY ], size );
        cmem = CLMemory.createBuffer( ctx, [ CLMemory.Flag.WRITE_ONLY ], size );
    },
    ( CLCommandQueue cq, CLMemory amem, CLMemory bmem, CLMemory cmem )
    {
        amem.write( cq, a );
        bmem.write( cq, b );
    },
    ( CLCommandQueue cq, CLMemory amem, CLMemory bmem, CLMemory cmem )
    {
        cmem.readTo( cq, c );
    }
    );
}

auto hostTestPlatform( CLPlatform platform, vec2[] a, vec2[] b, vec2[] c )
{
    auto size = a.length * vec2.sizeof;
    CLMemory.MemoryMap amap, bmap, cmap;

    return testPlatform( platform, cast(uint)(a.length),
    ( CLContext ctx, ref CLMemory amem, ref CLMemory bmem, ref CLMemory cmem ){
        enum RW = CLMemory.Flag.READ_WRITE;
        enum UHPTR = CLMemory.Flag.USE_HOST_PTR;
        amem = CLMemory.createBuffer( ctx, [ RW, UHPTR ], size, a.ptr );
        bmem = CLMemory.createBuffer( ctx, [ RW, UHPTR ], size, b.ptr );
        cmem = CLMemory.createBuffer( ctx, [ RW, UHPTR ], size, c.ptr );
    },
    ( CLCommandQueue cq, CLMemory amem, CLMemory bmem, CLMemory cmem )
    {
        if( !amap.valid ) return;
        amap.unmap();
        bmap.unmap();
        cmap.unmap();
    },
    ( CLCommandQueue cq, CLMemory amem, CLMemory bmem, CLMemory cmem )
    {
        amap = amem.mapBuffer( cq );
        bmap = bmem.mapBuffer( cq );
        cmap = cmem.mapBuffer( cq );
    }
    );
}
