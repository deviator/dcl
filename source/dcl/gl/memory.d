module dcl.gl.memory;

version(clglinterop):

import derelict.opengl3.gl;

import dcl.base;
import dcl.memory;
import dcl.commandqueue;
import dcl.context;
import dcl.event;

import des.cl.gl.context;

///
class CLGLMemory : CLMemory
{
protected:
    ///
    this( CLGLContext ctx, cl_mem id )
    {
        super( id );
        gl_context = ctx;
    }

    CLGLContext gl_context;

    bool _acquired = false;

public:

    enum Access : Flag
    {
        RW = Flag.READ_WRITE,
        RO = Flag.READ_ONLY,
        WO = Flag.WRITE_ONLY
    }

    ///
    static auto createFromGLBuffer( CLGLContext ctx, uint gl_id,
            Access access=Access.RW )
    in{ assert( ctx !is null ); } body
    {
        auto id = checkCode!clCreateFromGLBuffer( ctx.id, access, gl_id );
        return new CLGLMemory( ctx, id );
    }

    /// note: miplevel=0;
    static auto createFromGLTexture( CLGLContext ctx, uint gl_id,
            GLenum target, Access access=Access.RW )
    in{ assert( ctx !is null ); } body
    {
        enum miplevel = 0;
        auto id = checkCode!clCreateFromGLTexture( ctx.id, access, target, miplevel, gl_id );
        return new CLGLMemory( ctx, id );
    }

    ///
    static auto createFromGLRenderBuffer( CLGLContext ctx, uint gl_id, Access access=Access.RW )
    in{ assert( ctx !is null ); } body
    {
        auto id = checkCode!clCreateFromGLRenderbuffer( ctx.id, access, gl_id );
        return new CLGLMemory( ctx, id );
    }

    ///
    bool acquired() @property const { return _acquired; }

    ///
    void acquireFromGL( CLCommandQueue queue, CLEvent[] wait_list=[], CLEvent* event=null )
    in{ assert( queue !is null ); } body
    {
        if( acquired ) return;
        checkCallWL!clEnqueueAcquireGLObjects( queue.id, 1u, &id,
                wait_list, event );
        _acquired = true;
        (cast(CLGLContext)context).registerAcquired( this );
    }

    ///
    void releaseToGL( CLCommandQueue queue, CLEvent[] wait_list=[], CLEvent* event=null )
    {
        if( !acquired ) return;
        checkCallWL!clEnqueueReleaseGLObjects( queue.id, 1u, &id,
                wait_list, event );
        _acquired = false;
        (cast(CLGLContext)context).unregisterAcquired( this );
    }

    override CLContext context() @property
    {
        assert( gl_context.id == super.context.id );
        return gl_context;
    }

    package void ctxReleaseToGL() { _acquired = false; }
}
