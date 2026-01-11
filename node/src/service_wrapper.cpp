#include <node_api.h>
#include "juzbus_c_api.h"
#include <cstring>
#include <string>
#include <mutex>
#include <condition_variable>

namespace juzbus {

// Structure to pass data between C callback and JavaScript
struct CommandCallData {
    std::string command;
    std::string response;
    std::mutex mutex;
    std::condition_variable cv;
    bool completed;

    CommandCallData() : completed(false) {}
};

class ServiceWrapper {
private:
    juzbus_service_t service_;
    napi_env env_;
    napi_ref wrapper_;
    napi_threadsafe_function command_tsfn_;

public:
    ServiceWrapper(napi_env env)
        : service_(nullptr), env_(env), wrapper_(nullptr), command_tsfn_(nullptr) {
    }

    ~ServiceWrapper() {
        if (service_) {
            juzbus_service_destroy(service_);
            service_ = nullptr;
        }
        if (command_tsfn_) {
            napi_release_threadsafe_function(command_tsfn_, napi_tsfn_release);
            command_tsfn_ = nullptr;
        }
        if (wrapper_) {
            napi_delete_reference(env_, wrapper_);
            wrapper_ = nullptr;
        }
    }

    juzbus_service_t GetService() const { return service_; }
    void SetWrapper(napi_ref ref) { wrapper_ = ref; }

    // Static C callback invoked when commands are received
    static void StaticCommandCallback(
        const char* command,
        char** out_response,
        void* user_data
    ) {
        ServiceWrapper* wrapper = static_cast<ServiceWrapper*>(user_data);

        // Create data structure to communicate with JavaScript
        CommandCallData* data = new CommandCallData();
        data->command = command ? command : "";

        // Call into JavaScript via threadsafe function
        napi_status status = napi_call_threadsafe_function(
            wrapper->command_tsfn_,
            data,
            napi_tsfn_blocking
        );

        if (status != napi_ok) {
            *out_response = strdup("Error: Failed to call JavaScript handler");
            delete data;
            return;
        }

        // Wait for JavaScript to provide response
        {
            std::unique_lock<std::mutex> lock(data->mutex);
            data->cv.wait(lock, [data] { return data->completed; });
        }

        // Copy response for C caller
        if (!data->response.empty()) {
            *out_response = strdup(data->response.c_str());
        } else {
            *out_response = strdup("");
        }

        delete data;
    }

    // Helper to handle Promise resolution
    static void HandlePromiseResolution(
        napi_env env,
        napi_value promise,
        CommandCallData* call_data
    ) {
        // Create a promise chain to handle the result
        napi_value then_func;
        napi_get_named_property(env, promise, "then", &then_func);

        napi_value catch_func;
        napi_get_named_property(env, promise, "catch", &catch_func);

        // Create callback for successful resolution
        napi_value then_callback;
        napi_create_function(env, "then", NAPI_AUTO_LENGTH,
            [](napi_env env, napi_callback_info info) -> napi_value {
                size_t argc = 1;
                napi_value argv[1];
                void* data;
                napi_get_cb_info(env, info, &argc, argv, nullptr, &data);

                CommandCallData* call_data = static_cast<CommandCallData*>(data);

                // Convert resolved value to string
                if (argc > 0) {
                    napi_valuetype type;
                    napi_typeof(env, argv[0], &type);

                    if (type == napi_string) {
                        size_t length;
                        napi_get_value_string_utf8(env, argv[0], nullptr, 0, &length);
                        char* buffer = new char[length + 1];
                        napi_get_value_string_utf8(env, argv[0], buffer, length + 1, nullptr);
                        call_data->response = std::string(buffer);
                        delete[] buffer;
                    } else {
                        call_data->response = "Error: Handler must return a string";
                    }
                }

                // Signal completion
                {
                    std::lock_guard<std::mutex> lock(call_data->mutex);
                    call_data->completed = true;
                }
                call_data->cv.notify_one();

                return nullptr;
            }, call_data, &then_callback);

        // Create callback for rejection
        napi_value catch_callback;
        napi_create_function(env, "catch", NAPI_AUTO_LENGTH,
            [](napi_env env, napi_callback_info info) -> napi_value {
                size_t argc = 1;
                napi_value argv[1];
                void* data;
                napi_get_cb_info(env, info, &argc, argv, nullptr, &data);

                CommandCallData* call_data = static_cast<CommandCallData*>(data);

                // Convert error to string
                if (argc > 0) {
                    napi_value message_val;
                    napi_get_named_property(env, argv[0], "message", &message_val);

                    size_t length;
                    napi_get_value_string_utf8(env, message_val, nullptr, 0, &length);
                    char* buffer = new char[length + 1];
                    napi_get_value_string_utf8(env, message_val, buffer, length + 1, nullptr);
                    call_data->response = "Error: " + std::string(buffer);
                    delete[] buffer;
                } else {
                    call_data->response = "Error: Handler threw an exception";
                }

                // Signal completion
                {
                    std::lock_guard<std::mutex> lock(call_data->mutex);
                    call_data->completed = true;
                }
                call_data->cv.notify_one();

                return nullptr;
            }, call_data, &catch_callback);

        // Chain the callbacks
        napi_value then_result;
        napi_call_function(env, promise, then_func, 1, &then_callback, &then_result);

        napi_value catch_result;
        napi_call_function(env, then_result, catch_func, 1, &catch_callback, &catch_result);
    }

    // JavaScript callback handler
    static void CommandHandlerCallback(
        napi_env env,
        napi_value js_callback,
        void* context,
        void* data
    ) {
        if (data == nullptr) return;

        CommandCallData* call_data = static_cast<CommandCallData*>(data);

        // Convert command to JS string
        napi_value js_command;
        napi_create_string_utf8(env, call_data->command.c_str(), NAPI_AUTO_LENGTH, &js_command);

        // Call JavaScript handler
        napi_value global;
        napi_get_global(env, &global);

        napi_value js_response;
        napi_status status = napi_call_function(env, global, js_callback, 1, &js_command, &js_response);

        if (status != napi_ok) {
            call_data->response = "Error: JavaScript handler threw an exception";
            std::lock_guard<std::mutex> lock(call_data->mutex);
            call_data->completed = true;
            call_data->cv.notify_one();
            return;
        }

        // Check if result is a Promise
        bool is_promise = false;
        napi_is_promise(env, js_response, &is_promise);

        if (is_promise) {
            // Handle async (Promise-based) response
            HandlePromiseResolution(env, js_response, call_data);
        } else {
            // Handle synchronous response
            napi_valuetype type;
            napi_typeof(env, js_response, &type);

            if (type == napi_string) {
                size_t length;
                napi_get_value_string_utf8(env, js_response, nullptr, 0, &length);
                char* buffer = new char[length + 1];
                napi_get_value_string_utf8(env, js_response, buffer, length + 1, nullptr);
                call_data->response = std::string(buffer);
                delete[] buffer;
            } else {
                call_data->response = "Error: Handler must return a string or Promise<string>";
            }

            // Signal completion
            {
                std::lock_guard<std::mutex> lock(call_data->mutex);
                call_data->completed = true;
            }
            call_data->cv.notify_one();
        }
    }

    static napi_value Constructor(napi_env env, napi_callback_info info) {
        napi_value target;
        size_t argc = 2;
        napi_value argv[2];
        napi_get_cb_info(env, info, &argc, argv, &target, nullptr);

        if (argc < 2) {
            napi_throw_error(env, nullptr, "Service constructor requires (instanceName, commandHandler)");
            return nullptr;
        }

        // Check command handler is a function
        napi_valuetype handler_type;
        napi_typeof(env, argv[1], &handler_type);
        if (handler_type != napi_function) {
            napi_throw_error(env, nullptr, "commandHandler must be a function");
            return nullptr;
        }

        // Create native wrapper
        ServiceWrapper* wrapper = new ServiceWrapper(env);

        // Convert instance name to C string
        char instance_name[256];
        size_t instance_name_len;
        napi_get_value_string_utf8(env, argv[0], instance_name, sizeof(instance_name), &instance_name_len);

        // Create threadsafe function for command handler
        napi_value async_name;
        napi_create_string_utf8(env, "CommandHandler", NAPI_AUTO_LENGTH, &async_name);

        napi_status status = napi_create_threadsafe_function(
            env,
            argv[1],         // JS callback
            nullptr,         // async_resource
            async_name,      // async_resource_name
            0,               // max_queue_size (0 = unlimited)
            1,               // initial_thread_count
            nullptr,         // thread_finalize_data
            nullptr,         // thread_finalize_cb
            wrapper,         // context
            CommandHandlerCallback,  // call_js_cb
            &wrapper->command_tsfn_
        );

        if (status != napi_ok) {
            delete wrapper;
            napi_throw_error(env, nullptr, "Failed to create threadsafe function");
            return nullptr;
        }

        // Create C service
        wrapper->service_ = juzbus_service_create(
            instance_name,
            StaticCommandCallback,
            wrapper  // user_data points to ServiceWrapper
        );

        if (!wrapper->service_) {
            delete wrapper;
            napi_throw_error(env, nullptr, "Failed to create Juzbus service");
            return nullptr;
        }

        // Wrap native object with JS object
        napi_ref ref;
        napi_wrap(env, target, wrapper, Destructor, nullptr, &ref);
        wrapper->SetWrapper(ref);

        return target;
    }

    static void Destructor(napi_env env, void* nativeObject, void* finalize_hint) {
        ServiceWrapper* wrapper = static_cast<ServiceWrapper*>(nativeObject);
        delete wrapper;
    }

    static napi_value Start(napi_env env, napi_callback_info info) {
        napi_value jsthis;
        napi_get_cb_info(env, info, nullptr, nullptr, &jsthis, nullptr);

        ServiceWrapper* wrapper;
        napi_unwrap(env, jsthis, reinterpret_cast<void**>(&wrapper));

        if (!wrapper->GetService()) {
            napi_throw_error(env, nullptr, "Service is not initialized");
            return nullptr;
        }

        bool success = juzbus_service_start(wrapper->GetService());

        napi_value result;
        napi_get_boolean(env, success, &result);
        return result;
    }

    static napi_value Stop(napi_env env, napi_callback_info info) {
        napi_value jsthis;
        napi_get_cb_info(env, info, nullptr, nullptr, &jsthis, nullptr);

        ServiceWrapper* wrapper;
        napi_unwrap(env, jsthis, reinterpret_cast<void**>(&wrapper));

        if (wrapper && wrapper->GetService()) {
            juzbus_service_stop(wrapper->GetService());
        }

        return nullptr;
    }
};

// Export Service class
napi_value InitService(napi_env env, napi_value exports) {
    napi_property_descriptor properties[] = {
        {"start", nullptr, ServiceWrapper::Start, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stop", nullptr, ServiceWrapper::Stop, nullptr, nullptr, nullptr, napi_default, nullptr}
    };

    napi_value service_class;
    napi_define_class(
        env,
        "Service",
        NAPI_AUTO_LENGTH,
        ServiceWrapper::Constructor,
        nullptr,
        2,
        properties,
        &service_class
    );

    napi_set_named_property(env, exports, "Service", service_class);

    return exports;
}

} // namespace juzbus
