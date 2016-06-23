module dcl.platform;

import dcl.base;

import dcl.device;
import dcl.context;

///
class CLPlatform : CLObject
{
private:

    static CLPlatform[cl_platform_id] used;

    this( cl_platform_id id )
    {
        enforce( id !is null, new CLException( "can't create platform with null id" ) );
        enforce( id !in used, new CLException( "can't create existing platform" ) );
        this.id = id;
        used[id] = this;

        updateDevs();
    }

    void updateDevs()
    {
        uint nums;
        auto type = CLDevice.Type.ALL;

        checkCall!clGetDeviceIDs( id, type, 0, null, &nums );
        auto ids = new cl_device_id[](nums);
        checkCall!clGetDeviceIDs( id, type, nums, ids.ptr, null );

        _devices = regChild( ids.map!(a=>CLDevice.getFromID(a)).array );
    }

    CLDevice[] _devices;

package:
    ///
    cl_platform_id id;

public:

    static CLPlatform getFromID( cl_platform_id id )
    {
        if( id is null ) return null;
        if( id in used ) return used[id];
        return new CLPlatform( id );
    }

    ///
    CLDevice[] devices() @property { return _devices; }

    ///
    static CLPlatform[] getAll()
    {
        uint nums;
        checkCall!clGetPlatformIDs( 0, null, &nums );
        auto ids = new cl_platform_id[](nums);
        checkCall!clGetPlatformIDs( nums, ids.ptr, null );

        return ids.map!(a=>getFromID(a)).array;
    }

    static private enum info_list =
    [
        "string name",
        "string vendor",
        "string profile",
        "string version:_version",
        "string extensions"
    ];

    mixin( infoMixin( "platform", info_list ) );

protected:

    override void selfDestroy() { used.remove(id); }
}
