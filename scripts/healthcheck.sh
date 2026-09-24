#!/usr/bin/env bash
set -Eeuo pipefail

is_true() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

check_http() {
    curl --silent --show-error --output /dev/null --max-time 3 "$1"
}

if is_true "${ENABLE_CODE_SERVER:-true}"; then
    check_http "http://127.0.0.1:${CODE_SERVER_PORT:-8080}/healthz"
fi

if is_true "${ENABLE_OPENCODE:-true}"; then
    curl --silent --show-error --fail --output /dev/null --max-time 3 \
        --user "opencode:${OPENCODE_PASSWORD:?}" \
        "http://127.0.0.1:${OPENCODE_PORT:-4096}/api/info"
fi

if is_true "${ENABLE_SSH:-true}"; then
    ss -H -lnt "sport = :${SSH_PORT:-2222}" | grep -q LISTEN
fi
