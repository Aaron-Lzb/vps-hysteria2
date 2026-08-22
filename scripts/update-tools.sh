#!/usr/bin/env bash

# Update maintenance tools supplied by Aaron-Lzb/vps-hysteria2.
#
# This updater manages only /usr/local/bin/hysteria-check. It does not update
# Hysteria2 itself or change server configuration, services, certificates,
# firewall rules, packages, accounts, SSH, or network settings.

set -Eeuo pipefail

readonly CHECK_SOURCE_URL="https://raw.githubusercontent.com/Aaron-Lzb/vps-hysteria2/main/scripts/check-status.sh"
readonly CHECK_COMMAND="/usr/local/bin/hysteria-check"
readonly GREEN=$'\033[32m'
readonly CYAN=$'\033[36m'
readonly RED=$'\033[31m'
readonly RESET=$'\033[0m'

color_stdout=0
color_stderr=0
temporary_file=""

# Check stdout and stderr independently so redirected output remains plain.
if [[ -z ${NO_COLOR+x} && ${TERM:-} != "dumb" ]]; then
  [[ -t 1 ]] && color_stdout=1
  [[ -t 2 ]] && color_stderr=1
fi

readonly color_stdout
readonly color_stderr

print_stdout_status() {
  local color=$1
  local label=$2
  local message=$3

  if [[ ${color_stdout} -eq 1 ]]; then
    printf '%s[%s]%s %s\n' "${color}" "${label}" "${RESET}" "${message}"
  else
    printf '[%s] %s\n' "${label}" "${message}"
  fi
}

print_stderr_status() {
  local color=$1
  local label=$2
  local message=$3

  if [[ ${color_stderr} -eq 1 ]]; then
    printf '%s[%s]%s %s\n' "${color}" "${label}" "${RESET}" "${message}" >&2
  else
    printf '[%s] %s\n' "${label}" "${message}" >&2
  fi
}

info() {
  print_stdout_status "${CYAN}" "INFO" "$1"
}

pass() {
  print_stdout_status "${GREEN}" "PASS" "$1"
}

error() {
  print_stderr_status "${RED}" "ERROR" "$1"
}

cleanup() {
  if [[ -n ${temporary_file} && -f ${temporary_file} ]]; then
    rm -f -- "${temporary_file}"
  fi
  temporary_file=""
}

download_check_script() {
  local destination=$1

  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error \
      --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 1 \
      --output "${destination}" "${CHECK_SOURCE_URL}"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget --quiet --timeout=30 --tries=3 \
      --output-document="${destination}" "${CHECK_SOURCE_URL}"
    return
  fi

  return 1
}

validate_check_script() {
  local candidate=$1
  local shebang=""

  if [[ ! -s ${candidate} ]]; then
    error "Downloaded hysteria-check is empty."
    return 1
  fi

  IFS= read -r shebang <"${candidate}" || true
  case "${shebang}" in
    "#!/usr/bin/env bash" | "#!/bin/bash")
      ;;
    *)
      error "Downloaded hysteria-check does not have a valid Bash shebang."
      return 1
      ;;
  esac

  if ! bash -n "${candidate}" >/dev/null 2>&1; then
    error "Downloaded hysteria-check failed the Bash syntax check."
    return 1
  fi
}

update_check_command() {
  local target=$1

  info "Checking latest maintenance tool..."

  if [[ ! -d ${target%/*} ]]; then
    error "Target directory does not exist: ${target%/*}"
    return 1
  fi

  if ! temporary_file="$(mktemp "${target}.tmp.XXXXXX")"; then
    error "Unable to create a secure temporary file."
    return 1
  fi

  info "Downloading hysteria-check..."
  if ! download_check_script "${temporary_file}"; then
    cleanup
    error "Unable to download hysteria-check."
    printf 'Existing installation was not changed.\n' >&2
    return 1
  fi
  pass "Download completed."

  if ! validate_check_script "${temporary_file}"; then
    cleanup
    printf 'Existing installation was not changed.\n' >&2
    return 1
  fi
  pass "Validation passed."

  if [[ -f ${target} && ! -L ${target} ]] && cmp -s -- "${temporary_file}" "${target}"; then
    if ! chmod 0755 "${target}"; then
      cleanup
      error "Unable to set hysteria-check permissions."
      printf 'Existing installation was not replaced.\n' >&2
      return 1
    fi
    cleanup
    pass "hysteria-check is already up to date."
    printf '\nMaintenance tools are up to date.\n'
    return 0
  fi

  if ! chmod 0755 "${temporary_file}"; then
    cleanup
    error "Unable to prepare hysteria-check permissions."
    printf 'Existing installation was not changed.\n' >&2
    return 1
  fi

  # The temporary file is in the target directory, so this rename stays on the
  # same filesystem and replaces the command atomically.
  if ! mv -f -- "${temporary_file}" "${target}"; then
    cleanup
    error "Unable to install hysteria-check."
    printf 'Existing installation was not changed.\n' >&2
    return 1
  fi
  temporary_file=""

  pass "hysteria-check updated successfully."
  printf '\nMaintenance tools are up to date.\n'
}

main() {
  local required_command

  printf 'Hysteria2 maintenance tools update\n\n'

  if [[ ${EUID} -ne 0 ]]; then
    error "Root privileges are required."
    printf 'Run: sudo hysteria-update\n' >&2
    return 1
  fi

  if [[ $# -ne 0 ]]; then
    error "hysteria-update does not accept arguments."
    return 1
  fi

  for required_command in bash chmod cmp mktemp mv rm; do
    if ! command -v "${required_command}" >/dev/null 2>&1; then
      error "Required command is missing: ${required_command}"
      return 1
    fi
  done

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    error "Neither curl nor wget is available; unable to download maintenance tools."
    return 1
  fi

  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM

  update_check_command "${CHECK_COMMAND}"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
