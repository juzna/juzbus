#!/bin/bash
set -e

echo "=== Testing juzbus workflow ==="
echo ""

# Check if binaries are installed
if ! command -v juzbus &> /dev/null || ! command -v juzbus-example &> /dev/null; then
    echo "Error: juzbus not installed. Please run install.sh first."
    exit 1
fi

# Start example instances
echo "Starting instance 'alice'..."
juzbus-example alice &
ALICE_PID=$!

echo "Starting instance 'bob'..."
juzbus-example bob &
BOB_PID=$!

# Wait for instances to register
echo "Waiting for instances to register..."
sleep 3

# Test: List instances
echo ""
echo "=== Test 1: Listing instances ==="
juzbus list

# Test: Send ping command
echo ""
echo "=== Test 2: Sending 'ping' to alice ==="
juzbus exec alice ping

# Test: Get instance name
echo ""
echo "=== Test 3: Getting name from bob ==="
juzbus exec bob get-name

# Test: Get uptime
echo ""
echo "=== Test 4: Getting uptime from alice ==="
juzbus exec alice get-uptime

# Test: Echo command
echo ""
echo "=== Test 5: Echo command to bob ==="
juzbus exec bob "echo Hello from juzbus!"

# Test: Unknown command
echo ""
echo "=== Test 6: Unknown command (should show available commands) ==="
juzbus exec alice unknown-command || true

# Cleanup
echo ""
echo "=== Cleaning up ==="
kill $ALICE_PID $BOB_PID 2>/dev/null || true
sleep 1

# Verify instances are gone
echo ""
echo "=== Test 7: Verify instances unregistered ==="
juzbus list

echo ""
echo "=== All tests completed successfully! ==="
echo ""
