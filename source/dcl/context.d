module dcl.context;

import dcl.base;
import dcl.device;
import dcl.platform;
import dcl.program;
import dcl.commandqueue;

///
class CLContext : CLObject
{
protected:
    ///
    static synchronized class NotifyBuffer
    {
        ///
        protected Notify[] list;

        ///
        void push( Notify n ) { list ~= n; }

        ///
        Notify[] getAll() const
        {
            auto ret = new Notify[]( list.length );
            foreach( i, n; list ) ret[i] = n;
            return ret;
        }

        ///
        void drop() { list.length = 0; }
    }

    ///
    shared NotifyBuffer notify_buffer;

    static CLContext[cl_context] used;

    this( cl_context id )
    {
        enforce( id !is null, new CLException( "can't create context with null id" ) );
        enforce( id !in used, new CLException( "can't create existing context" ) );
        this.id = id;
        used[id] = this;
        checkCall!clRetainContext(id);

        notify_buffer = new shared NotifyBuffer;
        updateDevices();
    }

    CLDevice[] _devices;

    void updateDevices()
    {
        import std.stdio;
        uint ndev;
        checkCall!clGetContextInfo( id, CL_CONTEXT_NUM_DEVICES,
                uint.sizeof, &ndev, null );

        auto dev_ids = new cl_device_id[](ndev);
        size_t dev_ids_bytes;

        checkCall!clGetContextInfo( id, CL_CONTEXT_DEVICES,
                ndev * cl_device_id.sizeof,
                dev_ids.ptr, &dev_ids_bytes );

        _devices = dev_ids.map!(a=>CLDevice.getFromID(a)).array;
    }

package:
    ///
    cl_context id;

public:

    static CLContext getFromID( cl_context id )
    {
        if( id is null ) return null;
        if( id in used ) return used[id];
        return new CLContext(id);
    }

    ///
    static struct Notify
    {
        ///
        string errinfo;
        ///
        immutable(void)[] bininfo;
    }

    ///
    this( CLDevice[] devs )
    in{ assert(devs.length); } body
    {
        enforce( devs.all!(a=>a.platform is devs[0].platform) );

        auto prop = getProperties(devs[0].platform);

        this( checkCode!clCreateContext( prop.ptr,
                                        cast(uint)_devices.length,
                                        getIDsPtr(_devices),
                                        &pfn_notify,
                                        cast(void*)notify_buffer ) );
    }

    ///
    this( CLPlatform pl, CLDevice.Type type=CLDevice.Type.ALL )
    {
        auto prop = getProperties(pl);

        this( checkCode!clCreateContextFromType( prop.ptr, type,
                                       &pfn_notify,
                                       cast(void*)notify_buffer ) );
    }

    ///
    CLPlatform platform() @property { return _devices[0].platform; }

    ///
    CLDevice[] devices() @property { return _devices; }

    ///
    Notify[] notifies() const { return notify_buffer.getAll(); }
    ///
    void dropNotifies() { return notify_buffer.drop(); }

    ///
    CLProgram buildProgram( string src, CLBuildOption[] opt=[] )
    {
         auto prog = regChild( CLProgram.createWithSource( this, src ) );
         prog.build( devices, opt );
         return prog;
    }

    ///
    CLCommandQueue createQueue( CLCommandQueue.Properties[] prop, size_t devNo=0 )
    in{ assert( devNo < devices.length ); } body
    { return newChild!CLCommandQueue( this, devNo, prop ); }

    static private enum info_list =
    [
        "uint reference_count:refcount",
        "cl_context_properties[] properties"
    ];

    mixin( infoMixin( "context", info_list ) );

protected:

    override void selfDestroy()
    {
        used.remove(id);
        checkCall!clReleaseContext(id);
    }

    cl_context_properties[] getProperties( CLPlatform p )
    {
        return [ CL_CONTEXT_PLATFORM, cast(cl_context_properties)(p.id), 0 ];
    }
}

private
{
    version(Windows)
    {
        extern(Windows) void pfn_notify( const char* errinfo, const void* private_info, size_t cb, void* user_data )
        {
            auto nb = (cast(shared CLContext.NotifyBuffer)user_data);
            nb.push( CLContext.Notify( errinfo.fromStringz.idup,
                        (cast(ubyte*)private_info)[0..cb].idup ) );
        }
    }
    else
    {
        extern(C) void pfn_notify( const char* errinfo, const void* private_info, size_t cb, void* user_data )
        {
            auto nb = (cast(shared CLContext.NotifyBuffer)user_data);
            nb.push( CLContext.Notify( errinfo.fromStringz.idup,
                        (cast(ubyte*)private_info)[0..cb].idup ) );
        }
    }
}
