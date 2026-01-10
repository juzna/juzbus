"""CFFI bindings to native juzbus library."""
from cffi import FFI
import os

ffi = FFI()

# Define C API from juzbus_c_api.h
ffi.cdef("""
    // Opaque types
    typedef void* juzbus_client_t;
    typedef void* juzbus_service_t;

    // Callback types
    typedef void (*juzbus_list_callback_t)(
        const char** instances,
        size_t count,
        void* user_data
    );

    typedef void (*juzbus_send_callback_t)(
        const char* response,
        const char* error,
        void* user_data
    );

    typedef void (*juzbus_command_callback_t)(
        const char* command,
        char** out_response,
        void* user_data
    );

    // Client API
    juzbus_client_t juzbus_client_create(void);
    void juzbus_client_destroy(juzbus_client_t client);

    void juzbus_client_list_instances(
        juzbus_client_t client,
        juzbus_list_callback_t callback,
        void* user_data
    );

    void juzbus_client_send_command(
        juzbus_client_t client,
        const char* instance_name,
        const char* command,
        juzbus_send_callback_t callback,
        void* user_data
    );

    // Service API
    juzbus_service_t juzbus_service_create(
        const char* instance_name,
        juzbus_command_callback_t callback,
        void* user_data
    );

    bool juzbus_service_start(juzbus_service_t service);
    void juzbus_service_stop(juzbus_service_t service);
    void juzbus_service_destroy(juzbus_service_t service);

    // Memory management
    void juzbus_free_string(char* str);
    void juzbus_free_string_array(char** arr, size_t count);

    // Utility
    const char* juzbus_version(void);
""")

# Load bundled dylib
_lib_path = os.path.join(os.path.dirname(__file__), "libjuzbus.dylib")

try:
    lib = ffi.dlopen(_lib_path)
except OSError as e:
    raise ImportError(
        f"Failed to load native library at {_lib_path}. "
        f"Make sure the dylib is built and bundled correctly. Error: {e}"
    ) from e

__all__ = ['ffi', 'lib']
