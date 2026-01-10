#include <node_api.h>
#include "juzbus_c_api.h"

namespace juzbus {

// Forward declarations
napi_value InitClient(napi_env env, napi_value exports);
napi_value InitService(napi_env env, napi_value exports);

} // namespace juzbus

// Module initialization function
static napi_value Init(napi_env env, napi_value exports) {
    // Initialize Client class
    juzbus::InitClient(env, exports);

    // Initialize Service class
    juzbus::InitService(env, exports);

    // Export version
    napi_value version;
    const char* version_str = juzbus_version();
    napi_create_string_utf8(env, version_str, NAPI_AUTO_LENGTH, &version);
    napi_set_named_property(env, exports, "version", version);

    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
