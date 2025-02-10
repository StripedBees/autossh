#!/usr/bin/dumb-init /bin/bash
./version.sh

errors_encountered=no

function missingFilesCheck() {
    # $1 = File to check
    # $2 = Expected File Name
    # $3 = 
    if [[ ! -f "${1}" ]]; then

        POSSIBLE_KEY_FILES=$(find / -name "${2}" -type f | tr '\n' ' ')
        POSSIBLE_KEY_FILES_LENGTH=$(echo "${POSSIBLE_KEY_FILES}" | wc -w)

        if [[ ${POSSIBLE_KEY_FILES_LENGTH} -gt 0 ]]; then
            case "${2}" in 
                "id_rsa")
                    message="[FATAL] No SSH Key file found in ${1}. Possible files: ${POSSIBLE_KEY_FILES}"
                    ;;
                "known_hosts")
                    ls -l /
                    message="[FATAL] No SSH Known Hosts file found in ${1}. Possible files: ${POSSIBLE_KEY_FILES}"
                    ;;
                *)
                    message="[FATAL] No SSH file found in ${1}. Possible files: ${POSSIBLE_KEY_FILES}"
                    ;;
            esac
            echo -e "\033[31m${message}\033[0m"
            errors_encountered=yes
            # exit 1
        else
            case "${2}" in 
                "id_rsa")
                    message="[FATAL] No SSH Key file found in ${1}."
                    ;;
                "known_hosts")
                    message="[FATAL] No SSH Known Hosts file found in ${1}."
                    ;;
                *)
                    message="[FATAL] No SSH file found in ${1}."
                    ;;
            esac
            echo -e "\033[31m${message}\033[0m"
            errors_encountered=yes
            # exit 1
        fi
    else
        chmod 0600 "${1}"
        echo "[INFO] Found ${2} file: ${1}"
    fi

}

# Set up key file
KEY_FILE="${SSH_KEY_FILE:=/id_rsa}"

# Verify that the key defined key file exists
missingFilesCheck "${KEY_FILE}" "id_rsa"

eval "$(ssh-agent -s)"

# cat "${KEY_FILE}" | ssh-add -k -
ssh-add -k - < "${KEY_FILE}"

# If known_hosts is provided, STRICT_HOST_KEY_CHECKING=yes
# Default CheckHostIP=yes unless SSH_STRICT_HOST_IP_CHECK=false
STRICT_HOSTS_KEY_CHECKING=no
KNOWN_HOSTS="${SSH_KNOWN_HOSTS_FILE:=/known_hosts}"
# Verify that the defined known_hosts file exists
missingFilesCheck "${KNOWN_HOSTS}" "known_hosts"

if [[ -f "${KNOWN_HOSTS}" ]]; then
    KNOWN_HOSTS_ARG="-o UserKnownHostsFile=${KNOWN_HOSTS} "
    if [[ "${SSH_STRICT_HOST_IP_CHECK}" = false ]]; then
        KNOWN_HOSTS_ARG="${KNOWN_HOSTS_ARG}-o CheckHostIP=no "
        message="[WARN] Not using STRICT_HOSTS_KEY_CHECKING"
        echo -e "\033[33m$message\033[0m"
    fi
    STRICT_HOSTS_KEY_CHECKING=yes
    echo "[INFO] Using STRICT_HOSTS_KEY_CHECKING"
fi

# Add entry to /etc/passwd if we are running non-root
if [[ $(id -u) != "0" ]]; then
  USER="autossh:x:$(id -u):$(id -g):autossh:/tmp:/bin/sh"
  echo "[INFO ] Creating non-root-user = $USER"
  echo "$USER" >> /etc/passwd
fi

if [[ -n "${SSH_BIND_IP}" ]] && [[ "${SSH_MODE}" = "-R" ]]; then
    message="[WARN] SSH_BIND_IP requires GatewayPorts configured on the server to work properly"
    echo -e "\033[33m$message\033[0m"
fi

USE_RANDOM_PORT="${SSH_USE_RANDOM_PORT:=no}"
if [ ! -f "${USE_RANDOM_PORT}" ]; then
    if [[ "${USE_RANDOM_PORT}" = "yes" ]]; then
        # Pick a random port above 32768
        DEFAULT_PORT=${RANDOM}
        (( DEFAULT_PORT += 32768 ))
        message="[INFO] Using random port"
        echo -e "${message}"
    fi
fi



# Determine command line flags

# Log to stdout

echo "[INFO] Using $(autossh -V)"

if [[ -z "${SSH_TUNNEL_PORT}" && -z "${SSH_TARGET_PORT}" ]]; then
    message="[WARN] SSH_TUNNEL_PORT or SSH_TARGET_PORT not set. No Port Fowarding will be done."
    echo -e "\033[33m$message\033[0m"

else
    echo "[INFO] Tunneling ${SSH_BIND_IP:=0.0.0.0}:${SSH_TUNNEL_PORT:=${DEFAULT_PORT}}" \
        " on ${SSH_REMOTE_USER:=root}@${SSH_REMOTE_HOST:=localhost}:${SSH_REMOTE_PORT}" \
        " to ${SSH_TARGET_HOST=localhost}:${SSH_TARGET_PORT:=22}"

    PORT_FORWARD="${SSH_MODE:=-R} ${SSH_BIND_IP}:${SSH_TUNNEL_PORT}:${SSH_TARGET_HOST}:${SSH_TARGET_PORT}"
fi


# Display proxy command in output
if [[ "${SSH_PROXY_COMMAND}" ]]; then
    # Verify that proxy command exists on container.
    proxy_command=$( echo "${SSH_PROXY_COMMAND}" | awk -F ' ' '{print $1}' | sed 's/[\"'\'']//g' )
    if command -v "${proxy_command}" &> /dev/null; then
        message="[INFO] ProxyCommand found: ${proxy_command}"
        echo -e "${message}"
    else
        message="[FATAL] ProxyCommand not found: ${proxy_command}"
        echo -e "\033[31m${message}\033[0m"
        errors_encountered=yes
        # exit 1
    fi
    # Remove quotes from proxy command
    if [[ "${SSH_PROXY_COMMAND}" == \'*\' ]]; then
        SSH_PROXY_COMMAND="${SSH_PROXY_COMMAND:1:-1}"
    fi
    use_proxy_command_path=$(command -v "${proxy_command}" | awk -F '/' '{OFS="/"; $NF=""; print}')
    # Encapsulate proxy command in single quotes if it is not already
    if [[ "${SSH_PROXY_COMMAND}" != \"*\" ]]; then
        SSH_PROXY_COMMAND="\"${SSH_PROXY_COMMAND}\" "
    fi
    SSH_PROXY_COMMAND="-o ProxyCommand=\"${use_proxy_command_path}${SSH_PROXY_COMMAND:1}"

    message="[INFO] Using ProxyCommand: ${SSH_PROXY_COMMAND}"
    echo -e "${message}"
fi
use_autossh=$(command -v autossh)


COMMAND="${use_autossh} -M 0 -N \
  -o StrictHostKeyChecking=${STRICT_HOSTS_KEY_CHECKING} ${KNOWN_HOSTS_ARG:=} \
  -o ServerAliveInterval=${SSH_SERVER_ALIVE_INTERVAL:-10} \
  -o ServerAliveCountMax=${SSH_SERVER_ALIVE_COUNT_MAX:-3} \
  -o ExitOnForwardFailure=yes ${SSH_OPTIONS} ${SSH_PROXY_COMMAND} \
  -t -t ${PORT_FORWARD} \
  -p ${SSH_REMOTE_PORT:=22} \
  ${SSH_REMOTE_USER}@${SSH_REMOTE_HOST}"


echo "[INFO] # ${COMMAND}"

if [[ "${errors_encountered}" = "yes" ]]; then
    echo -e "\033[31m[FATAL] Errors encountered. Exiting\033[0m"
    exit 1
else
    # Run command (Do not add quotes to ${COMMAND} below)
    eval "${COMMAND}"
fi
