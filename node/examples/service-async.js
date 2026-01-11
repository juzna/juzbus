#!/usr/bin/env node

const juzbus = require('../lib/index.js');

// Get instance name from command line or use default
const instanceName = process.argv[2] || 'async-service';

console.log('Juzbus Async Service Example');
console.log('============================\n');
console.log(`Library version: ${juzbus.version}`);
console.log(`Starting async service as: ${instanceName}\n`);

// Simulate async operations
async function fetchData(delay) {
    return new Promise(resolve => {
        setTimeout(() => {
            resolve(`Data fetched after ${delay}ms`);
        }, delay);
    });
}

async function processCommand(cmd) {
    // Simulate async processing
    await new Promise(resolve => setTimeout(resolve, 100));
    return `Processed: ${cmd}`;
}

// Define ASYNC command handler
async function handleCommand(command) {
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

        case 'async-fetch':
            // Demonstrate async operation
            const delay = parseInt(args) || 500;
            response = await fetchData(delay);
            break;

        case 'async-process':
            // Demonstrate async processing
            response = await processCommand(args || 'default');
            break;

        case 'sleep':
            // Demonstrate long-running async operation
            const sleepTime = parseInt(args) || 1000;
            await new Promise(resolve => setTimeout(resolve, sleepTime));
            response = `Slept for ${sleepTime}ms`;
            break;

        case 'node-version':
            response = process.version;
            break;

        case 'help':
            response = 'Available commands: ping, get-name, get-uptime, echo, async-fetch, async-process, sleep, node-version, help';
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
        console.error(`    node examples/service-async.js my-unique-name`);
        process.exit(1);
    }

    console.log(`✓ Async service '${instanceName}' is running and registered with the directory`);
    console.log('\nYou can now send commands to this service:');
    console.log(`  juzbus exec ${instanceName} ping`);
    console.log(`  juzbus exec ${instanceName} "async-fetch 1000"`);
    console.log(`  juzbus exec ${instanceName} "async-process test"`);
    console.log(`  juzbus exec ${instanceName} "sleep 2000"`);
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
