#!/usr/bin/env bash
set -Eeuo pipefail

image="${DEVBOX_IMAGE:-devbox:local}"
platforms="${DEVBOX_PLATFORMS:-linux/arm64}"

args=(
    buildx build
    --platform "${platforms}"
    --tag "${image}"
)

if [[ "${platforms}" != *,* ]]; then
    args+=(--load)
fi

args+=("$@" .)

docker "${args[@]}"
