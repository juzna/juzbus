#!/usr/bin/env node

const juzbus = require('../lib/index.js');

// Get instance name from command line or use default
const instanceName = process.argv[2] || 'node-service';

console.log('Juzbus Node.js Service Example');
console.log('===============================\n');
console.log(`Library version: ${juzbus.version}`);
console.log(`Starting service as: ${instanceName}\n`);

// Define command handler
function handleCommand(command) {
    console.log(`[${new Date().toISOString()}] Received command: ${command}`);

    const parts = command.split(' ');
    const cmd = parts[0];
    const args = parts.slice(1).join(' ');

    let response;

    switch (cmd) {
        case 'ping':
            response = 'pong';
            break;

        case 'get-name':
            response = instanceName;
            break;

        case 'get-uptime':
            response = `${Math.floor(process.uptime())} seconds`;
            break;

        case 'echo':
            response = args || '';
            break;

        case 'node-version':
            response = process.version;
            break;

        case 'platform':
            response = `${process.platform} ${process.arch}`;
            break;

        case 'memory':
            const mem = process.memoryUsage();
            response = `RSS: ${Math.round(mem.rss / 1024 / 1024)}MB, Heap: ${Math.round(mem.heapUsed / 1024 / 1024)}MB`;
            break;

        case 'help':
            response = 'Available commands: ping, get-name, get-uptime, echo, node-version, platform, memory, help';
            break;

        default:
            response = `Unknown command: ${cmd}. Try 'help' for available commands.`;
            break;
    }

    console.log(`[${new Date().toISOString()}] Sending response: ${response}`);
    return response;
}

// Create and start service
const service = new juzbus.Service(instanceName, handleCommand);

try {
    const success = service.start();

    if (!success) {
        console.error('\n✗ Failed to start service');
        console.error('  This usually means:');
        console.error('    - The instance name is already taken');
        console.error('    - The directory service is not running');
        console.error('\n  Try a different instance name:');
        console.error(`    node examples/service.js my-unique-name`);
        process.exit(1);
    }

    console.log(`✓ Service '${instanceName}' is running and registered with the directory`);
    console.log('\nYou can now send commands to this service:');
    console.log(`  juzbus send ${instanceName} ping`);
    console.log(`  node examples/client.js`);
    console.log('\nPress Ctrl+C to stop the service.\n');

    // Graceful shutdown
    process.on('SIGINT', () => {
        console.log('\n\nShutting down...');
        service.stop();
        console.log('Service stopped.');
        process.exit(0);
    });

    process.on('SIGTERM', () => {
        service.stop();
        process.exit(0);
    });

    // Keep process alive
    setInterval(() => {}, 1000);

} catch (error) {
    console.error('\n✗ Error starting service:', error.message);
    process.exit(1);
}
