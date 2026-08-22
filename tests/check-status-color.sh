#!/usr/bin/env bash

# Verify that status colors appear only on suitable interactive terminals.

set -euo pipefail

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT
readonly CHECK_STATUS_SCRIPT="${REPOSITORY_ROOT}/scripts/check-status.sh"
readonly ANSI_PREFIX=$'\033['

contains_ansi() {
  [[ $1 == *"${ANSI_PREFIX}"* ]]
}

capture_check() {
  local output

  output="$("$@" 2>&1 || true)"
  printf '%s' "${output}"
}

plain_output="$(capture_check env -u NO_COLOR TERM=xterm bash "${CHECK_STATUS_SCRIPT}" 8.8.8.8)"
if contains_ansi "${plain_output}"; then
  printf 'Non-TTY output unexpectedly contains ANSI escape sequences.\n' >&2
  exit 1
fi

# GitHub-hosted Ubuntu runners provide util-linux script(1), which creates a
# pseudo-terminal for testing the interactive behavior. Other platforms still
# run the non-TTY compatibility check above.
if script --version 2>&1 | grep -q 'util-linux'; then
  printf -v check_command 'bash %q 8.8.8.8' "${CHECK_STATUS_SCRIPT}"

  tty_output="$(capture_check env -u NO_COLOR TERM=xterm script -qec "${check_command}" /dev/null)"
  if ! contains_ansi "${tty_output}"; then
    printf 'TTY output did not contain ANSI escape sequences.\n' >&2
    exit 1
  fi

  expected_sequences=(
    $'\033[32m[PASS]\033[0m'
    $'\033[36m[INFO]\033[0m'
    $'\033[33m[WARN]\033[0m'
    $'\033[31m[CRITICAL]\033[0m'
    $'- \033[33mWARNING:\033[0m '
    $'- \033[31mCRITICAL:\033[0m '
    $'Overall status: \033[31mCRITICAL ('
  )
  for expected_sequence in "${expected_sequences[@]}"; do
    if [[ ${tty_output} != *"${expected_sequence}"* ]]; then
      printf 'TTY output is missing an expected semantic color sequence.\n' >&2
      exit 1
    fi
  done

  no_color_output="$(capture_check env TERM=xterm NO_COLOR=1 script -qec "${check_command}" /dev/null)"
  if contains_ansi "${no_color_output}"; then
    printf 'NO_COLOR output unexpectedly contains ANSI escape sequences.\n' >&2
    exit 1
  fi

  dumb_output="$(capture_check env -u NO_COLOR TERM=dumb script -qec "${check_command}" /dev/null)"
  if contains_ansi "${dumb_output}"; then
    printf 'TERM=dumb output unexpectedly contains ANSI escape sequences.\n' >&2
    exit 1
  fi
else
  printf 'Skipping pseudo-TTY checks: util-linux script(1) is unavailable.\n'
fi

printf 'Color output checks passed.\n'
