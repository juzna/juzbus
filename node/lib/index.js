const native = require('../build/Release/juzbus.node');

/**
 * Juzbus Client for communicating with XPC services
 */
class Client {
    constructor() {
        this._client = new native.Client();
    }

    /**
     * Lists all registered instance names
     * @returns {Promise<string[]>} Array of instance names
     */
    async listInstances() {
        return new Promise((resolve, reject) => {
            try {
                this._client.listInstances((instances) => {
                    resolve(instances);
                });
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Sends a command to a specific instance
     * @param {string} instanceName - Name of the instance to send the command to
     * @param {string} command - The command string to send
     * @returns {Promise<string>} The response from the instance
     */
    async sendCommand(instanceName, command) {
        return new Promise((resolve, reject) => {
            try {
                this._client.sendCommand(instanceName, command, (response, error) => {
                    if (error) {
                        reject(new Error(error));
                    } else {
                        resolve(response);
                    }
                });
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Closes the client and releases resources
     */
    close() {
        if (this._client) {
            this._client.destroy();
            this._client = null;
        }
    }
}

/**
 * Juzbus Service for registering as an XPC service
 */
class Service {
    constructor(instanceName, commandHandler) {
        if (typeof commandHandler !== 'function') {
            throw new TypeError('commandHandler must be a function');
        }

        // Wrap handler to ensure it always returns a string
        const wrappedHandler = (command) => {
            try {
                const result = commandHandler(command);
                return result !== null && result !== undefined ? String(result) : '';
            } catch (error) {
                return `Error: ${error.message}`;
            }
        };

        this._service = new native.Service(instanceName, wrappedHandler);
    }

    /**
     * Starts the service and registers it with the directory
     * @returns {boolean} true if service started successfully, false otherwise
     */
    start() {
        if (!this._service) {
            throw new Error('Service is not initialized');
        }
        return this._service.start();
    }

    /**
     * Stops the service and unregisters it from the directory
     */
    stop() {
        if (this._service) {
            this._service.stop();
        }
    }
}

module.exports = {
    Client,
    Service,
    version: native.version
};
