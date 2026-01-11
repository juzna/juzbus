#import "JuzbusClientBridge.h"
#import <Foundation/Foundation.h>
#import <os/log.h>

// Mach service name for the directory service
static NSString* const kJuzbusMachServiceName = @"cz.juzna.juzbus";

// Forward declare protocols from JuzbusProtocols Swift module
@protocol DirectoryProtocol <NSObject>
- (void)listInstancesWithReply:(void (^)(NSArray<NSString*>*))reply;
- (void)endpointFor:(NSString*)name reply:(void (^)(NSXPCListenerEndpoint* _Nullable))reply;
- (void)registerWithName:(NSString*)name endpoint:(NSXPCListenerEndpoint*)endpoint reply:(void (^)(BOOL))reply;
- (void)unregisterWithName:(NSString*)name;
@end

@protocol InstanceProtocol <NSObject>
- (void)runCommand:(NSString*)command reply:(void (^)(NSString*))reply;
@end

@interface JuzbusClientBridge ()
@property (nonatomic, strong) NSXPCConnection* directoryConnection;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) os_log_t logger;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSXPCConnection*>* instanceConnections;
@end

@implementation JuzbusClientBridge

- (nullable instancetype)init {
    self = [super init];
    if (self) {
        _logger = os_log_create("cz.juzna.juzbus", "objc-client");
        _queue = dispatch_queue_create("cz.juzna.juzbus.client", DISPATCH_QUEUE_SERIAL);
        _instanceConnections = [NSMutableDictionary dictionary];

        // Create connection to directory service
        _directoryConnection = [[NSXPCConnection alloc] initWithMachServiceName:kJuzbusMachServiceName
                                                                         options:0];
        _directoryConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(DirectoryProtocol)];

        __weak typeof(self) weakSelf = self;
        _directoryConnection.invalidationHandler = ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                os_log_error(strongSelf.logger, "Directory connection invalidated");
            }
        };

        _directoryConnection.interruptionHandler = ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                os_log_info(strongSelf.logger, "Directory connection interrupted");
            }
        };

        [_directoryConnection resume];
        os_log_info(_logger, "Client bridge initialized");
    }
    return self;
}

- (void)dealloc {
    [self invalidate];
}

- (void)listInstancesWithCallback:(void (^)(NSArray<NSString*>*))callback {
    dispatch_async(self.queue, ^{
        id<DirectoryProtocol> directory = [self.directoryConnection remoteObjectProxy];

        [directory listInstancesWithReply:^(NSArray<NSString *> * _Nonnull instances) {
            os_log_debug(self.logger, "Listed %lu instances", (unsigned long)instances.count);
            callback(instances);
        }];
    });
}

- (void)sendCommand:(NSString*)command
         toInstance:(NSString*)instanceName
           callback:(void (^)(NSString* _Nullable, NSError* _Nullable))callback {
    dispatch_async(self.queue, ^{
        // Step 1: Get endpoint for the instance from directory with error handler
        id<DirectoryProtocol> directory = [self.directoryConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
            os_log_error(self.logger, "Error connecting to directory: %{public}@", error.localizedDescription);
            callback(nil, error);
        }];

        [directory endpointFor:instanceName reply:^(NSXPCListenerEndpoint * _Nullable endpoint) {
            if (!endpoint) {
                NSError* error = [NSError errorWithDomain:@"cz.juzna.juzbus"
                                                    code:1
                                                userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Instance not found: %@", instanceName]}];
                callback(nil, error);
                return;
            }

            // Step 2: Get or create connection to the instance
            NSXPCConnection* instanceConnection = self.instanceConnections[instanceName];
            if (!instanceConnection) {
                instanceConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
                instanceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(InstanceProtocol)];

                __weak typeof(self) weakSelf = self;
                instanceConnection.invalidationHandler = ^{
                    typeof(self) strongSelf = weakSelf;
                    if (strongSelf) {
                        dispatch_async(strongSelf.queue, ^{
                            [strongSelf.instanceConnections removeObjectForKey:instanceName];
                            os_log_debug(strongSelf.logger, "Instance connection invalidated: %{public}@", instanceName);
                        });
                    }
                };

                instanceConnection.interruptionHandler = ^{
                    os_log_debug(self.logger, "Instance connection interrupted: %{public}@", instanceName);
                };

                [instanceConnection resume];
                self.instanceConnections[instanceName] = instanceConnection;
                os_log_debug(self.logger, "Created connection to instance: %{public}@", instanceName);
            }

            // Step 3: Send command to the instance with error handler
            id<InstanceProtocol> instance = [instanceConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
                os_log_error(self.logger, "Error sending command to %{public}@: %{public}@", instanceName, error.localizedDescription);
                callback(nil, error);
            }];

            [instance runCommand:command reply:^(NSString * _Nonnull response) {
                os_log_debug(self.logger, "Received response from %{public}@", instanceName);
                callback(response, nil);
            }];
        }];
    });
}

- (void)invalidate {
    dispatch_sync(self.queue, ^{
        // Invalidate all instance connections
        for (NSXPCConnection* connection in self.instanceConnections.allValues) {
            [connection invalidate];
        }
        [self.instanceConnections removeAllObjects];

        // Invalidate directory connection
        [self.directoryConnection invalidate];

        os_log_info(self.logger, "Client bridge invalidated");
    });
}

@end
