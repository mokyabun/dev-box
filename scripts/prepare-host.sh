#!/usr/bin/env bash
set -Eeuo pipefail

app_data_root="${APP_DATA_ROOT:-/data/compose/appdata}"
workspace_root="${DEV_WORKSPACE_ROOT:-/data/compose/workspace}"
puid="${PUID:-1001}"
pgid="${PGID:-1001}"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "run this script as root on the OCI host" >&2
    exit 1
fi

install -d -m 0750 -o "${puid}" -g "${pgid}" \
    "${app_data_root}/devbox/home" \
    "${workspace_root}"

install -d -m 0700 -o root -g root \
    "${app_data_root}/devbox/ssh"

printf 'prepared:\n  %s\n  %s\n  %s\n' \
    "${app_data_root}/devbox/home" \
    "${app_data_root}/devbox/ssh" \
    "${workspace_root}"

