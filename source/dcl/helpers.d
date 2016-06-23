module dcl.helpers;

import dcl;

import std.typecons;

alias tss = Tuple!(string,string);

/// full info about platform
auto getCLPlatformFullInfo( CLPlatform pl )
{
    return [
        tss("platform" , pl.name),
        tss("vendor"   , pl.vendor),
        tss("profile"  , pl.profile),
        tss("version"  , pl._version),
        tss("ext"      , pl.extensions),
    ];
}

/// full info about platform as string
string getCLPlatformFullInfoString( CLPlatform pl, string fmt="", string sep="\n" )
{ return formatInfo( getCLPlatformFullInfo(pl), fmt, sep ); }

/// full info about device
auto getCLDeviceFullInfo( CLDevice dev )
{
    return [
        tss("type - name"                    , format( "%s - %s", fmtFlags(dev.typeMask,[CLDevice.Type.ALL]), dev.name ) ),
        tss("available"                      , format( "dev:%s compiler:%s linker:%s", dev.available, dev.compiler_available, dev.linker_available ) ),
        tss("max_compute_units"              , format( "%s", dev.max_compute_units ) ),
        tss("max_work_item_dimensions"       , format( "%s", dev.max_work_item_dimensions ) ),
        tss("max_work_group_size"            , format( "%s", dev.max_work_group_size ) ),
        tss("max_work_item_sizes"            , format( "%s", dev.max_work_item_sizes ) ),
        tss("image_support"                  , format( "%s", dev.image_support ) ),
        tss("max_read_image_args"            , format( "%s", dev.max_read_image_args ) ),
        tss("max_write_image_args"           , format( "%s", dev.max_write_image_args ) ),
        tss("max image2d size"               , format( "[%d, %d]", dev.image2d_max_width, dev.image2d_max_height ) ),
        tss("max image3d size"               , format( "[%d, %d, %d]", dev.image3d_max_width, dev.image3d_max_height, dev.image3d_max_depth ) ),
        tss("image_max_buffer_size"          , format( "%s px", dev.image_max_buffer_size ) ),
        tss("image_max_array_size"           , format( "%s", dev.image_max_array_size ) ),
        tss("address_bits"                   , format( "%s", dev.address_bits ) ),
        tss("max_mem_alloc_size"             , fmtSize( dev.max_mem_alloc_size ) ),
        tss("max_clock_frequency"            , format( "%s MHz (%.2e sec)", dev.max_clock_frequency, 1.0f / ( dev.max_clock_frequency * 1e6 ) ) ),
        tss("max_parameter_size"             , fmtSize( dev.max_parameter_size ) ),
        tss("max_samplers"                   , format( "%s", dev.max_samplers ) ),
        tss("mem_base_addr_align"            , format( "%s bits", dev.mem_base_addr_align ) ),
        tss("global_mem_cache_type"          , format( "%s", dev.global_mem_cache_type ) ),
        tss("global_mem_cacheline_size"      , format( "%s", fmtSize( dev.global_mem_cacheline_size ) ) ),
        tss("global_mem_cache_size"          , format( "%s", fmtSize( dev.global_mem_cache_size ) ) ),
        tss("global_mem_size"                , format( "%s", fmtSize( dev.global_mem_size ) ) ),
        tss("max_constant_buffer_size"       , format( "%s", fmtSize( dev.max_constant_buffer_size ) ) ),
        tss("max_constant_args"              , format( "%s", dev.max_constant_args ) ),
        tss("local_mem_type"                 , format( "%s", dev.local_mem_type ) ),
        tss("local_mem_size"                 , format( "%s", fmtSize( dev.local_mem_size ) ) ),
        tss("error_correction_support"       , format( "%s", dev.error_correction_support ) ),
        tss("profiling_timer_resolution"     , format( "%s ns", dev.profiling_timer_resolution ) ),
        tss("endian_little"                  , format( "%s", dev.endian_little ) ),
        tss("preferred vector width"         , format( "char:%s short:%s int:%s long:%s half:%s float:%s double:%s",
                                                       dev.preferred_vector_width_char,
                                                       dev.preferred_vector_width_short,
                                                       dev.preferred_vector_width_int,
                                                       dev.preferred_vector_width_long,
                                                       dev.preferred_vector_width_half,
                                                       dev.preferred_vector_width_float,
                                                       dev.preferred_vector_width_double ) ),
        tss("native vector width"            , format( "char:%s short:%s int:%s long:%s half:%s float:%s double:%s",
                                                       dev.native_vector_width_char,
                                                       dev.native_vector_width_short,
                                                       dev.native_vector_width_int,
                                                       dev.native_vector_width_long,
                                                       dev.native_vector_width_half,
                                                       dev.native_vector_width_float,
                                                       dev.native_vector_width_double ) ),
        tss("execution_capabilities"         , format( "%s", fmtFlags!(CLDevice.ExecCapabilities)(dev.execution_capabilities) ) ),
        tss("queue_properties"               , format( "%s", fmtFlags!(CLCommandQueue.Properties)(dev.queue_properties) ) ),
        tss("vendor"                         , format( "%s (id:%s)", dev.vendor, dev.vendor_id ) ),
        tss("driver_version"                 , format( "%s", dev.driver_version ) ),
        tss("profile"                        , format( "%s", dev.profile ) ),
        tss("version"                        , format( "%s", dev._version ) ),
        tss("extensions"                     , format( "%s", dev.extensions ) ),
        tss("built_in_kernels"               , format( "%s", dev.built_in_kernels ) ),
        tss("opencl_c_version"               , format( "%s", dev.opencl_c_version ) ),
      //tss("platform"                       , format( "%s", dev.platform ) ),
        tss("single_fp_config"               , format( "%s", fmtFlags!(CLDevice.FPConfig)(dev.single_fp_config) ) ),
        tss("double_fp_config"               , format( "%s", fmtFlags!(CLDevice.FPConfig)(dev.double_fp_config) ) ),
        tss("host_unified_memory"            , format( "%s", dev.host_unified_memory ) ),
        tss("is root device"                 , format( "%s", !dev.parent_device ) ),
        tss("partition_max_sub_devices"      , format( "%s", dev.partition_max_sub_devices ) ),
        tss("partition_properties"           , format( "%s", dev.partition_properties ) ),
        tss("partition_affinity_domain"      , format( "%s", dev.partition_affinity_domain ) ),
        tss("partition_type"                 , format( "%s", dev.partition_type ) ),
        tss("reference_count"                , format( "%s", dev.refcount ) ),
        tss("preferred_interop_user_sync"    , format( "%s", dev.preferred_interop_user_sync ) ),
        tss("printf_buffer_size"             , fmtSize( dev.printf_buffer_size ) ),
    ];
}

/// full info about device as string
string getCLDeviceFullInfoString( CLDevice dev, string fmt="", string sep="\n" )
{ return formatInfo( getCLDeviceFullInfo(dev), fmt, sep ); }

string formatInfo( Tuple!(string,string)[] info, string fmt="", string sep="\n" )
{
    string[] ret;

    if( fmt == "" ) fmt = " %30 s : %s";

    foreach( item; info )
        ret ~= format( fmt, item[0], item[1] );

    return ret.join(sep);
}

import std.traits;

string fmtSize( ulong bytes )
{
    string ret = format( "%d bytes", bytes );
    if( bytes < 1024 ) return ret;

    enum sizes = [ "", "Ki", "Mi", "Gi", "Ti", "Pi" ];
    float size = bytes;
    ubyte k;
    do { k++; size /= 1024; } while( size > 1024 );
    return format( "%.2f %s (%s)", size, sizes[k]~"b", ret );
}

string fmtFlags(T)( ulong mask, T[] without=[] )
{ return parseFlags!T(mask,without).map!(a=>format("%s",a)).array.join("|"); }
