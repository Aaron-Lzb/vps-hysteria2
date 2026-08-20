#!/usr/bin/env bash

# Perform quick, read-only checks for a Hysteria2 deployment.
# Usage: sudo bash scripts/check-status.sh YOUR_DOMAIN
#
# The checks intentionally do not change the service, firewall, certificate, or
# DNS configuration. Missing diagnostic commands are reported as failures.

set -uo pipefail

readonly SERVICE_NAME="hysteria-server"
readonly DOMAIN="${1:-YOUR_DOMAIN}"

failures=0

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_command() {
  local command_name=$1

  if command -v "${command_name}" >/dev/null 2>&1; then
    return 0
  fi

  fail "Required command is unavailable: ${command_name}"
  return 1
}

printf 'Hysteria2 deployment status\n'
printf 'Domain: %s\n\n' "${DOMAIN}"

# 1. Check the systemd service with: systemctl status hysteria-server
if require_command systemctl; then
  if service_output="$(systemctl status "${SERVICE_NAME}" 2>&1)"; then
    pass "Hysteria2 service is active."
  else
    fail "Hysteria2 service is not active."
    printf '%s\n' "${service_output}" >&2
  fi
fi

# 2. Check the UDP listener with the equivalent of: ss -ulnp | grep 443
if require_command ss; then
  socket_output="$(ss -ulnp 2>&1)"
  socket_status=$?

  if [[ ${socket_status} -ne 0 ]]; then
    fail "Could not inspect UDP listening sockets. Try running as root."
    printf '%s\n' "${socket_output}" >&2
  elif grep -Eq '(^|[[:space:]])[^[:space:]]*:443([[:space:]]|$)' <<<"${socket_output}"; then
    pass "A process is listening on UDP 443."
  else
    fail "No UDP 443 listener was found."
  fi
fi

# 3. Check certificate information with: certbot certificates
if require_command certbot; then
  certificate_output="$(certbot certificates 2>&1)"
  certificate_status=$?

  if [[ ${certificate_status} -ne 0 ]]; then
    fail "Certbot could not read certificate information. Try running as root."
    printf '%s\n' "${certificate_output}" >&2
  elif ! grep -Fq 'VALID:' <<<"${certificate_output}"; then
    fail "Certbot did not report a currently valid certificate."
  elif [[ ${DOMAIN} != "YOUR_DOMAIN" ]] && ! grep -Fq "${DOMAIN}" <<<"${certificate_output}"; then
    fail "Certbot reports a valid certificate, but not for ${DOMAIN}."
  else
    pass "Certbot reports a valid TLS certificate."
  fi
fi

# 4. Resolve the deployment domain with: dig YOUR_DOMAIN
if [[ ${DOMAIN} == "YOUR_DOMAIN" ]]; then
  fail "Replace YOUR_DOMAIN or pass the deployment domain as the first argument."
elif require_command dig; then
  dns_output="$(dig +short "${DOMAIN}" 2>&1)"
  dns_status=$?

  if [[ ${dns_status} -ne 0 ]]; then
    fail "DNS lookup failed for ${DOMAIN}."
    printf '%s\n' "${dns_output}" >&2
  elif [[ -z ${dns_output} ]]; then
    fail "DNS returned no address for ${DOMAIN}."
  else
    pass "Domain DNS resolution returned an address."
  fi
fi

printf '\n'
if [[ ${failures} -eq 0 ]]; then
  printf '[PASS] All deployment checks passed.\n'
  exit 0
fi

printf '[FAIL] %d check(s) need attention.\n' "${failures}" >&2
exit 1
