#!/bin/bash

read -p "Enter target Containerfile path: " containerfilePath
read -p "Enter the Redis version number (without patch version number): " version

echo "Creating temporary directory"

temporaryDirectory="$(mktemp -d)"
baseDockerfile="$temporaryDirectory/Dockerfile"

echo "Fetching target Redis $version Dockerfile"
curl -sS "https://raw.githubusercontent.com/docker-library/redis/master/$version/alpine/Dockerfile" -o "$baseDockerfile"

oldRedisVersion="$(grep 'ENV REDIS_VERSION' "$containerfilePath" | cut -d ' ' -f 3)"
oldRedisDownloadUrl="$(grep 'ENV REDIS_DOWNLOAD_URL' "$containerfilePath" | cut -d ' ' -f 3)"
oldRedisDownloadSha="$(grep 'ENV REDIS_DOWNLOAD_SHA' "$containerfilePath" | cut -d ' ' -f 3)"

redisVersion="$(grep 'ENV REDIS_VERSION' "$baseDockerfile" | cut -d ' ' -f 3)"
redisDownloadUrl="$(grep 'ENV REDIS_DOWNLOAD_URL' "$baseDockerfile" | cut -d ' ' -f 3)"
redisDownloadSha="$(grep 'ENV REDIS_DOWNLOAD_SHA' "$baseDockerfile" | cut -d ' ' -f 3)"

echo "Redis Version: $oldRedisVersion => $redisVersion"
echo "Redis Download URL: $oldRedisDownloadUrl => $redisDownloadUrl"
echo "Redis Download SHA: $oldRedisDownloadSha => $redisDownloadSha"

read -p "Confirm the above update? [Y/n]: " response
response="${response:-Y}"
if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
	ed -s <<- EOF "$containerfilePath"
    ,s/ENV REDIS_VERSION $oldRedisVersion/ENV REDIS_VERSION $redisVersion/
    w
    q
	EOF

  # Use ; as seperator to prevent conflict with / in the URL
  ed -s <<- EOF "$containerfilePath"
    ,s;ENV REDIS_DOWNLOAD_URL $oldRedisDownloadUrl;ENV REDIS_DOWNLOAD_URL $redisDownloadUrl;
    w
    q
	EOF

  ed -s <<- EOF "$containerfilePath"
    ,s/ENV REDIS_DOWNLOAD_SHA $oldRedisDownloadSha/ENV REDIS_DOWNLOAD_SHA $redisDownloadSha/
    w
    q
	EOF
fi
