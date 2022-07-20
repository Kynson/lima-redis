#!/bin/bash

echo "Creating secrets"
podman secret create redis-users.acl ./redis-users.acl
podman secret create redis-init-secrets ./redis-init-secrets.txt

echo "Running image for test"
# Use these two command as podman run does not work well with &
podman create -it --rm --name lima-redis-test --secret=redis-users.acl --secret=redis-init-secrets lima-redis
podman start lima-redis-test &

echo "Sleeping for 8 seconds to wait for Redis to start"
sleep 8

echo "Testing if Redis is running"
# We do not authenticate here as we just want to test if Redis is started and running
podman exec lima-redis-test redis-cli PING

testExitCode=$?

# Stop Redis
podman stop lima-redis-test

if [[ $testExitCode == 0 ]]; then
    echo "Test passed: Connection to Redis was successful"
else
    echo "Test failed: Cannot connect to Redis"
    exit 1
fi