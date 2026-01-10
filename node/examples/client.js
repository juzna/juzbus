#!/usr/bin/env node

const juzbus = require('../lib/index.js');

async function main() {
    console.log('Juzbus Node.js Client Example');
    console.log('==============================\n');
    console.log(`Library version: ${juzbus.version}\n`);

    const client = new juzbus.Client();

    try {
        // List all registered instances
        console.log('Listing registered instances...');
        const instances = await client.listInstances();

        if (instances.length === 0) {
            console.log('No instances found.');
            console.log('\nTo test the client, start a Swift service first:');
            console.log('  juzbus-example alice');
            console.log('Then run this example again.');
            return;
        }

        console.log(`Found ${instances.length} instance(s):`);
        instances.forEach((name, index) => {
            console.log(`  ${index + 1}. ${name}`);
        });

        // Send commands to the first instance
        const instanceName = instances[0];
        console.log(`\n--- Testing commands with '${instanceName}' ---\n`);

        // Test 1: ping
        console.log('Sending: ping');
        const pingResponse = await client.sendCommand(instanceName, 'ping');
        console.log(`Response: ${pingResponse}\n`);

        // Test 2: get-name
        console.log('Sending: get-name');
        const nameResponse = await client.sendCommand(instanceName, 'get-name');
        console.log(`Response: ${nameResponse}\n`);

        // Test 3: get-uptime
        console.log('Sending: get-uptime');
        const uptimeResponse = await client.sendCommand(instanceName, 'get-uptime');
        console.log(`Response: ${uptimeResponse}\n`);

        // Test 4: echo
        console.log('Sending: echo Hello from Node.js!');
        const echoResponse = await client.sendCommand(instanceName, 'echo Hello from Node.js!');
        console.log(`Response: ${echoResponse}\n`);

        console.log('✓ All tests completed successfully!');

    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    } finally {
        client.close();
    }
}

main();
