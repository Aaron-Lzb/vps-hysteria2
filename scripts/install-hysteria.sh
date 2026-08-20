#!/usr/bin/env bash

# Install Hysteria2 and prepare its systemd service on Ubuntu.
#
# Tested on Ubuntu 22.04 and 24.04. Existing Hysteria2 configuration and
# systemd unit files are preserved.

set -Eeuo pipefail

readonly SERVICE_NAME="hysteria-server"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
readonly CONFIG_DIR="/etc/hysteria"
readonly CONFIG_FILE="${CONFIG_DIR}/config.yaml"
readonly INSTALLER_URL="https://get.hy2.sh/"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CHECK_SCRIPT="${SCRIPT_DIR}/check-status.sh"
readonly CHECK_COMMAND="/usr/local/bin/hysteria-check"

installer_file=""
service_template=""
config_existed_before=0
check_script_available=0

cleanup() {
  if [[ -n "${installer_file}" && -f "${installer_file}" ]]; then
    rm -f -- "${installer_file}"
  fi
  if [[ -n "${service_template}" && -f "${service_template}" ]]; then
    rm -f -- "${service_template}"
  fi
}

on_error() {
  local exit_code=$?
  printf '[ERROR] Installation stopped at line %s (exit code %s).\n' "${BASH_LINENO[0]}" "${exit_code}" >&2
  printf 'Review the error above; existing Hysteria2 configuration was not replaced.\n' >&2
  exit "${exit_code}"
}

trap cleanup EXIT
trap on_error ERR

if [[ ${EUID} -ne 0 ]]; then
  printf '[ERROR] Root permission is required. Run: sudo bash scripts/install-hysteria.sh\n' >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  printf '[ERROR] Cannot detect the operating system because /etc/os-release is unavailable.\n' >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ ${ID:-} != "ubuntu" ]]; then
  printf '[ERROR] This installer supports Ubuntu only; detected: %s.\n' "${PRETTY_NAME:-unknown system}" >&2
  exit 1
fi

case "${VERSION_ID:-unknown}" in
  22.04 | 24.04)
    printf '[PASS] Detected supported system: %s\n' "${PRETTY_NAME}"
    ;;
  *)
    printf '[WARN] Ubuntu %s is not part of the tested 22.04/24.04 matrix.\n' "${VERSION_ID:-unknown}"
    printf '[WARN] Continuing without changing existing configuration files.\n'
    ;;
esac

for required_command in apt-get systemctl mktemp install; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    printf '[ERROR] Required command is missing: %s\n' "${required_command}" >&2
    exit 1
  fi
done

if [[ -r ${CHECK_SCRIPT} ]]; then
  check_script_available=1
else
  printf '[WARN] Maintenance script is missing from the checkout: %s\n' "${CHECK_SCRIPT}" >&2
  printf '[WARN] Hysteria2 installation will continue, but hysteria-check cannot be installed.\n' >&2
fi

printf '\n[1/6] Refreshing package metadata...\n'
apt-get update

printf '\n[2/6] Installing required packages...\n'
# Do not run a full distribution upgrade here. Operators should review system
# upgrades separately so this installer does not make unrelated package changes.
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates certbot curl dnsutils iproute2 wget

printf '\n[3/6] Installing Hysteria2 with the upstream installer...\n'
if [[ -e "${CONFIG_FILE}" ]]; then
  config_existed_before=1
fi
installer_file="$(mktemp)"
curl --fail --silent --show-error --location "${INSTALLER_URL}" --output "${installer_file}"
# The upstream installer normally replaces its systemd unit. Disable that part
# so an existing administrator-managed unit is never overwritten.
FORCE_NO_SYSTEMD=2 bash "${installer_file}"

if ! command -v hysteria >/dev/null 2>&1 && [[ ! -x /usr/local/bin/hysteria ]]; then
  printf '[ERROR] The installer completed but the Hysteria2 binary was not found.\n' >&2
  exit 1
fi

printf '\n[4/6] Preparing the configuration directory...\n'
install -d -m 0755 "${CONFIG_DIR}"

if [[ ${config_existed_before} -eq 1 ]]; then
  printf '[PASS] Preserved existing configuration: %s\n' "${CONFIG_FILE}"
elif [[ -e "${CONFIG_FILE}" ]]; then
  printf '[INFO] The upstream installer created an example configuration: %s\n' "${CONFIG_FILE}"
  printf '[INFO] Review it or replace it with configs/hysteria/config.example.yaml before use.\n'
else
  printf '[INFO] No configuration was created. Copy and edit the repository example before starting the service.\n'
fi

printf '\n[5/6] Preparing the systemd service...\n'
if [[ -e "${SERVICE_FILE}" ]]; then
  printf '[WARN] Preserving existing systemd unit: %s\n' "${SERVICE_FILE}"
  printf '[WARN] Compare it manually with configs/systemd/hysteria-server.service if an update is needed.\n'
else
  service_template="$(mktemp)"
  cat >"${service_template}" <<'EOF'
[Unit]
Description=Hysteria2 Server Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  install -m 0644 "${service_template}" "${SERVICE_FILE}"
  rm -f -- "${service_template}"
  service_template=""
  printf '[PASS] Created systemd unit: %s\n' "${SERVICE_FILE}"
fi

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

printf '\n[6/6] Installing the maintenance command...\n'
# Install a standalone copy so the command keeps working if the repository
# checkout is later moved or removed. Re-running the installer safely refreshes
# the project-managed copy without creating another command or symlink.
if [[ ${check_script_available} -eq 1 ]]; then
  install -m 0755 "${CHECK_SCRIPT}" "${CHECK_COMMAND}"
  if [[ ! -x ${CHECK_COMMAND} ]]; then
    printf '[ERROR] Maintenance command was not installed correctly: %s\n' "${CHECK_COMMAND}" >&2
    exit 1
  fi
  printf '[PASS] Installed maintenance command: %s\n' "${CHECK_COMMAND}"
else
  printf '[WARN] Skipped hysteria-check because the source script was unavailable.\n'
fi

printf '\nInstallation preparation completed.\n'
printf '\nNext steps:\n'
printf '1. Obtain a TLS certificate for YOUR_DOMAIN with Certbot.\n'
printf '2. Copy configs/hysteria/config.example.yaml to %s.\n' "${CONFIG_FILE}"
printf '3. In the private server copy, replace YOUR_DOMAIN and YOUR_PASSWORD.\n'
printf '4. Review the configuration and service unit before starting anything.\n'
printf '5. Start and check the service:\n'
printf '   sudo systemctl start %s\n' "${SERVICE_NAME}"
printf '   sudo systemctl status %s\n' "${SERVICE_NAME}"
printf '6. Install scripts/restart-hysteria-after-renew.sh under:\n'
printf '   /etc/letsencrypt/renewal-hooks/deploy/\n'
printf '7. Verify the deployment with: hysteria-check\n'
printf '\nMaintenance check:\n'
printf 'hysteria-check\n'
printf 'If automatic public-IP detection fails: hysteria-check <PUBLIC_IP>\n'
