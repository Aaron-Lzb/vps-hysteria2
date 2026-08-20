#!/usr/bin/env bash

# Run read-only maintenance checks for a Hysteria2 server.
# Usage: bash scripts/check-status.sh [YOUR_DOMAIN]
#
# The script never restarts services, renews certificates, refreshes package
# metadata, installs updates, or changes configuration. Root is not required,
# although sudo may allow certificate and service details to be read.

set -uo pipefail

readonly SERVICE_NAME="hysteria-server"
readonly CONFIG_FILE="/etc/hysteria/config.yaml"
readonly HYSTERIA_BINARY="/usr/local/bin/hysteria"
readonly DOMAIN="${1:-YOUR_DOMAIN}"
readonly TLS_WARNING_DAYS=30
readonly DISK_WARNING_PERCENT=80
readonly DISK_CRITICAL_PERCENT=90

warnings=()
criticals=()

pass() {
  printf '[PASS] %s\n' "$1"
}

info() {
  printf '[INFO] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
  warnings+=("$1")
}

critical() {
  printf '[CRITICAL] %s\n' "$1" >&2
  criticals+=("$1")
}

print_findings() {
  local finding

  printf 'Findings:\n' >&2
  for finding in "${criticals[@]}"; do
    printf -- '- CRITICAL: %s\n' "${finding}" >&2
  done
  for finding in "${warnings[@]}"; do
    printf -- '- WARNING: %s\n' "${finding}" >&2
  done
}

# Read the certificate path from the tls.cert field used by this project.
discover_certificate_path() {
  awk '
    /^[[:space:]]*(#|$)/ { next }
    {
      current_indent = match($0, /[^[:space:]]/) - 1
      if (!in_tls && $0 ~ /^[[:space:]]*tls:[[:space:]]*(#.*)?$/) {
        in_tls = 1
        tls_indent = current_indent
        next
      }
      if (in_tls && current_indent <= tls_indent) {
        exit
      }
      if (in_tls && $0 ~ /^[[:space:]]*cert:[[:space:]]*/) {
        value = $0
        sub(/^[[:space:]]*cert:[[:space:]]*/, "", value)
        sub(/[[:space:]]+#.*$/, "", value)
        sub(/[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "${CONFIG_FILE}"
}

# GNU date is expected on Ubuntu; the BSD form also supports local review.
date_to_epoch() {
  local date_value=$1
  local epoch

  if epoch="$(date -d "${date_value}" +%s 2>/dev/null)"; then
    printf '%s\n' "${epoch}"
    return 0
  fi

  if epoch="$(date -j -f '%b %e %T %Y %Z' "${date_value}" +%s 2>/dev/null)"; then
    printf '%s\n' "${epoch}"
    return 0
  fi

  return 1
}

printf 'Hysteria2 maintenance status\n'
printf 'Read-only diagnostics; sudo may reveal additional details.\n\n'

# 1. Hysteria2 systemd service state.
if ! command -v systemctl >/dev/null 2>&1; then
  warn "Service status: unable to determine because systemctl is unavailable."
else
  service_load_state="$(systemctl show "${SERVICE_NAME}.service" --property=LoadState --value 2>/dev/null)"
  service_show_status=$?

  if [[ ${service_show_status} -ne 0 ]]; then
    warn "Service status: systemd could not provide the service state."
  elif [[ ${service_load_state} == "not-found" || -z ${service_load_state} ]]; then
    critical "Service status: ${SERVICE_NAME}.service was not found."
  elif systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
    pass "Service status: ${SERVICE_NAME}.service is active."
  else
    service_active_state="$(systemctl is-active "${SERVICE_NAME}.service" 2>/dev/null || true)"
    critical "Service status: ${SERVICE_NAME}.service is ${service_active_state:-not active}."
  fi
fi

# 2. Local UDP 443 listener. This does not prove external reachability.
if ! command -v ss >/dev/null 2>&1; then
  warn "UDP 443: unable to inspect listeners because ss is unavailable."
elif socket_output="$(ss -H -lun 2>/dev/null)"; then
  if grep -Eq '(^|[[:space:]])[^[:space:]]*:443([[:space:]]|$)' <<<"${socket_output}"; then
    pass "UDP 443: a local listening socket was found."
  else
    critical "UDP 443: no local listening socket was found."
  fi
else
  warn "UDP 443: unable to inspect local listening sockets."
fi

# 3. Certificate used by the configured Hysteria2 server.
certificate_path=""
if [[ ! -e ${CONFIG_FILE} ]]; then
  critical "TLS certificate: ${CONFIG_FILE} was not found."
elif [[ ! -r ${CONFIG_FILE} ]]; then
  critical "TLS certificate: ${CONFIG_FILE} is unreadable; sudo may provide access."
else
  certificate_path="$(discover_certificate_path)"
  certificate_path="${certificate_path#\"}"
  certificate_path="${certificate_path%\"}"
  certificate_path="${certificate_path#\'}"
  certificate_path="${certificate_path%\'}"

  if [[ -z ${certificate_path} ]]; then
    critical "TLS certificate: no tls.cert path was found in ${CONFIG_FILE}."
  elif [[ ${certificate_path} != /* ]]; then
    critical "TLS certificate: the configured certificate path is not absolute."
  elif [[ ! -r ${certificate_path} ]]; then
    critical "TLS certificate: the configured certificate file is unreadable or missing."
  elif ! command -v openssl >/dev/null 2>&1; then
    warn "TLS certificate: unable to inspect it because openssl is unavailable."
  else
    certificate_end_line="$(openssl x509 -noout -enddate -in "${certificate_path}" 2>/dev/null)"
    certificate_read_status=$?
    certificate_end_date="${certificate_end_line#notAfter=}"

    if [[ ${certificate_read_status} -ne 0 || -z ${certificate_end_date} || ${certificate_end_date} == "${certificate_end_line}" ]]; then
      critical "TLS certificate: the configured certificate could not be parsed."
    elif certificate_end_epoch="$(date_to_epoch "${certificate_end_date}")"; then
      current_epoch="$(date +%s)"
      seconds_remaining=$((certificate_end_epoch - current_epoch))

      if [[ ${seconds_remaining} -le 0 ]]; then
        critical "TLS certificate: expired."
      else
        days_remaining=$((seconds_remaining / 86400))
        if [[ ${days_remaining} -le ${TLS_WARNING_DAYS} ]]; then
          warn "TLS certificate: valid, but only ${days_remaining} day(s) remain."
        else
          pass "TLS certificate: valid for approximately ${days_remaining} more day(s)."
        fi
      fi
    elif openssl x509 -checkend 0 -noout -in "${certificate_path}" >/dev/null 2>&1; then
      info "TLS certificate: valid, but remaining days could not be calculated."
    else
      critical "TLS certificate: expired or unreadable."
    fi
  fi
fi

# 4. Active Certbot systemd renewal timer. No renewal is attempted.
if ! command -v certbot >/dev/null 2>&1; then
  warn "Certbot renewal: certbot is unavailable."
elif ! command -v systemctl >/dev/null 2>&1; then
  warn "Certbot renewal: unable to inspect timers because systemctl is unavailable."
elif timer_units="$(systemctl list-unit-files --type=timer --no-legend --no-pager 2>/dev/null | awk '$1 ~ /certbot/ && $1 ~ /\.timer$/ { print $1 }')"; then
  if [[ -z ${timer_units} ]]; then
    warn "Certbot renewal: no Certbot systemd timer was found."
  else
    active_timer=""
    while IFS= read -r timer_unit; do
      if systemctl is-active --quiet "${timer_unit}" 2>/dev/null; then
        active_timer="${timer_unit}"
        break
      fi
    done <<<"${timer_units}"

    if [[ -n ${active_timer} ]]; then
      pass "Certbot renewal: ${active_timer} is active."
    else
      warn "Certbot renewal: Certbot timer unit(s) exist, but none are active."
    fi
  fi
else
  warn "Certbot renewal: systemd timer state could not be read."
fi

# 5. Pending Ubuntu security updates from existing local APT metadata only.
os_id="unknown"
os_pretty_name="Unknown"
if [[ -r /etc/os-release ]]; then
  os_id="$(awk -F= '$1 == "ID" { value=$2; gsub(/^"|"$/, "", value); print value; exit }' /etc/os-release)"
  os_pretty_name="$(awk -F= '$1 == "PRETTY_NAME" { value=substr($0, index($0, "=") + 1); gsub(/^"|"$/, "", value); print value; exit }' /etc/os-release)"
fi

apt_metadata_found=0
if [[ -d /var/lib/apt/lists ]]; then
  for apt_metadata_file in /var/lib/apt/lists/*_Packages* /var/lib/apt/lists/*_InRelease; do
    if [[ -f ${apt_metadata_file} ]]; then
      apt_metadata_found=1
      break
    fi
  done
fi

if [[ ${os_id} != "ubuntu" ]]; then
  info "Security updates: not classified because this system is not detected as Ubuntu."
elif ! command -v apt >/dev/null 2>&1; then
  info "Security updates: unavailable because apt is not installed."
elif [[ ${apt_metadata_found} -eq 0 ]]; then
  info "Security updates: unavailable because local APT metadata was not found."
elif apt_output="$(apt list --upgradable 2>/dev/null)"; then
  security_update_count="$(awk 'NR > 1 && /-security/ { count++ } END { print count + 0 }' <<<"${apt_output}")"
  if [[ ${security_update_count} -gt 0 ]]; then
    warn "Security updates: ${security_update_count} pending update(s) shown by local APT metadata."
  else
    pass "Security updates: none shown by local APT metadata."
  fi
else
  info "Security updates: local APT metadata could not be read."
fi

# 6. Ubuntu/Debian reboot-required marker.
if [[ ${os_id} == "ubuntu" || ${os_id} == "debian" ]]; then
  if [[ -e /var/run/reboot-required ]]; then
    warn "Reboot: required by installed updates."
  else
    pass "Reboot: no reboot-required marker is present."
  fi
else
  info "Reboot: the Ubuntu/Debian reboot marker is not applicable."
fi

# 7. Root filesystem use.
disk_usage="$(df -P / 2>/dev/null | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')"
if [[ ! ${disk_usage} =~ ^[0-9]+$ ]]; then
  warn "Root filesystem: usage could not be determined."
elif [[ ${disk_usage} -ge ${DISK_CRITICAL_PERCENT} ]]; then
  critical "Root filesystem: ${disk_usage}% used."
elif [[ ${disk_usage} -ge ${DISK_WARNING_PERCENT} ]]; then
  warn "Root filesystem: ${disk_usage}% used."
else
  pass "Root filesystem: ${disk_usage}% used."
fi

# 8. Operating system version.
info "Operating system: ${os_pretty_name:-Unknown}."

# 9. Locally installed Hysteria2 version. No network lookup is performed.
hysteria_command=""
if [[ -x ${HYSTERIA_BINARY} ]]; then
  hysteria_command="${HYSTERIA_BINARY}"
elif command -v hysteria >/dev/null 2>&1; then
  hysteria_command="$(command -v hysteria)"
fi

if [[ -z ${hysteria_command} ]]; then
  warn "Hysteria2 version: installed binary was not found."
elif hysteria_version_output="$("${hysteria_command}" version 2>&1)"; then
  hysteria_version="$(grep -Eom 1 'v?[0-9]+\.[0-9]+\.[0-9]+([+-][^[:space:]]+)?' <<<"${hysteria_version_output}")"
  if [[ -n ${hysteria_version} ]]; then
    info "Hysteria2 version: ${hysteria_version}."
  else
    info "Hysteria2 version: installed, but the version string was not recognized."
  fi
else
  info "Hysteria2 version: installed, but the version could not be determined."
fi

# 10. Optional DNS check retained for compatibility with the existing helper.
if [[ ${DOMAIN} == "YOUR_DOMAIN" ]]; then
  info "DNS resolution: skipped; pass YOUR_DOMAIN as the first argument to check it."
elif ! command -v dig >/dev/null 2>&1; then
  warn "DNS resolution: unable to check ${DOMAIN} because dig is unavailable."
elif dns_output="$(dig +short "${DOMAIN}" 2>/dev/null)"; then
  if [[ -n ${dns_output} ]]; then
    pass "DNS resolution: ${DOMAIN} returned a record."
  else
    critical "DNS resolution: ${DOMAIN} returned no records."
  fi
else
  critical "DNS resolution: lookup failed for ${DOMAIN}."
fi

printf '\n'
if [[ ${#criticals[@]} -gt 0 ]]; then
  printf 'Overall status: CRITICAL (%d critical, %d warning)\n' "${#criticals[@]}" "${#warnings[@]}" >&2
  print_findings
  exit 1
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
  printf 'Overall status: ATTENTION REQUIRED (%d warning)\n' "${#warnings[@]}" >&2
  print_findings
  exit 1
fi

printf 'Overall status: HEALTHY\n'
exit 0
