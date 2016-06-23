module dcl.commandqueue;

import dcl.base;
import dcl.device;
import dcl.context;

///
class CLCommandQueue : CLObject
{
protected:
    static CLCommandQueue[cl_command_queue] used;

    this( cl_command_queue id )
    {
        enforce( id !is null, new CLException( "can't create command queue with null id" ) );
        enforce( id !in used, new CLException( "can't create existing command queue" ) );
        this.id = id;
        used[id] = this;
        checkCall!clRetainCommandQueue(id);

        _context = reqContext;
        _device = reqDevice;
    }

    ///
    CLContext _context;
    ///
    CLDevice _device;

package:
    ///
    cl_command_queue id;

public:

    /// compatible with mixinfo as parameter
    static CLCommandQueue getFromID( cl_command_queue id )
    {
        if( id is null ) return null;
        if( id in used ) return used[id];
        return new CLCommandQueue(id);
    }

    CLContext context() @property { return _context; }
    CLDevice device() @property { return _device; }

    ///
    enum Properties
    {
        OUT_OF_ORDER = CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE, ///
        PROFILING = CL_QUEUE_PROFILING_ENABLE, ///
    }

    ///
    this( CLContext ctx, size_t devID, Properties[] prop=[] )
    in { assert( ctx !is null ); } body
    { this( ctx, ctx.devices[devID], prop ); }

    ///
    this( CLContext ctx, CLDevice dev, Properties[] prop=[] )
    in
    {
        assert( ctx !is null );
        assert( dev !is null );
    }
    body
    {
        enforce( find( ctx.devices, dev ), "device is not in context" );

        this( checkCode!clCreateCommandQueue( ctx.id, dev.id, buildFlags(prop) ) );
    }

    static CLCommandQueue[] forAllDevices( CLContext ctx, Properties[] prop=[] )
    {
        auto ret = new CLCommandQueue[]( ctx.devices.length );
        foreach( i; 0 .. ret.length )
            ret[i] = new CLCommandQueue( ctx, i, prop );
        return ret;
    }

    /// `clFlush`
    void flush() { checkCall!clFlush(id); }
    /// `clFinish`
    void finish() { checkCall!clFinish(id); }

    /// `clEnqueueBarrierWithWaitList`
    void barrier( CLEvent[] wl=[], CLEvent* ev=null )
    { checkCallWL!clEnqueueBarrierWithWaitList(id,wl,ev); }

    static private enum info_list =
    [
        "cl_context:CLContext context:reqContext",
        "cl_device_id:CLDevice device:reqDevice",
        "cl_command_queue_properties properties",
        "uint reference_count:refcount"
    ];

    mixin( infoMixin( "command_queue", "queue", info_list ) );

protected:

    override void selfDestroy()
    {
        used.remove(id);
        checkCall!clReleaseCommandQueue(id);
    }
}
