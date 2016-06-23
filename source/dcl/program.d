module dcl.program;

import dcl.base;
import dcl.device;
import dcl.context;
import dcl.kernel;

class CLBuildException : CLException
{
    CLError error;
    CLProgram.BuildInfo[] info;
    this( CLError error, CLProgram.BuildInfo[] info,
            string file=__FILE__, size_t line=__LINE__ )
    {
        this.error = error;
        this.info = info;
        super( format( "cl program build failed: %s\n%s", error,
                    this.info.map!(a=>format( "build for dev <%s> %s log:\n%s",
                            a.device.name, a.status, a.log )).array.join("\n") ), file, line );
    }
}

///
class CLProgram : CLObject
{
protected:

    static CLProgram[cl_program] used;

    ///
    this( cl_program id )
    {
        enforce( id !is null, new CLException( "can't create program with null id" ) );
        enforce( id !in used, new CLException( "can't create existing program" ) );
        this.id = id;
        used[id] = this;

        updateInfo();
    }

    void updateInfo()
    {
        _context = reqContext;
        updateSource();
        updateDevices();
        updateKernels();
    }

    void updateDevices()
    {
        uint ndev;
        checkCall!clGetProgramInfo( id, CL_PROGRAM_NUM_DEVICES,
                uint.sizeof, &ndev, null );

        auto dev_ids = new cl_device_id[](ndev);
        size_t dev_ids_bytes;

        checkCall!clGetProgramInfo( id, CL_PROGRAM_DEVICES,
                ndev * cl_device_id.sizeof,
                dev_ids.ptr, &dev_ids_bytes );

        _devices = dev_ids.map!(a=>CLDevice.getFromID(a)).array;
    }

    void updateSource()
    {
        size_t len;
        checkCall!clGetProgramInfo( id, CL_PROGRAM_SOURCE, 0, null, &len );
        auto src = new char[]( len );
        checkCall!clGetProgramInfo( id, CL_PROGRAM_SOURCE, len, src.ptr, &len );
        _source = src.tr("\0","\n").idup;
    }

    void updateKernels()
    {
        foreach( name, kernel; kernels )
            kernel.destroy;

        //kernels.clear;
        kernels = null;

        // by standart clGetProgramInfo returns
        // CL_INVALID_PROGRAM_EXECUTABLE if param_name is
        // CL_PROGRAM_NUM_KERNELS or CL_PROGRAM_KERNEL_NAMES
        // and a successful program executable has not been
        // built for at least one device in the list of devices
        // associated with program.
        try if( kernel_names.length == 0 ) return;
        catch( CLCallException e )
        {
            if( e.error == CLError.INVALID_PROGRAM_EXECUTABLE ) return;
            else throw e;
        }

        auto knlist = kernel_names.split(";");

        foreach( name; knlist )
            kernels[name] = newChild!CLKernel( this, name );

        kernels.rehash;
    }

    CLDevice[] _devices;
    CLContext _context;
    string _source;
    CLKernel[string] kernels;

package:
    ///
    cl_program id;

public:

    static CLProgram getFromID( cl_program id )
    {
        if( id is null ) return null;
        if( id in used ) return used[id];
        return new CLProgram(id);
    }

    @property
    {
        CLDevice[] devices() { return _devices; }
        CLContext context() { return _context; }
        string source() { return _source; }
    }

    /// get kernel by name
    CLKernel opIndex( string name ) { return kernels[name]; }

    /// get kernels names
    string[] kernelsNames() @property { return kernels.keys; }

    ///
    package static CLProgram createWithSource( CLContext context, string src )
    {
        auto buf = cast(char*)src.toStringz;
        auto id = checkCode!clCreateProgramWithSource( context.id, 1,
                     &buf, [src.length].ptr );

        return CLProgram.getFromID( id );
    }

    ///
    BuildInfo[] build( CLDevice[] devs, CLBuildOption[] options=[] )
    {
        try checkCall!clBuildProgram( id,
                cast(uint)devs.length,
                getIDsPtr(devs),
                getOptionsStringz(options),
                null, null /+ callback and userdata for callback +/ );
        catch( CLCallException e )
            throw new CLBuildException( e.error, buildInfo(), e.file, e.line );

        updateInfo();

        return buildInfo();
    }

    /// use devices from context
    BuildInfo[] build( CLBuildOption[] options=[] )
    { return build( context.devices, options ); }

    ///
    enum BuildStatus
    {
        NONE        = CL_BUILD_NONE,       /// `CL_BUILD_NONE`
        ERROR       = CL_BUILD_ERROR,      /// `CL_BUILD_ERROR`
        SUCCESS     = CL_BUILD_SUCCESS,    /// `CL_BUILD_SUCCESS`
        IN_PROGRESS = CL_BUILD_IN_PROGRESS /// `CL_BUILD_IN_PROGRESS`
    }

    ///
    static struct BuildInfo
    {
        ///
        CLDevice device;
        ///
        BuildStatus status;
        ///
        string log;
    }

    ///
    BuildInfo[] buildInfo()
    {
        return devices
            .map!(a=>BuildInfo(a,buildStatus(a),buildLog(a)))
            .array;
    }

    static private enum info_list =
    [
        "uint reference_count:refcount",
        "cl_context:CLContext context:reqContext",
        //"uint num_devices",
        //"cl_device_id[] devices",
        //"size_t[] binary_sizes",
        //"void*[] binaries",
        //"size_t num_kernels",
        "string kernel_names",
    ];

    mixin( infoMixin( "program", info_list ) );

protected:

    override void selfDestroy()
    {
        used.remove(id);
        checkCall!clReleaseProgram(id);
    }

    ///
    auto getOptionsStringz( CLBuildOption[] options )
    {
        if( options.length == 0 ) return null;
        return options.map!(a=>a.toString).array.join(" ").toStringz;
    }

    ///
    BuildStatus buildStatus( CLDevice device )
    {
        cl_build_status val;
        size_t len;
        checkCall!clGetProgramBuildInfo( id, device.id,
                CL_PROGRAM_BUILD_STATUS, cl_build_status.sizeof, &val, &len );
        return cast(BuildStatus)val;
    }

    ///
    string buildLog( CLDevice device )
    {
        size_t len;
        checkCall!clGetProgramBuildInfo( id, device.id,
                CL_PROGRAM_BUILD_LOG, 0, null, &len );
        if( len == 0 ) return null;
        auto val = new char[](len);
        checkCall!clGetProgramBuildInfo( id, device.id,
                CL_PROGRAM_BUILD_LOG, val.length, val.ptr, &len );
        return val.idup;
    }
}

///
interface CLBuildOption
{
    ///
    string toString();

    static
    {
        ///
        CLBuildOption define( string name, string val=null )
        {
            return new class CLBuildOption
            {
                override string toString()
                { return format( "-D %s%s", name, (val?"="~val:"") ); }
            };
        }

        ///
        CLBuildOption include( string d )
        {
            return new class CLBuildOption
            { override string toString() { return format( "-I %s", d ); } };
        }

        ///
        @property CLBuildOption inhibitAllWarningMessages()
        {
            return new class CLBuildOption
            { override string toString() { return "-w"; } };
        }

        ///
        @property CLBuildOption makeAllWarningsIntoErrors()
        {
            return new class CLBuildOption
            { override string toString() { return "-Werror"; } };
        }

        private
        {
            /++ generate static functions to return simple options
                + Rules:
                +   to camel case, first small
                + Example:
                + ---
                +   single-precision-constant ->
                +   static @property CLBuildOption singlePrecisionConstant()
                + ---
                +
                + List:
                + ---
                +  single-precision-constant
                +  denorms-are-zero
                +  opt-disable
                +  strict-aliasing
                +  mad-enable
                +  no-signed-zeros
                +  unsafe-math-optimizations
                +  finite-math-only
                +  fast-relaxed-math
                + ---
                +/
            enum string[] simple_build_options =
            [
                "single-precision-constant",
                "denorms-are-zero",
                "opt-disable",
                "strict-aliasing",
                "mad-enable",
                "no-signed-zeros",
                "unsafe-math-optimizations",
                "finite-math-only",
                "fast-relaxed-math"
            ];

            private string simpleBuildOptionsListDefineString( in string[] list )
            { return map!(a=>simpleBuildOptionDefineString(a))(list).array.join("\n"); }

            string simpleBuildOptionDefineString( string opt )
            {
                return format(`
            static @property CLBuildOption %s()
            {
                return new class CLBuildOption
                { override string toString() { return "-cl-%s"; } };
            }`, toCamelCaseBySep(opt,"-",false), opt );
            }
        }

        mixin( simpleBuildOptionsListDefineString( simple_build_options ) );
    }
}
