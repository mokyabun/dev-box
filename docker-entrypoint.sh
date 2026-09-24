#!/usr/bin/env bash
# shellcheck disable=SC2317
set -Eeuo pipefail

readonly dev_user="dev"
readonly dev_home="/home/dev"

log() {
    printf '[devbox] %s\n' "$*"
}

is_true() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

if [[ "$(id -u)" -ne 0 ]]; then
    echo "docker-entrypoint must start as root so it can initialize sshd and map UID/GID" >&2
    exit 1
fi

if [[ ! "${PUID}" =~ ^[0-9]+$ || ! "${PGID}" =~ ^[0-9]+$ ]]; then
    echo "PUID and PGID must be numeric" >&2
    exit 1
fi

current_gid="$(id -g "${dev_user}")"
current_uid="$(id -u "${dev_user}")"

if [[ "${current_gid}" != "${PGID}" ]]; then
    groupmod --non-unique --gid "${PGID}" "${dev_user}"
fi

if [[ "${current_uid}" != "${PUID}" ]]; then
    usermod --non-unique --uid "${PUID}" "${dev_user}"
fi

usermod --append --groups sudo "${dev_user}"

install -d -m 0755 -o "${PUID}" -g "${PGID}" \
    "${dev_home}" \
    "${WORKSPACE_DIR}" \
    "${dev_home}/.cache" \
    "${dev_home}/.config" \
    "${dev_home}/.local" \
    "${dev_home}/.local/share" \
    "${dev_home}/.local/state" \
    "${dev_home}/.config/mise" \
    "${dev_home}/.local/share/mise" \
    "${dev_home}/.local/state/mise" \
    "${dev_home}/.cache/mise" \
    "${dev_home}/.ssh"

if [[ -n "${DEVBOX_SSH_AUTHORIZED_KEYS:-}" ]]; then
    printf '%s\n' "${DEVBOX_SSH_AUTHORIZED_KEYS}" \
        > "${dev_home}/.ssh/authorized_keys"
    chown "${PUID}:${PGID}" "${dev_home}/.ssh/authorized_keys"
    chmod 0600 "${dev_home}/.ssh/authorized_keys"
fi

install -d -m 0700 /etc/devbox/ssh
if [[ ! -s /etc/devbox/ssh/ssh_host_ed25519_key ]]; then
    log "generating persistent SSH host key"
    ssh-keygen -q -t ed25519 -N '' -f /etc/devbox/ssh/ssh_host_ed25519_key
fi

export HOME="${dev_home}"
export USER="${dev_user}"
export LOGNAME="${dev_user}"

pids=()

start_process() {
    local name="$1"
    shift
    log "starting ${name}"
    "$@" &
    pids+=("$!")
}

shutdown() {
    trap - TERM INT EXIT
    log "stopping services"
    if ((${#pids[@]})); then
        kill -TERM "${pids[@]}" 2>/dev/null || true
        wait "${pids[@]}" 2>/dev/null || true
    fi
}
trap shutdown TERM INT EXIT

if is_true "${ENABLE_CODE_SERVER}"; then
    if [[ -z "${CODE_SERVER_PASSWORD:-}" && -z "${CODE_SERVER_HASHED_PASSWORD:-}" ]]; then
        echo "CODE_SERVER_PASSWORD or CODE_SERVER_HASHED_PASSWORD is required when code-server is enabled" >&2
        exit 1
    fi
    start_process code-server \
        env \
        -u CODE_SERVER_PASSWORD \
        -u CODE_SERVER_HASHED_PASSWORD \
        PASSWORD="${CODE_SERVER_PASSWORD:-}" \
        HASHED_PASSWORD="${CODE_SERVER_HASHED_PASSWORD:-}" \
        gosu "${dev_user}" code-server \
        --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" \
        --auth password \
        --disable-telemetry \
        "${WORKSPACE_DIR}"
fi

if is_true "${ENABLE_OPENCODE}"; then
    if [[ -z "${OPENCODE_PASSWORD:-}" ]]; then
        echo "OPENCODE_PASSWORD is required when OpenCode is enabled" >&2
        exit 1
    fi
    start_process opencode \
        gosu "${dev_user}" opencode serve \
        --hostname 0.0.0.0 \
        --port "${OPENCODE_PORT}"
fi

if is_true "${ENABLE_SSH}"; then
    start_process sshd \
        /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config \
        -o "Port=${SSH_PORT}"
fi

if ((${#pids[@]} == 0)); then
    echo "at least one service must be enabled" >&2
    exit 1
fi

set +e
wait -n "${pids[@]}"
status=$?
set -e
log "a service exited with status ${status}"
exit "${status}"
