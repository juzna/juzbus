/**
 * Juzbus Client for communicating with XPC services
 */
export declare class Client {
    /**
     * Creates a new Juzbus client instance
     */
    constructor();

    /**
     * Lists all registered instance names
     * @returns Promise that resolves to an array of instance names
     */
    listInstances(): Promise<string[]>;

    /**
     * Sends a command to a specific instance
     * @param instanceName - Name of the instance to send the command to
     * @param command - The command string to send
     * @returns Promise that resolves to the response from the instance
     */
    sendCommand(instanceName: string, command: string): Promise<string>;

    /**
     * Closes the client and releases resources
     */
    close(): void;
}

/**
 * Command handler function type for services
 * @param command - The command string received
 * @returns Response string to send back to the caller
 */
export type CommandHandler = (command: string) => string;

/**
 * Juzbus Service for registering as an XPC service
 */
export declare class Service {
    /**
     * Creates a new Juzbus service instance
     * @param instanceName - Name to register the service under
     * @param commandHandler - Function to invoke when commands are received
     */
    constructor(instanceName: string, commandHandler: CommandHandler);

    /**
     * Starts the service and registers it with the directory
     * @returns true if service started successfully, false otherwise
     */
    start(): boolean;

    /**
     * Stops the service and unregisters it from the directory
     */
    stop(): void;
}

/**
 * Version of the Juzbus native library
 */
export declare const version: string;
