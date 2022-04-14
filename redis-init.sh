#!/bin/ash

# This script should be run inside the Alpine container, therefore we use ash instead of bash
# This script loads the required custom pscan command for Redis

# Reference: https://docs.docker.com/config/containers/multi-service_container/

function log() {
  echo "$(date): $1" >> "/var/log/redis-init.log"
}

function stopRedisAndExit() {
  log "Unexpected error occurred while initializing Redis, exiting"
  kill %1
  exit 1
}

# Turn on job control
set -m
# $INIT_PASSWORD will be substitute during build. Refer to scripts/build.sh in this repo
export REDISCLI_AUTH="$INIT_PASSWORD"

log "Starting Redis"
# Put redis-server to background for the meantime
redis-server /etc/redis/redis.conf &

log "Sleeping for 5 seconds to wait for Redis to fully initialize"
sleep 5

log "Checking if PSCAN function loaded"
response="$(redis-cli --user init FUNCTION LIST LIBRARYNAME pscan)" || stopRedisAndExit

if [[ "$response" = "" ]]; then
    log "Loading PSCAN function"
    redis-cli --user init FUNCTION LOAD "$(cat /var/lib/redis/scripts/pscan.lua)" || stopRedisAndExit
  else
    log "PSCAN function already loaded"
fi

unset REDISCLI_AUTH

log "Redis is fully configured and initialized"
# Bring redis-server back to foreground
fg %1