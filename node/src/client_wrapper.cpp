#include <node_api.h>
#include "juzbus_c_api.h"
#include "callback_handler.h"
#include <cstring>

namespace juzbus {

class ClientWrapper {
private:
    juzbus_client_t client_;
    napi_ref wrapper_;
    bool destroyed_;

public:
    ClientWrapper(napi_env env) : client_(nullptr), wrapper_(nullptr), destroyed_(false) {
        (void)env; // Unused parameter
        client_ = juzbus_client_create();
    }

    ~ClientWrapper() {
        if (client_ && !destroyed_) {
            juzbus_client_destroy(client_);
            client_ = nullptr;
        }
        // Don't delete reference during shutdown - env might be invalid
        // napi will clean up references automatically
        wrapper_ = nullptr;
    }

    juzbus_client_t GetClient() const { return client_; }

    void SetWrapper(napi_ref ref) { wrapper_ = ref; }

    static napi_value Constructor(napi_env env, napi_callback_info info) {
        napi_value target;
        napi_get_cb_info(env, info, nullptr, nullptr, &target, nullptr);

        // Create native wrapper
        ClientWrapper* wrapper = new ClientWrapper(env);
        if (!wrapper->GetClient()) {
            delete wrapper;
            napi_throw_error(env, nullptr, "Failed to create Juzbus client");
            return nullptr;
        }

        // Wrap native object with JS object
        napi_ref ref;
        napi_wrap(env, target, wrapper, Destructor, nullptr, &ref);
        wrapper->SetWrapper(ref);

        return target;
    }

    static void Destructor(napi_env env, void* nativeObject, void* finalize_hint) {
        ClientWrapper* wrapper = static_cast<ClientWrapper*>(nativeObject);
        delete wrapper;
    }

    static napi_value ListInstances(napi_env env, napi_callback_info info) {
        // Get 'this' and callback parameter
        napi_value jsthis;
        size_t argc = 1;
        napi_value argv[1];
        napi_get_cb_info(env, info, &argc, argv, &jsthis, nullptr);

        if (argc < 1) {
            napi_throw_error(env, nullptr, "listInstances requires a callback argument");
            return nullptr;
        }

        // Check callback is a function
        napi_valuetype callback_type;
        napi_typeof(env, argv[0], &callback_type);
        if (callback_type != napi_function) {
            napi_throw_error(env, nullptr, "Callback must be a function");
            return nullptr;
        }

        // Unwrap native object
        ClientWrapper* wrapper;
        napi_unwrap(env, jsthis, reinterpret_cast<void**>(&wrapper));

        if (!wrapper->GetClient() || wrapper->destroyed_) {
            napi_throw_error(env, nullptr, "Client has been destroyed");
            return nullptr;
        }

        // Create callback handler (will delete itself after callback)
        auto* handler = new ListCallbackHandler(env, argv[0]);

        // Call C API
        juzbus_client_list_instances(
            wrapper->GetClient(),
            ListCallbackHandler::StaticCallback,
            handler
        );

        return nullptr;
    }

    static napi_value SendCommand(napi_env env, napi_callback_info info) {
        // Get 'this', instanceName, command, callback
        napi_value jsthis;
        size_t argc = 3;
        napi_value argv[3];
        napi_get_cb_info(env, info, &argc, argv, &jsthis, nullptr);

        if (argc < 3) {
            napi_throw_error(env, nullptr, "sendCommand requires (instanceName, command, callback)");
            return nullptr;
        }

        // Check callback is a function
        napi_valuetype callback_type;
        napi_typeof(env, argv[2], &callback_type);
        if (callback_type != napi_function) {
            napi_throw_error(env, nullptr, "Callback must be a function");
            return nullptr;
        }

        // Unwrap native object
        ClientWrapper* wrapper;
        napi_unwrap(env, jsthis, reinterpret_cast<void**>(&wrapper));

        if (!wrapper->GetClient() || wrapper->destroyed_) {
            napi_throw_error(env, nullptr, "Client has been destroyed");
            return nullptr;
        }

        // Convert instanceName to C string
        char instance_name[256];
        size_t instance_name_len;
        napi_get_value_string_utf8(env, argv[0], instance_name, sizeof(instance_name), &instance_name_len);

        // Convert command to C string
        char command[1024];
        size_t command_len;
        napi_get_value_string_utf8(env, argv[1], command, sizeof(command), &command_len);

        // Create callback handler (will delete itself after callback)
        auto* handler = new SendCallbackHandler(env, argv[2]);

        // Call C API
        juzbus_client_send_command(
            wrapper->GetClient(),
            instance_name,
            command,
            SendCallbackHandler::StaticCallback,
            handler
        );

        return nullptr;
    }

    static napi_value Destroy(napi_env env, napi_callback_info info) {
        napi_value jsthis;
        napi_get_cb_info(env, info, nullptr, nullptr, &jsthis, nullptr);

        ClientWrapper* wrapper;
        napi_unwrap(env, jsthis, reinterpret_cast<void**>(&wrapper));

        if (wrapper && wrapper->GetClient() && !wrapper->destroyed_) {
            juzbus_client_destroy(wrapper->GetClient());
            wrapper->client_ = nullptr;
            wrapper->destroyed_ = true;
        }

        return nullptr;
    }
};

// Export Client class
napi_value InitClient(napi_env env, napi_value exports) {
    napi_property_descriptor properties[] = {
        {"listInstances", nullptr, ClientWrapper::ListInstances, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sendCommand", nullptr, ClientWrapper::SendCommand, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"destroy", nullptr, ClientWrapper::Destroy, nullptr, nullptr, nullptr, napi_default, nullptr}
    };

    napi_value client_class;
    napi_define_class(
        env,
        "Client",
        NAPI_AUTO_LENGTH,
        ClientWrapper::Constructor,
        nullptr,
        3,
        properties,
        &client_class
    );

    napi_set_named_property(env, exports, "Client", client_class);

    return exports;
}

} // namespace juzbus
