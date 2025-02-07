#!/bin/bash

# A "common-courtesy" file inspired by @gurneyalex
#  - Information on current version.
#  - Deprecation warnings for future versions.

echo "${PACKAGE} ${VERSION} revision ${REVISION} built ${BUILD_RFC3339}"

if [[ ! -z "${SSH_TUNNEL_HOST}" ]]; then
    message="[WARN ] SSH_TUNNEL_HOST is deprecated, please use SSH_TARGET_HOST"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

if [[ ! -z "${SSH_TUNNEL_LOCAL}" ]]; then
    message="[WARN ] SSH_TUNNEL_LOCAL is deprecated, please use SSH_TARGET_PORT"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

if [[ ! -z "${SSH_TUNNEL_REMOTE}" ]]; then
    message="[WARN ] SSH_TUNNEL_REMOTE is deprecated, please use SSH_TUNNEL_PORT"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

if [[ ! -z "${SSH_HOSTUSER}" ]]; then
    message="[WARN ] SSH_HOSTUSER is deprecated, please use SSH_REMOTE_USER"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

if [[ ! -z "${SSH_HOSTNAME}" ]]; then
    message="[WARN ] SSH_HOSTNAME is deprecated, please use SSH_REMOTE_HOST"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

if [[ ! -z "${SSH_HOSTPORT}" ]]; then
    message="[WARN ] SSH_HOSTPORT is deprecated, please use SSH_REMOTE_PORT"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

if [[ ! -z "${SSH_KNOWN_HOSTS}" ]]; then
    message="[WARN ] SSH_KNOWN_HOSTS is deprecated, please use SSH_KNOWN_HOSTS_FILE"
    echo -e "\033[33m${message}\033[0m"
    WARN=true
fi

# Exit if there are any fatal errors from version mismatches.
if [ ! -z $FATAL  ]; then
    exit 1
fi