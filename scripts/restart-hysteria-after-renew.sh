#!/usr/bin/env bash

# Certbot deployment hook for Hysteria2.
#
# Install this file with executable permissions at, for example:
# /etc/letsencrypt/renewal-hooks/deploy/restart-hysteria-after-renew.sh
#
# Certbot renewal
#        |
#        v
# renewal deploy hook
#        |
#        v
# restart Hysteria2
#        |
#        v
# load new certificate
#
# Certbot calls deploy hooks only after a successful certificate renewal. A
# restart is required because Hysteria2 reads its TLS files when it starts.

set -Eeuo pipefail

readonly SERVICE_NAME="hysteria-server"

if [[ ${EUID} -ne 0 ]]; then
  printf '[ERROR] This Certbot deploy hook must run as root.\n' >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  printf '[ERROR] systemctl is unavailable; cannot restart %s.\n' "${SERVICE_NAME}" >&2
  exit 1
fi

printf '[INFO] Restarting %s to load the renewed TLS certificate...\n' "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

if systemctl is-active --quiet "${SERVICE_NAME}"; then
  printf '[PASS] %s restarted and is active.\n' "${SERVICE_NAME}"
else
  printf '[ERROR] %s did not become active after restart.\n' "${SERVICE_NAME}" >&2
  exit 1
fi
