#include "callback_handler.h"
#include <cstring>

namespace juzbus {

// ============================================================================
// CallbackHandler Base Class
// ============================================================================

CallbackHandler::CallbackHandler(napi_env env, napi_value callback) {
    napi_value async_name;
    napi_create_string_utf8(env, "JuzbusCallback", NAPI_AUTO_LENGTH, &async_name);

    napi_create_threadsafe_function(
        env,
        callback,
        nullptr,
        async_name,
        0,           // max_queue_size (0 = unlimited)
        1,           // initial_thread_count
        nullptr,     // thread_finalize_data
        nullptr,     // thread_finalize_cb
        this,        // context (pointer to this handler)
        CallJs,      // call_js_cb
        &tsfn_
    );
}

CallbackHandler::~CallbackHandler() {
    if (tsfn_) {
        napi_release_threadsafe_function(tsfn_, napi_tsfn_release);
    }
}

void CallbackHandler::CallJs(napi_env env, napi_value js_callback, void* context, void* data) {
    if (context == nullptr || data == nullptr) return;

    CallbackHandler* handler = static_cast<CallbackHandler*>(context);
    handler->HandleCallback(env, js_callback, data);
}

// ============================================================================
// ListCallbackHandler
// ============================================================================

ListCallbackHandler::ListCallbackHandler(napi_env env, napi_value callback)
    : CallbackHandler(env, callback) {
}

void ListCallbackHandler::StaticCallback(const char** instances, size_t count, void* user_data) {
    if (user_data == nullptr) return;

    ListCallbackHandler* handler = static_cast<ListCallbackHandler*>(user_data);

    // Copy strings to C++ vector
    auto* data = new CallbackData();
    data->instances.reserve(count);

    for (size_t i = 0; i < count; i++) {
        if (instances[i]) {
            data->instances.push_back(std::string(instances[i]));
        }
    }

    // Queue the call to JavaScript
    napi_call_threadsafe_function(
        handler->GetTSFN(),
        data,
        napi_tsfn_blocking
    );
}

void ListCallbackHandler::HandleCallback(napi_env env, napi_value js_callback, void* data) {
    auto* callback_data = static_cast<CallbackData*>(data);

    // Create JavaScript array
    napi_value js_array;
    napi_create_array_with_length(env, callback_data->instances.size(), &js_array);

    for (size_t i = 0; i < callback_data->instances.size(); i++) {
        napi_value js_string;
        napi_create_string_utf8(env, callback_data->instances[i].c_str(), NAPI_AUTO_LENGTH, &js_string);
        napi_set_element(env, js_array, i, js_string);
    }

    // Call JavaScript callback with array
    napi_value global;
    napi_get_global(env, &global);

    napi_value result;
    napi_call_function(env, global, js_callback, 1, &js_array, &result);

    // Cleanup
    delete callback_data;
    delete this;  // Handler is single-use
}

// ============================================================================
// SendCallbackHandler
// ============================================================================

SendCallbackHandler::SendCallbackHandler(napi_env env, napi_value callback)
    : CallbackHandler(env, callback) {
}

void SendCallbackHandler::StaticCallback(const char* response, const char* error, void* user_data) {
    if (user_data == nullptr) return;

    SendCallbackHandler* handler = static_cast<SendCallbackHandler*>(user_data);

    // Copy strings to C++ struct
    auto* data = new CallbackData();
    if (response) {
        data->response = std::string(response);
    }
    if (error) {
        data->error = std::string(error);
    }

    // Queue the call to JavaScript
    napi_call_threadsafe_function(
        handler->GetTSFN(),
        data,
        napi_tsfn_blocking
    );
}

void SendCallbackHandler::HandleCallback(napi_env env, napi_value js_callback, void* data) {
    auto* callback_data = static_cast<CallbackData*>(data);

    // Create JavaScript values
    napi_value js_response;
    napi_value js_error;

    if (!callback_data->error.empty()) {
        // Error case: response is null, error is string
        napi_get_null(env, &js_response);
        napi_create_string_utf8(env, callback_data->error.c_str(), NAPI_AUTO_LENGTH, &js_error);
    } else {
        // Success case: response is string, error is null
        napi_create_string_utf8(env, callback_data->response.c_str(), NAPI_AUTO_LENGTH, &js_response);
        napi_get_null(env, &js_error);
    }

    // Call JavaScript callback with (response, error)
    napi_value global;
    napi_get_global(env, &global);

    napi_value args[] = {js_response, js_error};
    napi_value result;
    napi_call_function(env, global, js_callback, 2, args, &result);

    // Cleanup
    delete callback_data;
    delete this;  // Handler is single-use
}

} // namespace juzbus
