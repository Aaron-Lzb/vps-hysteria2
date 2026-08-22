#!/usr/bin/env bash

# Exercise the maintenance-tool updater without touching /usr/local/bin.

set -euo pipefail

TEST_REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TEST_REPOSITORY_ROOT
readonly TEST_UPDATE_SCRIPT="${TEST_REPOSITORY_ROOT}/scripts/update-tools.sh"
readonly TEST_INSTALL_SCRIPT="${TEST_REPOSITORY_ROOT}/scripts/install-hysteria.sh"
readonly TEST_ANSI_PREFIX=$'\033['

# The sourced production script is checked separately.
# shellcheck disable=SC1090,SC1091
source "${TEST_UPDATE_SCRIPT}"

test_root="$(mktemp -d)"
readonly test_root
trap 'rm -rf -- "${test_root}"' EXIT

fail() {
  printf 'Updater test failed: %s\n' "$1" >&2
  exit 1
}

contains_ansi() {
  [[ $1 == *"${TEST_ANSI_PREFIX}"* ]]
}

assert_no_temporary_files() {
  local target=$1
  local temporary_path

  for temporary_path in "${target}.tmp."*; do
    [[ ! -e ${temporary_path} ]] || fail "temporary file was not cleaned up"
  done
}

file_mode() {
  local path=$1

  if stat -c '%a' "${path}" >/dev/null 2>&1; then
    stat -c '%a' "${path}"
  else
    stat -f '%Lp' "${path}"
  fi
}

file_inode() {
  local path=$1

  if stat -c '%i' "${path}" >/dev/null 2>&1; then
    stat -c '%i' "${path}"
  else
    stat -f '%i' "${path}"
  fi
}

run_update() {
  local target=$1

  set +e
  update_output="$(update_check_command "${target}" 2>&1)"
  update_status=$?
  set -e
}

mkdir -p "${test_root}/target" "${test_root}/fixtures" "${test_root}/fake-bin" "${test_root}/empty-bin" "${test_root}/outside"
target="${test_root}/target/hysteria-check"
valid_download="${test_root}/fixtures/check-status.sh"
original_installation="${test_root}/fixtures/original-check"

printf '#!/usr/bin/env bash\nprintf "updated maintenance check\\n"\n' >"${valid_download}"
printf '#!/usr/bin/env bash\nprintf "original maintenance check\\n"\n' >"${original_installation}"

# Verify the production downloader falls back to wget when curl is unavailable.
cat >"${test_root}/fake-bin/wget" <<'EOF'
#!/bin/bash
destination=""
for argument in "$@"; do
  case "${argument}" in
    --output-document=*) destination=${argument#*=} ;;
  esac
done
[[ -n ${destination} ]]
/bin/cp -- "${DOWNLOAD_FIXTURE}" "${destination}"
EOF
chmod 0755 "${test_root}/fake-bin/wget"
export DOWNLOAD_FIXTURE="${valid_download}"
PATH="${test_root}/fake-bin" download_check_script "${test_root}/wget-download"
cmp -s "${valid_download}" "${test_root}/wget-download" || fail "wget fallback did not download the fixture"

set +e
PATH="${test_root}/empty-bin" download_check_script "${test_root}/missing-tools-download"
missing_tools_status=$?
set -e
[[ ${missing_tools_status} -ne 0 ]] || fail "missing curl/wget was not rejected"

# Use deterministic local fixtures for all installation safety tests.
download_fixture="${valid_download}"
download_should_fail=0
download_check_script() {
  if [[ ${download_should_fail} -eq 1 ]]; then
    return 1
  fi
  cp -- "${download_fixture}" "$1"
}

cp -- "${original_installation}" "${target}"
chmod 0700 "${target}"
run_update "${target}"
[[ ${update_status} -eq 0 ]] || fail "successful update returned a nonzero status"
cmp -s "${valid_download}" "${target}" || fail "successful update installed the wrong content"
[[ $(file_mode "${target}") == "755" ]] || fail "successful update did not set mode 0755"
[[ ${update_output} == *"hysteria-check updated successfully."* ]] || fail "successful update message is missing"
assert_no_temporary_files "${target}"

existing_inode="$(file_inode "${target}")"
run_update "${target}"
[[ ${update_status} -eq 0 ]] || fail "already-current update returned a nonzero status"
[[ ${update_output} == *"hysteria-check is already up to date."* ]] || fail "already-current message is missing"
[[ $(file_inode "${target}") == "${existing_inode}" ]] || fail "already-current command was replaced"
assert_no_temporary_files "${target}"

cp -- "${original_installation}" "${target}"
download_should_fail=1
run_update "${target}"
[[ ${update_status} -ne 0 ]] || fail "download failure returned success"
cmp -s "${original_installation}" "${target}" || fail "download failure changed the existing command"
[[ ${update_output} == *"Existing installation was not changed."* ]] || fail "download failure protection message is missing"
assert_no_temporary_files "${target}"

download_should_fail=0

invalid_empty="${test_root}/fixtures/empty"
invalid_shebang="${test_root}/fixtures/invalid-shebang"
invalid_syntax="${test_root}/fixtures/invalid-syntax"
: >"${invalid_empty}"
printf 'printf "missing shebang\\n"\n' >"${invalid_shebang}"
printf '#!/usr/bin/env bash\nif then\n' >"${invalid_syntax}"

for download_fixture in "${invalid_empty}" "${invalid_shebang}" "${invalid_syntax}"; do
  cp -- "${original_installation}" "${target}"
  run_update "${target}"
  [[ ${update_status} -ne 0 ]] || fail "invalid download returned success"
  cmp -s "${original_installation}" "${target}" || fail "invalid download changed the existing command"
  assert_no_temporary_files "${target}"
done

# The installed updater is standalone: invoke a copied command outside the
# checkout and verify the required non-root refusal without repository access.
installed_updater="${test_root}/outside/hysteria-update"
cp -- "${TEST_UPDATE_SCRIPT}" "${installed_updater}"
chmod 0755 "${installed_updater}"

if [[ ${EUID} -ne 0 ]]; then
  set +e
  root_output="$(cd / && env -u NO_COLOR TERM=xterm "${installed_updater}" 2>&1)"
  root_status=$?
  set -e
  [[ ${root_status} -ne 0 ]] || fail "non-root invocation returned success"
  [[ ${root_output} == *"[ERROR] Root privileges are required."* ]] || fail "non-root error is missing"
  [[ ${root_output} == *"Run: sudo hysteria-update"* ]] || fail "sudo guidance is missing"
  contains_ansi "${root_output}" && fail "non-TTY updater output contains ANSI escapes"

  if script --version 2>&1 | grep -q 'util-linux'; then
    printf -v updater_command '%q' "${installed_updater}"
    tty_output="$(env -u NO_COLOR TERM=xterm script -qec "${updater_command}" /dev/null 2>&1 || true)"
    [[ ${tty_output} == *$'\033[31m[ERROR]\033[0m'* ]] || fail "TTY error color is missing"

    no_color_output="$(env TERM=xterm NO_COLOR=1 script -qec "${updater_command}" /dev/null 2>&1 || true)"
    contains_ansi "${no_color_output}" && fail "NO_COLOR updater output contains ANSI escapes"

    dumb_output="$(env -u NO_COLOR TERM=dumb script -qec "${updater_command}" /dev/null 2>&1 || true)"
    contains_ansi "${dumb_output}" && fail "TERM=dumb updater output contains ANSI escapes"
  else
    printf 'Skipping updater pseudo-TTY checks: util-linux script(1) is unavailable.\n'
  fi
else
  printf 'Skipping non-root entry-point checks while running tests as root.\n'
fi

grep -Fq 'https://raw.githubusercontent.com/Aaron-Lzb/vps-hysteria2/main/scripts/check-status.sh' "${TEST_UPDATE_SCRIPT}" \
  || fail "official fixed download source is missing"
grep -Fq '/usr/local/bin/hysteria-check' "${TEST_UPDATE_SCRIPT}" \
  || fail "fixed maintenance target is missing"
grep -Fq 'update-tools.sh' "${TEST_INSTALL_SCRIPT}" \
  || fail "installer does not reference the updater source"
grep -Fq '/usr/local/bin/hysteria-update' "${TEST_INSTALL_SCRIPT}" \
  || fail "installer does not install the global updater"

if grep -Eq 'systemctl[[:space:]]+(restart|reload)|apt(-get)?[[:space:]]+(update|upgrade|install)|certbot[[:space:]]+renew|ufw[[:space:]]|iptables[[:space:]]|nft[[:space:]]|/etc/hysteria' "${TEST_UPDATE_SCRIPT}"; then
  fail "updater crossed the maintenance-tool safety boundary"
fi

printf 'Maintenance updater checks passed.\n'
