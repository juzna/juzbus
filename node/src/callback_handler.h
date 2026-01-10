#ifndef JUZBUS_CALLBACK_HANDLER_H
#define JUZBUS_CALLBACK_HANDLER_H

#include <node_api.h>
#include <string>
#include <vector>

namespace juzbus {

// Base class for threadsafe callback handlers
class CallbackHandler {
public:
    CallbackHandler(napi_env env, napi_value callback);
    virtual ~CallbackHandler();

    // Get the threadsafe function handle
    napi_threadsafe_function GetTSFN() const { return tsfn_; }

protected:
    napi_threadsafe_function tsfn_;

    // Static callback for napi_create_threadsafe_function
    static void CallJs(napi_env env, napi_value js_callback, void* context, void* data);

    // Virtual method to be implemented by subclasses
    virtual void HandleCallback(napi_env env, napi_value js_callback, void* data) = 0;
};

// Handler for listInstances callback
class ListCallbackHandler : public CallbackHandler {
public:
    struct CallbackData {
        std::vector<std::string> instances;
    };

    ListCallbackHandler(napi_env env, napi_value callback);

    // Static C callback for juzbus_client_list_instances
    static void StaticCallback(const char** instances, size_t count, void* user_data);

protected:
    void HandleCallback(napi_env env, napi_value js_callback, void* data) override;
};

// Handler for sendCommand callback
class SendCallbackHandler : public CallbackHandler {
public:
    struct CallbackData {
        std::string response;
        std::string error;
    };

    SendCallbackHandler(napi_env env, napi_value callback);

    // Static C callback for juzbus_client_send_command
    static void StaticCallback(const char* response, const char* error, void* user_data);

protected:
    void HandleCallback(napi_env env, napi_value js_callback, void* data) override;
};

} // namespace juzbus

#endif // JUZBUS_CALLBACK_HANDLER_H
