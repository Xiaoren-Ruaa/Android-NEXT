#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${script_dir}/../lib/common.sh"

repo_dir="$(repo_root)"
manifest_path="${1:-${repo_dir}/manifests/bash.env}"
output_dir="${2:-${repo_dir}/dist/bash}"

load_manifest "$manifest_path"

require_cmd curl
require_cmd docker

resolved_version="${BASH_VERSION:-latest}"

if [[ "$resolved_version" == "latest" ]]; then
  log_step "Resolving latest Bash release"
  resolved_version="$(curl -fsSL https://ftp.gnu.org/gnu/bash/ | grep -oP 'bash-\K[0-9]+\.[0-9]+(?=\.tar\.gz)' | sort -V | tail -1)"
  [[ -n "$resolved_version" ]] || fail "unable to resolve latest Bash release"
fi

log_step "Building Bash ${resolved_version} for linux/arm64"

rm -rf "$output_dir"
ensure_dir "$output_dir"

docker run --rm --platform linux/arm64 \
  -e BASH_VERSION="$resolved_version" \
  -v "${repo_dir}:/workspace" \
  -w /workspace \
  "ubuntu:${UBUNTU_CONTAINER_TAG:-22.04}" \
  bash -lc '
    set -euo pipefail
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      wget \
      build-essential \
      file \
      flex \
      bison \
      libncurses-dev \
      autoconf \
      gettext \
      ca-certificates \
      xz-utils

    rm -rf build/bash
    mkdir -p build/bash dist/bash
    cd build/bash

    wget "https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz"
    tar -xzf "bash-${BASH_VERSION}.tar.gz"
    cd "bash-${BASH_VERSION}"

    ./configure \
      --enable-static-link \
      --enable-alias \
      --enable-arith-for-command \
      --enable-array-variables \
      --enable-bang-history \
      --enable-brace-expansion \
      --enable-casemod-attributes \
      --enable-casemod-expansions \
      --enable-command-timing \
      --enable-cond-command \
      --enable-cond-regexp \
      --enable-coprocesses \
      --enable-debugger \
      --enable-directory-stack \
      --enable-dparen-arithmetic \
      --enable-extended-glob \
      --enable-help-builtin \
      --enable-history \
      --enable-job-control \
      --enable-multibyte \
      --enable-net-redirections \
      --enable-process-substitution \
      --enable-progcomp \
      --enable-prompt-string-decoding \
      --enable-readline \
      --enable-restricted \
      --enable-select \
      --enable-single-help-strings \
      --enable-strict-posix-default \
      --enable-translatable-strings \
      --enable-usg-echo-default \
      --enable-xpg-echo-default \
      LDFLAGS="-static"

    make -j"$(nproc)"

    file ./bash | grep "statically linked" >/dev/null || { echo "bash is not statically linked" >&2; exit 1; }
    file ./bash | grep "ARM aarch64" >/dev/null || { echo "bash is not built for ARM64" >&2; exit 1; }

    strip ./bash
    cp ./bash /workspace/dist/bash/bash
  '

printf '%s\n' "$resolved_version" > "${output_dir}/VERSION"

log_step "Bash artifact written to ${output_dir}"