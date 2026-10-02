#!/bin/bash
set -euo pipefail

TOOL_VERSIONS_FILE="${TOOL_VERSIONS_FILE:-/azp/tool-versions.tsv}"

usage() {
  echo "usage: recordversion.sh [--extract PATTERN] NAME COMMAND [ARGS...]" >&2
}

extract_pattern=""
if [ "${1:-}" = "--extract" ]; then
  if [ "$#" -lt 4 ]; then
    usage
    exit 2
  fi
  extract_pattern="$2"
  shift 2
fi

if [ "$#" -lt 2 ]; then
  usage
  exit 2
fi

name="$1"
shift

set +e
output="$("$@" 2>&1)"
status=$?
set -e

if [ "$status" -ne 0 ]; then
  printf '%s\n' "$output" >&2
  exit "$status"
fi

if [ -n "$extract_pattern" ]; then
  extracted="$(printf '%s\n' "$output" | grep -i -m 1 -E -- "$extract_pattern" || true)"
  if [ -z "$extracted" ]; then
    echo "recordversion.sh: no line matching ${extract_pattern} in ${name} output" >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
  output="$extracted"
fi

normalized="$(printf '%s' "$output" | tr '\t\n\r' '   ' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
row="$(printf '%s\t%s' "$name" "$normalized")"
printf '%s\n' "$row" | tee -a "${TOOL_VERSIONS_FILE}"
