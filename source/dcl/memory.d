module dcl.memory;

import std.traits;

import dcl.base;
import dcl.context;
import dcl.event;
import dcl.commandqueue;

///
class CLMemory : CLObject
{
protected:
    ///
    this( cl_mem id )
    {
        enforce( id !is null, new CLException( "can't create memobject with null id" ) );
        this.id = id;

        _flags = parseFlags!Flag( flagMask );
    }

    private Flag[] _flags;

public:
    ///
    cl_mem id;

    ///
    enum Type
    {
        BUFFER         = CL_MEM_OBJECT_BUFFER,         ///
        IMAGE2D        = CL_MEM_OBJECT_IMAGE2D,        ///
        IMAGE3D        = CL_MEM_OBJECT_IMAGE3D,        ///
        IMAGE2D_ARRAY  = CL_MEM_OBJECT_IMAGE2D_ARRAY,  ///
        IMAGE1D        = CL_MEM_OBJECT_IMAGE1D,        ///
        IMAGE1D_ARRAY  = CL_MEM_OBJECT_IMAGE1D_ARRAY,  ///
        IMAGE1D_BUFFER = CL_MEM_OBJECT_IMAGE1D_BUFFER, ///
    }

    ///
    enum Flag
    {
        READ_WRITE     = CL_MEM_READ_WRITE,     /// `CL_MEM_READ_WRITE`
        WRITE_ONLY     = CL_MEM_WRITE_ONLY,     /// `CL_MEM_WRITE_ONLY`
        READ_ONLY      = CL_MEM_READ_ONLY,      /// `CL_MEM_READ_ONLY`
        USE_HOST_PTR   = CL_MEM_USE_HOST_PTR,   /// `CL_MEM_USE_HOST_PTR`
        ALLOC_HOST_PTR = CL_MEM_ALLOC_HOST_PTR, /// `CL_MEM_ALLOC_HOST_PTR`
        COPY_HOST_PTR  = CL_MEM_COPY_HOST_PTR   /// `CL_MEM_COPY_HOST_PTR`
    }

    ///
    const(Flag[]) flags() @property const { return _flags; }

    ///
    static CLMemory createBuffer( CLContext context, Flag[] flags, size_t size, void* host_ptr=null )
    {
        auto id = checkCode!clCreateBuffer( context.id, buildFlags(flags), size, host_ptr );

        return new CLMemory( id );
    }

    // TODO: Image

    ///
    void readTo( CLCommandQueue queue, void[] buffer, size_t offset=0, bool blocking=true,
            CLEvent[] wait_list=[], CLEvent* event=null )
    {
        enforce( type == Type.BUFFER ); // TODO: images

        checkCallWL!clEnqueueReadBuffer( queue.id, id,
               blocking, offset,
               buffer.length, buffer.ptr, wait_list, event );
    }

    ///
    void[] read( CLCommandQueue queue, size_t size, size_t offset=0, bool blocking=true,
            CLEvent[] wait_list=[], CLEvent* event=null )
    {
        auto buffer = new void[](size);
        readTo( queue, buffer, offset, blocking, wait_list, event );
        return buffer;
    }

    ///
    void write( CLCommandQueue queue, void[] buffer, size_t offset=0, bool blocking=true,
            CLEvent[] wait_list=[], CLEvent* event=null )
    {
        assert( type == Type.BUFFER ); // TODO: images

        checkCallWL!clEnqueueWriteBuffer( queue.id, id,
                blocking, offset,
                buffer.length, buffer.ptr,
                wait_list, event );
    }

    ///
    static struct MemoryMap
    {
        ///
        static struct Array { size_t len; void *ptr; }

        CLMemory memory;
        CLCommandQueue map_queue;

        union { Array arr; void[] data; }

        this( void* ptr, size_t len, CLMemory mem, CLCommandQueue mcq )
        {
            arr.ptr = ptr;
            arr.len = len;
            memory  = mem;
            map_queue = mcq;
        }

        bool valid() const @property { return arr.ptr !is null; }

        void unmap( CLCommandQueue queue=null,
                CLEvent[] wait_list=[], CLEvent* event=null )
        {
            if( arr.ptr is null ) return;

            if( queue is null ) queue = map_queue;
            checkCallWL!clEnqueueUnmapMemObject( queue.id,
                memory.id, arr.ptr,
                wait_list, event );

            arr.ptr = null;
        }
    }

    enum MapFlag
    {
        READ = CL_MAP_READ, ///
        WRITE = CL_MAP_WRITE, ///
        READ_WRITE = READ | WRITE ///
    }

    // TODO: Image

    MemoryMap mapBuffer( CLCommandQueue queue,
            MapFlag mode=MapFlag.READ_WRITE,
            size_t offset=0, size_t cb=0,
            bool blocking=true, CLEvent[] wait_list=[],
            CLEvent* event=null )
    {
        if( cb == 0 ) cb = size; // dynamic property

        auto ptr = checkCodeWL!clEnqueueMapBuffer( queue.id,
                id, blocking, mode, offset, cb,
                wait_list, event );

        return MemoryMap( ptr, cb, this, queue );
    }

    enum string[] info_list =
    [
        "cl_mem_object_type:Type type",
        "cl_mem_flags flags:flagMask",
        "size_t size",
        "size_t offset",
        "void* host_ptr",
        "uint map_count",
        "uint reference_count:refcount",
        "cl_context:CLContext context",
    ];

    mixin( infoMixin( "mem_object", "mem", info_list ) );

protected:
    override void selfDestroy() { checkCall!clReleaseMemObject(id); }
}
