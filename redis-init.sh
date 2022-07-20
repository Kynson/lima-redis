#!/bin/ash

# This script should be run inside the Alpine container, therefore we use ash instead of bash
# This script loads the required custom pscan command for Redis

# Reference: https://docs.docker.com/config/containers/multi-service_container/

function log() {
  echo "$(date): $1" >> "/var/log/redis-init.log"
  echo "[redis-init] $(date): $1"
}

function stopRedisAndExit() {
  log "Unexpected error occurred while initializing Redis, exiting"
  kill %1
  exit 1
}

# Turn on job control
set -m

# The secrets are mounted when the container is started with podman-compose
log "Loading secrets"
secrets="$(cat /run/secrets/redis-init-secrets.txt)"
secretNames=""

for secret in $secrets; do
  secretName="$(cut -d '=' -f 1 <(echo "$secret"))"
  # ASH does not support += so use this workaround
  secretNames="$secretNames $secretName"

  export "$secretName"="$(cut -d '=' -f 2 <(echo "$secret"))"
done

log "Starting Redis"
# Put redis-server to background for the meantime
su-exec redis:redis redis-server /etc/redis/redis.conf &

log "Sleeping for 5 seconds to wait for Redis to fully initialize"
sleep 5

log "Checking if PSCAN function loaded"
response="$(redis-cli --user $__S_INIT_USER__ FUNCTION LIST LIBRARYNAME pscan)" || stopRedisAndExit

if [[ "$response" = "" ]]; then
    log "Loading PSCAN function"
    redis-cli --user $__S_INIT_USER__ FUNCTION LOAD "$(cat /var/lib/redis/scripts/pscan.lua)" || stopRedisAndExit
  else
    log "PSCAN function already loaded"
fi

log "Cleaning up secrets"
for secretName in "$secretNames"; do
  unset "$secretName"
done

log "Redis is fully configured and initialized"
# Bring redis-server back to foreground
fg %1
