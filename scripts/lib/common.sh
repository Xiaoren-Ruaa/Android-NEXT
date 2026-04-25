#!/usr/bin/env bash

set -euo pipefail

repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/../.." >/dev/null 2>&1 && pwd
}

log_step() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

ensure_dir() {
  mkdir -p "$1"
}

download_file() {
  local url="$1"
  local output_path="$2"

  curl -fsSL "$url" -o "$output_path"
}

extract_archive() {
  local archive_path="$1"
  local target_dir="$2"

  ensure_dir "$target_dir"

  case "$archive_path" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive_path" -C "$target_dir"
      ;;
    *.tar.xz)
      tar -xJf "$archive_path" -C "$target_dir"
      ;;
    *.tar.bz2)
      tar -xjf "$archive_path" -C "$target_dir"
      ;;
    *)
      fail "unsupported archive format: $archive_path"
      ;;
  esac
}

load_manifest() {
  local manifest_path="$1"

  [[ -f "$manifest_path" ]] || fail "manifest not found: $manifest_path"

  set -a
  # shellcheck disable=SC1091
  source <(tr -d '\r' < "$manifest_path")
  set +a
}