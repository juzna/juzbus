#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Callback type for handling commands received by the service
/// @param command The command string received
/// @return Response string to send back to the caller
typedef NSString* _Nonnull (^JuzbusCommandHandler)(NSString* command);

/// Objective-C bridge for Juzbus service operations
///
/// This class wraps NSXPCListener to create an anonymous XPC service
/// and registers it with the directory service.
@interface JuzbusServiceBridge : NSObject

/// Initializes a new service bridge instance
/// @param instanceName The name to register the service under
/// @param commandHandler Block to invoke when commands are received
/// @return Initialized service bridge, or nil on failure
- (nullable instancetype)initWithName:(NSString*)instanceName
                       commandHandler:(JuzbusCommandHandler)commandHandler;

/// Starts the service and registers it with the directory
/// @return YES if service started successfully, NO otherwise
- (BOOL)start;

/// Stops the service and unregisters it from the directory
- (void)stop;

@end

NS_ASSUME_NONNULL_END
