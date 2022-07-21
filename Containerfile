# Copyright (c) 2022 Kynson Szetau. All Rights Reserved.
# 
# This file is a modified version of the official Redis Dockerfile.
# This file is licensed under the MIT License.
# 
# ============== Start of Original LICENSE ==============
# 
# Copyright (c) 2014 Docker, Inc.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
# 
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
# 
#     * Neither the name of Docker, Inc. nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# ============== End of Original LICENSE ==============

FROM alpine:latest

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S -g 1000 redis && adduser -S -G redis -u 999 redis
# alpine already has a gid 999, so we'll use the next id

RUN apk add --no-cache \
# grab su-exec for easy step-down from root
		'su-exec>=0.2' \
# add tzdata for https://github.com/docker-library/redis/issues/138
		tzdata

ENV REDIS_VERSION 7.0.4
ENV REDIS_DOWNLOAD_URL https://download.redis.io/releases/redis-7.0.4.tar.gz
ENV REDIS_DOWNLOAD_SHA f0e65fda74c44a3dd4fa9d512d4d4d833dd0939c934e946a5c622a630d057f2f

# Set the correct time zone
ENV TZ Asia/Hong_Kong

ENV ROOT_DIR /var/lib/redis
ENV DATA_VOLUME $ROOT_DIR/data-volume

RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		coreutils \
		dpkg-dev dpkg \
		gcc \
		linux-headers \
		make \
		musl-dev \
		openssl-dev \
# install real "wget" to avoid:
#   + wget -O redis.tar.gz https://download.redis.io/releases/redis-6.0.6.tar.gz
#   Connecting to download.redis.io (45.60.121.1:80)
#   wget: bad header line:     XxhODalH: btu; path=/; Max-Age=900
		wget \
	; \
	\
	wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL"; \
	echo "$REDIS_DOWNLOAD_SHA *redis.tar.gz" | sha256sum -c -; \
	mkdir -p /usr/src/redis; \
	tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1; \
	rm redis.tar.gz; \
	\
# https://github.com/jemalloc/jemalloc/issues/467 -- we need to patch the "./configure" for the bundled jemalloc to match how Debian compiles, for compatibility
# (also, we do cross-builds, so we need to embed the appropriate "--build=xxx" values to that "./configure" invocation)
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	extraJemallocConfigureFlags="--build=$gnuArch"; \
# https://salsa.debian.org/debian/jemalloc/-/blob/c0a88c37a551be7d12e4863435365c9a6a51525f/debian/rules#L8-23
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64 | i386 | x32) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=12" ;; \
		*) extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-page=16" ;; \
	esac; \
	extraJemallocConfigureFlags="$extraJemallocConfigureFlags --with-lg-hugepage=21"; \
	grep -F 'cd jemalloc && ./configure ' /usr/src/redis/deps/Makefile; \
	sed -ri 's!cd jemalloc && ./configure !&'"$extraJemallocConfigureFlags"' !' /usr/src/redis/deps/Makefile; \
	grep -F "cd jemalloc && ./configure $extraJemallocConfigureFlags " /usr/src/redis/deps/Makefile; \
	\
	export BUILD_TLS=yes; \
	make -C /usr/src/redis -j "$(nproc)" all; \
	make -C /usr/src/redis install; \
	\
# TODO https://github.com/redis/redis/pull/3494 (deduplicate "redis-server" copies)
	serverMd5="$(md5sum /usr/local/bin/redis-server | cut -d' ' -f1)"; export serverMd5; \
	find /usr/local/bin/redis* -maxdepth 0 \
		-type f -not -name redis-server \
		-exec sh -eux -c ' \
			md5="$(md5sum "$1" | cut -d" " -f1)"; \
			test "$md5" = "$serverMd5"; \
		' -- '{}' ';' \
		-exec ln -svfT 'redis-server' '{}' ';' \
	; \
	\
	rm -r /usr/src/redis; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .redis-rundeps $runDeps; \
	apk del --no-network .build-deps; \
	\
	redis-cli --version; \
	redis-server --version

RUN mkdir $ROOT_DIR

# This will be the mount point of data volume
RUN mkdir $DATA_VOLUME

RUN mkdir $DATA_VOLUME/data && chown redis:redis $DATA_VOLUME/data
RUN mkdir $DATA_VOLUME/data/append-only-files && chown redis:redis $DATA_VOLUME/data/append-only-files

COPY pscan.lua $ROOT_DIR/scripts/pscan.lua
COPY redis-init.sh $ROOT_DIR/scripts/redis-init.sh

RUN chmod +x $ROOT_DIR/scripts/redis-init.sh

COPY redis.conf /etc/redis/redis.conf
# Mount the fake ACL file for build
RUN --mount=type=secret,id=redis-users.acl ln -s /run/secrets/redis-users.acl /etc/redis/redis-users.acl

RUN touch /var/log/redis_6379.log && chown redis:redis /var/log/redis_6379.log

WORKDIR $ROOT_DIR

ENTRYPOINT $ROOT_DIR/scripts/redis-init.sh
