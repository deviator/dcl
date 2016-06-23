module dcl.event;

import dcl.base;
import dcl.context;
import dcl.commandqueue;

///
struct CLEvent
{
    ///
    cl_event id;

    alias id this;

    ///
    enum Command
    {
        NDRANGE_KERNEL       = CL_COMMAND_NDRANGE_KERNEL, ///
        TASK                 = CL_COMMAND_TASK, ///
        NATIVE_KERNEL        = CL_COMMAND_NATIVE_KERNEL, ///
        READ_BUFFER          = CL_COMMAND_READ_BUFFER, ///
        WRITE_BUFFER         = CL_COMMAND_WRITE_BUFFER, ///
        COPY_BUFFER          = CL_COMMAND_COPY_BUFFER, ///
        READ_IMAGE           = CL_COMMAND_READ_IMAGE, ///
        WRITE_IMAGE          = CL_COMMAND_WRITE_IMAGE, ///
        COPY_IMAGE           = CL_COMMAND_COPY_IMAGE, ///
        COPY_BUFFER_TO_IMAGE = CL_COMMAND_COPY_BUFFER_TO_IMAGE, ///
        COPY_IMAGE_TO_BUFFER = CL_COMMAND_COPY_IMAGE_TO_BUFFER, ///
        MAP_BUFFER           = CL_COMMAND_MAP_BUFFER, ///
        MAP_IMAGE            = CL_COMMAND_MAP_IMAGE, ///
        UNMAP_MEM_OBJECT     = CL_COMMAND_UNMAP_MEM_OBJECT, ///
        MARKER               = CL_COMMAND_MARKER, ///
        ACQUIRE_GL_OBJECTS   = CL_COMMAND_ACQUIRE_GL_OBJECTS, ///
        RELEASE_GL_OBJECTS   = CL_COMMAND_RELEASE_GL_OBJECTS, ///
        READ_BUFFER_RECT     = CL_COMMAND_READ_BUFFER_RECT, ///
        WRITE_BUFFER_RECT    = CL_COMMAND_WRITE_BUFFER_RECT, ///
        COPY_BUFFER_RECT     = CL_COMMAND_COPY_BUFFER_RECT, ///
        USER                 = CL_COMMAND_USER, ///
        BARRIER              = CL_COMMAND_BARRIER, ///
        MIGRATE_MEM_OBJECTS  = CL_COMMAND_MIGRATE_MEM_OBJECTS, ///
        FILL_BUFFER          = CL_COMMAND_FILL_BUFFER, ///
        FILL_IMAGE           = CL_COMMAND_FILL_IMAGE ///
    }

    ///
    enum Status
    {
        QUEUED    = CL_QUEUED,   ///
        SUBMITTED = CL_SUBMITTED,///
        RUNNING   = CL_RUNNING,  ///
        COMPLETE  = CL_COMPLETE  ///
    }

    static private enum info_list =
    [
        "cl_context:CLContext context",
        "cl_command_queue:CLCommandQueue command_queue:queue",
        "cl_command_type:Command command_type:command",
        "cl_int:Status command_execution_status:status",
        "uint reference_count:refcount"
    ];

    mixin( infoMixin( "event", info_list ) );

    static private enum prof_list =
    [
        "ulong queued",
        "ulong submit",
        "ulong start",
        "ulong end"
    ];

    mixin( infoMixin( "event_profiling", "profiling_command", prof_list ) );

    ///
    void retain() { checkCall!clRetainEvent(id); }

    ///
    void release() { checkCall!clReleaseEvent(id); }
}

unittest
{
    assertEq( CLEvent.sizeof, cl_event.sizeof );
}

class CLUserEvent
{
    CLEvent event;

    alias event this;

    this( CLContext ctx )
    {
        event = CLEvent( checkCode!clCreateUserEvent(ctx.id) );
    }

    void setComplite()
    { checkCall!clSetUserEventStatus( event, CLEvent.Status.COMPLETE ); }

    void setError( int val ) in{ assert( val < 0 ); } body
    { checkCall!clSetUserEventStatus( event, val ); }
}
