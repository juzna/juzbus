#import "juzbus_c_api.h"
#import "JuzbusClientBridge.h"
#import "JuzbusServiceBridge.h"
#import <Foundation/Foundation.h>
#import <os/log.h>

// ============================================================================
// MARK: - Internal Structures
// ============================================================================

struct juzbus_client {
    JuzbusClientBridge* __strong bridge;
    os_log_t logger;
};

struct juzbus_service {
    JuzbusServiceBridge* __strong bridge;
    os_log_t logger;
    juzbus_command_callback_t callback;
    void* user_data;
};

// ============================================================================
// MARK: - Helper Functions
// ============================================================================

/// Converts NSString to malloc'd C string (caller must free)
static char* nsstring_to_cstring(NSString* str) {
    if (!str) return NULL;
    const char* utf8 = [str UTF8String];
    if (!utf8) return NULL;
    return strdup(utf8);
}

/// Converts C string to NSString
static NSString* cstring_to_nsstring(const char* str) {
    if (!str) return nil;
    return [NSString stringWithUTF8String:str];
}

/// Converts NSArray<NSString*> to malloc'd char** array (caller must free)
static char** nsarray_to_cstring_array(NSArray<NSString*>* array, size_t* out_count) {
    if (!array) {
        *out_count = 0;
        return NULL;
    }

    size_t count = array.count;
    *out_count = count;

    if (count == 0) {
        return NULL;
    }

    char** c_array = (char**)malloc(count * sizeof(char*));
    if (!c_array) {
        *out_count = 0;
        return NULL;
    }

    for (size_t i = 0; i < count; i++) {
        c_array[i] = nsstring_to_cstring(array[i]);
        if (!c_array[i]) {
            // Cleanup on failure
            for (size_t j = 0; j < i; j++) {
                free(c_array[j]);
            }
            free(c_array);
            *out_count = 0;
            return NULL;
        }
    }

    return c_array;
}

// ============================================================================
// MARK: - Client API Implementation
// ============================================================================

juzbus_client_t juzbus_client_create(void) {
    struct juzbus_client* client = (struct juzbus_client*)calloc(1, sizeof(struct juzbus_client));
    if (!client) return NULL;

    client->logger = os_log_create("cz.juzna.juzbus", "c-api");
    client->bridge = [[JuzbusClientBridge alloc] init];

    if (!client->bridge) {
        os_log_error(client->logger, "Failed to create client bridge");
        free(client);
        return NULL;
    }

    os_log_info(client->logger, "Client created");
    return client;
}

void juzbus_client_destroy(juzbus_client_t client) {
    if (!client) return;

    struct juzbus_client* c = (struct juzbus_client*)client;
    os_log_info(c->logger, "Destroying client");

    [c->bridge invalidate];
    c->bridge = nil;

    free(c);
}

void juzbus_client_list_instances(
    juzbus_client_t client,
    juzbus_list_callback_t callback,
    void* user_data
) {
    if (!client || !callback) return;

    struct juzbus_client* c = (struct juzbus_client*)client;

    [c->bridge listInstancesWithCallback:^(NSArray<NSString *> * _Nonnull instances) {
        // Convert NSArray to C string array
        size_t count;
        char** c_instances = nsarray_to_cstring_array(instances, &count);

        // Invoke callback with temporary C strings
        // Note: We pass the malloc'd array, but the callback should not free it
        // The strings are only valid during the callback
        callback((const char**)c_instances, count, user_data);

        // Free the C string array after callback returns
        if (c_instances) {
            for (size_t i = 0; i < count; i++) {
                free(c_instances[i]);
            }
            free(c_instances);
        }
    }];
}

void juzbus_client_send_command(
    juzbus_client_t client,
    const char* instance_name,
    const char* command,
    juzbus_send_callback_t callback,
    void* user_data
) {
    if (!client || !instance_name || !command || !callback) return;

    struct juzbus_client* c = (struct juzbus_client*)client;

    NSString* nsInstanceName = cstring_to_nsstring(instance_name);
    NSString* nsCommand = cstring_to_nsstring(command);

    if (!nsInstanceName || !nsCommand) {
        callback(NULL, "Invalid instance name or command", user_data);
        return;
    }

    [c->bridge sendCommand:nsCommand
                toInstance:nsInstanceName
                  callback:^(NSString * _Nullable response, NSError * _Nullable error) {
        // Convert response/error to C strings (temporary, valid only during callback)
        char* c_response = NULL;
        char* c_error = NULL;

        if (error) {
            c_error = nsstring_to_cstring([error localizedDescription]);
        } else {
            c_response = nsstring_to_cstring(response);
        }

        // Invoke callback
        callback(c_response, c_error, user_data);

        // Free temporary strings
        if (c_response) free(c_response);
        if (c_error) free(c_error);
    }];
}

// ============================================================================
// MARK: - Service API Implementation
// ============================================================================

juzbus_service_t juzbus_service_create(
    const char* instance_name,
    juzbus_command_callback_t callback,
    void* user_data
) {
    if (!instance_name || !callback) return NULL;

    struct juzbus_service* service = (struct juzbus_service*)calloc(1, sizeof(struct juzbus_service));
    if (!service) return NULL;

    service->logger = os_log_create("cz.juzna.juzbus", "c-api-service");
    service->callback = callback;
    service->user_data = user_data;

    NSString* nsInstanceName = cstring_to_nsstring(instance_name);
    if (!nsInstanceName) {
        os_log_error(service->logger, "Invalid instance name");
        free(service);
        return NULL;
    }

    // Create command handler that calls back to C
    JuzbusCommandHandler handler = ^NSString*(NSString* command) {
        // Convert command to C string
        char* c_command = nsstring_to_cstring(command);
        if (!c_command) {
            return @"Error: Invalid command";
        }

        // Call C callback
        char* c_response = NULL;
        service->callback(c_command, &c_response, service->user_data);

        // Convert response to NSString
        NSString* response = @"";
        if (c_response) {
            response = cstring_to_nsstring(c_response);
            if (!response) {
                response = @"";
            }
            free(c_response);
        }

        free(c_command);
        return response;
    };

    // Create service bridge
    service->bridge = [[JuzbusServiceBridge alloc] initWithName:nsInstanceName
                                                 commandHandler:handler];

    if (!service->bridge) {
        os_log_error(service->logger, "Failed to create service bridge");
        free(service);
        return NULL;
    }

    os_log_info(service->logger, "Service created: %{public}@", nsInstanceName);
    return service;
}

bool juzbus_service_start(juzbus_service_t service) {
    if (!service) return false;

    struct juzbus_service* s = (struct juzbus_service*)service;
    BOOL success = [s->bridge start];

    if (success) {
        os_log_info(s->logger, "Service started successfully");
    } else {
        os_log_error(s->logger, "Failed to start service");
    }

    return success;
}

void juzbus_service_stop(juzbus_service_t service) {
    if (!service) return;

    struct juzbus_service* s = (struct juzbus_service*)service;
    os_log_info(s->logger, "Stopping service");
    [s->bridge stop];
}

void juzbus_service_destroy(juzbus_service_t service) {
    if (!service) return;

    struct juzbus_service* s = (struct juzbus_service*)service;
    os_log_info(s->logger, "Destroying service");

    [s->bridge stop];
    s->bridge = nil;

    free(s);
}

// ============================================================================
// MARK: - Memory Management
// ============================================================================

void juzbus_free_string(char* str) {
    if (str) {
        free(str);
    }
}

void juzbus_free_string_array(char** arr, size_t count) {
    if (!arr) return;

    for (size_t i = 0; i < count; i++) {
        if (arr[i]) {
            free(arr[i]);
        }
    }
    free(arr);
}

// ============================================================================
// MARK: - Utility
// ============================================================================

const char* juzbus_version(void) {
    return "0.1.0";
}
