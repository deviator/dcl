module dcl.gl.context;

version(clglinterop):

import dcl.base;
import dcl.context;
import dcl.device;
import dcl.platform;
import dcl.event;
import dcl.commandqueue;

import dcl.gl.memory;

///
class CLGLContext : CLContext
{
protected:

    ///
    CLGLMemory[] acquired_list;

package:

    ///
    void registerAcquired( CLGLMemory mem )
    { acquired_list ~= mem; }

    ///
    void unregisterAcquired( CLGLMemory mem )
    {
        CLGLMemory[] buf;
        foreach( elem; acquired_list )
            if( elem.id != mem.id ) buf ~= elem;
        acquired_list = buf;
    }

public:

    ///
    this( CLPlatform pl )
    {
        cl_device_id[32] devices; size_t size;
        clGetGLContextInfoKHR( getProperties(pl).ptr, CL_DEVICES_FOR_GL_CONTEXT_KHR,
                              32 * cl_device_id.sizeof, devices.ptr, &size);
        size /= cl_device_id.sizeof;
        super( devices[0..size].map!(a=>CLDevice.getFromID(a)).array );
    }

    ///
    void releaseAllToGL( CLCommandQueue queue, CLEvent[] wait_list=[], CLEvent* event=null )
    {
        checkCallWL!clEnqueueReleaseGLObjects( queue.id,
                cast(uint)acquired_list.length,
                getIDsPtr(acquired_list),
                wait_list, event );

        foreach( elem; acquired_list ) elem.ctxReleaseToGL();
        acquired_list.length = 0;
    }

protected:
    override cl_context_properties[] getProperties( CLPlatform p )
    {
        version(linux)
        {
            import derelict.opengl3.glx;
            return [ CL_GL_CONTEXT_KHR,  cast(cl_context_properties)glXGetCurrentContext(),
                     CL_GLX_DISPLAY_KHR, cast(cl_context_properties)glXGetCurrentDisplay() ] ~
                super.getProperties( p );
        }
        version(Windows)
        {
            import derelict.opengl3.wgl;
            return [ CL_GL_CONTEXT_KHR,   cast(cl_context_properties)wglGetCurrentContext(),
                     CL_WGL_HDC_KHR,      cast(cl_context_properties)wglGetCurrentDC() ] ~
                super.getProperties( p );
        }
        version(OSX)
        {
            // TODO
            static assert(0, "not implemented");
        }
    }
}
