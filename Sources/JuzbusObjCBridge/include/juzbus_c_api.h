#ifndef JUZBUS_C_API_H
#define JUZBUS_C_API_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// MARK: - Opaque Types
// ============================================================================

/// Opaque handle to a Juzbus client instance
typedef void* juzbus_client_t;

/// Opaque handle to a Juzbus service instance
typedef void* juzbus_service_t;

// ============================================================================
// MARK: - Callback Types
// ============================================================================

/// Callback invoked when list of instances is retrieved
/// @param instances Array of instance name strings (NULL-terminated)
/// @param count Number of instances in the array
/// @param user_data User data pointer passed to the list operation
typedef void (*juzbus_list_callback_t)(
    const char** instances,
    size_t count,
    void* user_data
);

/// Callback invoked when a command response is received
/// @param response The response string (NULL if error occurred)
/// @param error Error message (NULL if successful)
/// @param user_data User data pointer passed to the send operation
typedef void (*juzbus_send_callback_t)(
    const char* response,
    const char* error,
    void* user_data
);

/// Callback invoked when a service receives a command
/// @param command The command string received
/// @param out_response Pointer to store the response string (allocated by callback)
/// @param user_data User data pointer passed when service was created
typedef void (*juzbus_command_callback_t)(
    const char* command,
    char** out_response,
    void* user_data
);

// ============================================================================
// MARK: - Client API
// ============================================================================

/// Creates a new Juzbus client instance
/// @return Client handle, or NULL on failure
juzbus_client_t juzbus_client_create(void);

/// Destroys a client instance and releases all resources
/// @param client The client handle to destroy
void juzbus_client_destroy(juzbus_client_t client);

/// Lists all registered instance names
/// @param client The client handle
/// @param callback Callback to invoke with the list of instances
/// @param user_data User data pointer passed to callback
///
/// The callback is invoked asynchronously on a background thread.
/// Strings in the instances array are temporary and valid only during callback.
void juzbus_client_list_instances(
    juzbus_client_t client,
    juzbus_list_callback_t callback,
    void* user_data
);

/// Sends a command to a specific instance
/// @param client The client handle
/// @param instance_name Name of the instance to send command to
/// @param command The command string to send
/// @param callback Callback to invoke with the response
/// @param user_data User data pointer passed to callback
///
/// The callback is invoked asynchronously on a background thread.
/// Response and error strings are temporary and valid only during callback.
void juzbus_client_send_command(
    juzbus_client_t client,
    const char* instance_name,
    const char* command,
    juzbus_send_callback_t callback,
    void* user_data
);

// ============================================================================
// MARK: - Service API
// ============================================================================

/// Creates a new Juzbus service instance (does not start it)
/// @param instance_name Name to register the service under
/// @param callback Callback to invoke when commands are received
/// @param user_data User data pointer passed to command callback
/// @return Service handle, or NULL on failure
juzbus_service_t juzbus_service_create(
    const char* instance_name,
    juzbus_command_callback_t callback,
    void* user_data
);

/// Starts the service and registers it with the directory
/// @param service The service handle
/// @return true if service started successfully, false otherwise
bool juzbus_service_start(juzbus_service_t service);

/// Stops the service and unregisters it from the directory
/// @param service The service handle
void juzbus_service_stop(juzbus_service_t service);

/// Destroys a service instance and releases all resources
/// @param service The service handle to destroy
void juzbus_service_destroy(juzbus_service_t service);

// ============================================================================
// MARK: - Memory Management
// ============================================================================

/// Frees a string allocated by the framework
/// @param str The string to free (may be NULL)
void juzbus_free_string(char* str);

/// Frees an array of strings allocated by the framework
/// @param arr The string array to free (may be NULL)
/// @param count Number of strings in the array
void juzbus_free_string_array(char** arr, size_t count);

// ============================================================================
// MARK: - Utility
// ============================================================================

/// Returns the version of the Juzbus C API
/// @return Version string (statically allocated, do not free)
const char* juzbus_version(void);

#ifdef __cplusplus
}
#endif

#endif // JUZBUS_C_API_H
