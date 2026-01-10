#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge for Juzbus client operations
///
/// This class wraps NSXPCConnection to the directory service and provides
/// a clean interface for C code to interact with XPC services.
@interface JuzbusClientBridge : NSObject

/// Initializes a new client bridge instance
/// @return Initialized client bridge, or nil on failure
- (nullable instancetype)init;

/// Lists all registered instance names
/// @param callback Block to invoke with the list of instance names
///
/// The callback is invoked on a background queue. The array is guaranteed
/// to be non-nil but may be empty.
- (void)listInstancesWithCallback:(void (^)(NSArray<NSString*>* instances))callback;

/// Sends a command to a specific instance
/// @param command The command string to send
/// @param instanceName Name of the instance to send the command to
/// @param callback Block to invoke with the response or error
///
/// The callback is invoked on a background queue. Either response or error
/// will be non-nil, but not both.
- (void)sendCommand:(NSString*)command
         toInstance:(NSString*)instanceName
           callback:(void (^)(NSString* _Nullable response, NSError* _Nullable error))callback;

/// Invalidates all connections and cleans up resources
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
