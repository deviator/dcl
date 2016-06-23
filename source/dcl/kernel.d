module dcl.kernel;

import dcl.base;
import dcl.event;
import dcl.memory;
import dcl.commandqueue;
import dcl.program;
import dcl.device;
import dcl.context;

///
class CLKernel : CLObject
{
package:
    ///
    cl_kernel id;

public:

    ///
    this( CLProgram program, string nm )
    { id = checkCode!clCreateKernel( program.id, nm.toStringz ); }

    static private enum info_list =
    [
        "string function_name:name",
        "uint num_args",
        "uint reference_count:refcount",
        "cl_context:CLContext context",
        "cl_program:CLProgram program",
        "string attributes"
    ];

    mixin( infoMixin( "kernel", info_list ) );

protected:

    override void selfDestroy() { checkCall!clReleaseKernel(id); }
}

///
interface CLMemoryHandler
{
    ///
    protected CLMemory clmem() @property;

    ///
    /+ for post exec actions (release GL for example)
     + save queue and add this to list (acquired list for example)
     + before ocl operations process created list
     +/
    void preSetAsKernelArg( CLCommandQueue );

    ///
    mixin template CLMemoryHandlerHelper()
    {
        protected
        {
            CLMemory clmemory;
            CLMemory clmem() @property { return clmemory; }
        }
    }
}

///
struct CLKernelLocalMemory { size_t size; }

///
auto clKernelLocalMemory(T=ubyte)( size_t count )
{ return CLKernelLocalMemory( T.sizeof * count ); }

///
class CLKernelCaller
{
protected:
    size_t[] offset;
    size_t[] wgsize;
    size_t[] lgsize;

    uint range_dim = 1;

    void setArray( ref size_t[] arr, size_t[] val )
    {
        if( val )
        {
            enforce( val.length >= range_dim );
            arr = val[0..range_dim].dup;
        }
        else arr = null;
    }

public:

    CLKernel kernel;
    CLCommandQueue queue;
    CLEvent exec_inst;

    this( CLKernel kernel, CLCommandQueue queue )
    {
        this.kernel = kernel;
        this.queue = queue;
        wgsize = [64];
    }

    size_t rangeDim() const @property { return range_dim; }
    void set1DRange() { range_dim = 1; }
    void set2DRange() { range_dim = 2; }
    void set3DRange() { range_dim = 3; }

    void setGlobalOffset( size_t[] v... ) { setArray( offset, v ); }
    void setWorkGroupSize( size_t[] v... ) { setArray( wgsize, v ); }
    void setLocalGroupSize( size_t[] v... ) { setArray( lgsize, v ); }

    ///
    void setArgs(Args...)( Args args )
    {
        foreach( i, arg; args )
            setArg( i, arg );
    }

    ///
    void range( CLEvent[] wait_list=[] )
    {
        checkCallWL!clEnqueueNDRangeKernel( queue.id, kernel.id,
                range_dim, offset.ptr, wgsize.ptr, lgsize.ptr,
                wait_list, &exec_inst );
    }

    ///
    void task( CLEvent[] wait_list=[] )
    {
        checkCallWL!clEnqueueTask( queue.id, kernel.id, wait_list, &exec_inst );
    }

    static private enum info_list =
    [
        "size_t work_group_size:max_work_group_size",
        "size_t[3] compile_work_group_size",
        "ulong local_mem_size",
        "size_t preferred_work_group_size_multiple",
        "ulong private_mem_size"
    ];

    mixin( infoMixin( "kernel_work_group", "kernel", info_list, ["kernel","queue.device"] ) );

protected:

    ///
    void setArg(Arg)( uint index, Arg arg )
    {
        void *value;
        size_t size;

        static if( is( Arg : CLMemory ) )
        {
            auto aid = arg ? (cast(CLMemory)arg).id : null;
            value = &aid;
            size = cl_mem.sizeof;
        }
        else static if( is( Arg : CLMemoryHandler ) )
        {
            auto cmh = cast(CLMemoryHandler)arg;
            cl_mem aid = null;
            if( cmh !is null )
            {
                cmh.preSetAsKernelArg( queue );
                aid = cmh.clmem.id;
            }
            value = &aid;
            size = cl_mem.sizeof;
        }
        else static if( is( Arg == CLKernelLocalMemory ))
        {
            value = null;
            size = arg.size;
        }
        else static if( !hasIndirections!Arg )
        {
            value = &arg;
            size = arg.sizeof;
        }
        else
        {
            pragma(msg, "type of ", Arg, " couldn't be set as kernel argument" );
            static assert(0);
        }

        checkCall!clSetKernelArg( kernel.id, index, size, value );
    }
}
