module dcl.device;

import dcl.base;
import dcl.platform;

///
class CLDevice : CLObject
{
protected:

    static CLDevice[cl_device_id] used;

    ///
    this( cl_device_id id )
    {
        enforce( id !is null, new CLException( "can't create device with null id" ) );
        enforce( id !in used, new CLException( "can't create existing device" ) );
        this.id = id;
        used[id] = this;
        checkCall!clRetainDevice( id );

        _platform = reqPlatform;
    }

    ///
    CLPlatform _platform;

package:
    ///
    cl_device_id id;

public:

    static CLDevice getFromID( cl_device_id id )
    {
        if( id is null ) return null;
        if( id in used ) return used[id];
        return new CLDevice(id);
    }

    CLPlatform platform() @property { return _platform; }

    ///
    enum Type
    {
        DEFAULT     = CL_DEVICE_TYPE_DEFAULT, ///
        CPU         = CL_DEVICE_TYPE_CPU, ///
        GPU         = CL_DEVICE_TYPE_GPU, ///
        ACCELERATOR = CL_DEVICE_TYPE_ACCELERATOR, ///
        CUSTOM      = CL_DEVICE_TYPE_CUSTOM, ///
        ALL         = CL_DEVICE_TYPE_ALL ///
    }

    ///
    enum FPConfig
    {
        DENORM           = CL_FP_DENORM,          /// `CL_FP_DENORM`
        INF_NAN          = CL_FP_INF_NAN,         /// `CL_FP_INF_NAN`
        ROUND_TO_NEAREST = CL_FP_ROUND_TO_NEAREST,/// `CL_FP_ROUND_TO_NEAREST`
        ROUND_TO_ZERO    = CL_FP_ROUND_TO_ZERO,   /// `CL_FP_ROUND_TO_ZERO`
        ROUND_TO_INF     = CL_FP_ROUND_TO_INF,    /// `CL_FP_ROUND_TO_INF`
        FMA              = CL_FP_FMA              /// `CL_FP_FMA`
    }

    ///
    enum ExecCapabilities
    {
        KERNEL        = CL_EXEC_KERNEL, /// `CL_EXEC_KERNEL`
        NATIVE_KERNEL = CL_EXEC_NATIVE_KERNEL /// `CL_EXEC_NATIVE_KERNEL`
    }

    ///
    enum MemCacheType
    {
        NONE             = CL_NONE,            /// `CL_NONE`
        READ_ONLY_CACHE  = CL_READ_ONLY_CACHE, /// `CL_READ_ONLY_CACHE`
        READ_WRITE_CACHE = CL_READ_WRITE_CACHE /// `CL_READ_WRITE_CACHE`
    }

    enum LocalMemType
    {
        LOCAL  = CL_LOCAL, /// `CL_LOCAL`
        GLOBAL = CL_GLOBAL /// `CL_GLOBAL`
    }

    static private enum info_list =
    [
        "cl_device_type type:typeMask",
        "uint vendor_id",
        "uint max_compute_units",
        "uint max_work_item_dimensions",
        "size_t[] max_work_group_size",
        "size_t[] max_work_item_sizes",
        "uint preferred_vector_width_char",
        "uint preferred_vector_width_short",
        "uint preferred_vector_width_int",
        "uint preferred_vector_width_long",
        "uint preferred_vector_width_float",
        "uint preferred_vector_width_double",
        "uint preferred_vector_width_half",
        "uint native_vector_width_char",
        "uint native_vector_width_short",
        "uint native_vector_width_int",
        "uint native_vector_width_long",
        "uint native_vector_width_float",
        "uint native_vector_width_double",
        "uint native_vector_width_half",
        "uint max_clock_frequency",
        "uint address_bits",
        "uint max_read_image_args",
        "uint max_write_image_args",
        "ulong max_mem_alloc_size",
        "size_t image2d_max_width",
        "size_t image2d_max_height",
        "size_t image3d_max_width",
        "size_t image3d_max_height",
        "size_t image3d_max_depth",
        "cl_uint:bool image_support",
        "size_t max_parameter_size",
        "uint max_samplers",
        "uint mem_base_addr_align",
        "cl_device_fp_config single_fp_config",
        "cl_device_mem_cache_type:MemCacheType global_mem_cache_type",
        "uint global_mem_cacheline_size",
        "ulong global_mem_cache_size",
        "ulong global_mem_size",
        "ulong max_constant_buffer_size",
        "uint max_constant_args",
        "cl_device_local_mem_type:LocalMemType local_mem_type",
        "ulong local_mem_size",
        "cl_bool:bool error_correction_support",
        "size_t profiling_timer_resolution",
        "cl_bool:bool endian_little",
        "cl_bool:bool available",
        "cl_bool:bool compiler_available",
        "cl_device_exec_capabilities:ExecCapabilities execution_capabilities",
        "cl_command_queue_properties queue_properties",
        "string name",
        "string vendor",
        "string !driver_version:driver_version",
        "string profile",
        "string version:_version",
        "string extensions",
        "cl_device_fp_config double_fp_config",
        "cl_bool:bool host_unified_memory",
        "string opencl_c_version",
        "cl_bool:bool linker_available",
        "string built_in_kernels",
        "size_t image_max_buffer_size",
        "size_t image_max_array_size",
        "cl_device_id:CLDevice parent_device",
        "uint partition_max_sub_devices",
        "cl_device_partition_property[] partition_properties",
        "cl_device_affinity_domain partition_affinity_domain",
        "cl_device_partition_property[] partition_type",
        "uint reference_count:refcount",
        "cl_bool:bool preferred_interop_user_sync",
        "size_t printf_buffer_size",
        "cl_platform_id:CLPlatform platform:reqPlatform",
    ];

    mixin( infoMixin( "device", info_list ) );

protected:

    override void selfDestroy()
    {
        used.remove(id);
        checkCall!clReleaseDevice( id );
    }
}
