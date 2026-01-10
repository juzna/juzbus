#import "JuzbusServiceBridge.h"
#import <Foundation/Foundation.h>
#import <os/log.h>

// Mach service name for the directory service
static NSString* const kJuzbusMachServiceName = @"cz.juzna.juzbus";
static const NSTimeInterval kRegistrationTimeout = 10.0;

// Forward declare protocols
@protocol DirectoryProtocol <NSObject>
- (void)listInstancesWithReply:(void (^)(NSArray<NSString*>*))reply;
- (void)endpointFor:(NSString*)name reply:(void (^)(NSXPCListenerEndpoint* _Nullable))reply;
- (void)registerWithName:(NSString*)name endpoint:(NSXPCListenerEndpoint*)endpoint reply:(void (^)(BOOL))reply;
- (void)unregisterWithName:(NSString*)name;
@end

@protocol InstanceProtocol <NSObject>
- (void)runCommand:(NSString*)command reply:(void (^)(NSString*))reply;
@end

@interface JuzbusServiceBridge () <NSXPCListenerDelegate, InstanceProtocol>
@property (nonatomic, strong) NSString* instanceName;
@property (nonatomic, copy) JuzbusCommandHandler commandHandler;
@property (nonatomic, strong) NSXPCListener* listener;
@property (nonatomic, strong) NSXPCConnection* directoryConnection;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) os_log_t logger;
@property (nonatomic, assign) BOOL isRunning;
@end

@implementation JuzbusServiceBridge

- (nullable instancetype)initWithName:(NSString*)instanceName
                       commandHandler:(JuzbusCommandHandler)commandHandler {
    self = [super init];
    if (self) {
        _instanceName = [instanceName copy];
        _commandHandler = [commandHandler copy];
        _logger = os_log_create("cz.juzna.juzbus", "objc-service");
        _queue = dispatch_queue_create("cz.juzna.juzbus.service", DISPATCH_QUEUE_SERIAL);
        _isRunning = NO;

        // Create anonymous XPC listener
        _listener = [NSXPCListener anonymousListener];
        _listener.delegate = self;

        os_log_info(_logger, "Service bridge initialized for: %{public}@", instanceName);
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (BOOL)start {
    __block BOOL success = NO;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    dispatch_async(self.queue, ^{
        if (self.isRunning) {
            os_log_info(self.logger, "Service already running");
            success = YES;
            dispatch_semaphore_signal(semaphore);
            return;
        }

        // Start the anonymous listener
        [self.listener resume];
        os_log_info(self.logger, "Started anonymous XPC listener");

        // Connect to the directory service
        self.directoryConnection = [[NSXPCConnection alloc] initWithMachServiceName:kJuzbusMachServiceName
                                                                             options:0];
        self.directoryConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(DirectoryProtocol)];

        __weak typeof(self) weakSelf = self;
        self.directoryConnection.invalidationHandler = ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                os_log_error(strongSelf.logger, "Directory connection invalidated");
            }
        };

        self.directoryConnection.interruptionHandler = ^{
            typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                os_log_info(strongSelf.logger, "Directory connection interrupted");
            }
        };

        [self.directoryConnection resume];

        // Register with the directory
        id<DirectoryProtocol> directory = [self.directoryConnection remoteObjectProxy];

        [directory registerWithName:self.instanceName
                           endpoint:self.listener.endpoint
                              reply:^(BOOL registered) {
            if (registered) {
                os_log_info(self.logger, "Successfully registered with directory as: %{public}@", self.instanceName);
                self.isRunning = YES;
                success = YES;
            } else {
                os_log_error(self.logger, "Failed to register with directory (name may be taken)");
                success = NO;
            }
            dispatch_semaphore_signal(semaphore);
        }];
    });

    // Wait for registration to complete
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kRegistrationTimeout * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        os_log_error(self.logger, "Registration timed out");
        return NO;
    }

    return success;
}

- (void)stop {
    dispatch_sync(self.queue, ^{
        if (!self.isRunning) {
            return;
        }

        os_log_info(self.logger, "Stopping service: %{public}@", self.instanceName);

        // Unregister from directory
        if (self.directoryConnection) {
            id<DirectoryProtocol> directory = [self.directoryConnection remoteObjectProxy];
            [directory unregisterWithName:self.instanceName];
            [self.directoryConnection invalidate];
            self.directoryConnection = nil;
        }

        // Stop listener
        if (self.listener) {
            [self.listener invalidate];
            self.listener = nil;
        }

        self.isRunning = NO;
        os_log_info(self.logger, "Service stopped");
    });
}

// MARK: - InstanceProtocol

- (void)runCommand:(NSString*)command reply:(void (^)(NSString*))reply {
    os_log_debug(self.logger, "Received command: %{public}@", command);

    // Call the command handler
    NSString* response = self.commandHandler(command);

    os_log_debug(self.logger, "Sending response: %{public}@", response);
    reply(response);
}

// MARK: - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener*)listener shouldAcceptNewConnection:(NSXPCConnection*)newConnection {
    os_log_info(self.logger, "Accepting XPC connection from PID %d", newConnection.processIdentifier);

    // Configure the connection
    NSXPCInterface* interface = [NSXPCInterface interfaceWithProtocol:@protocol(InstanceProtocol)];
    newConnection.exportedInterface = interface;
    newConnection.exportedObject = self;

    __weak typeof(self) weakSelf = self;
    newConnection.invalidationHandler = ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            os_log_debug(strongSelf.logger, "Client connection invalidated");
        }
    };

    newConnection.interruptionHandler = ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            os_log_debug(strongSelf.logger, "Client connection interrupted");
        }
    };

    [newConnection resume];
    return YES;
}

@end
