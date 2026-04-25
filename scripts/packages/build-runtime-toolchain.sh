#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${script_dir}/../lib/common.sh"

repo_dir="$(repo_root)"
manifest_path="${1:-${repo_dir}/manifests/runtime-toolchain.env}"
output_dir="${2:-${repo_dir}/dist/runtime-toolchain}"

load_manifest "$manifest_path"

require_cmd curl
require_cmd tar
require_cmd find

artifact_name="${ARTIFACT_NAME:-runtime-toolchain-arm64}"
work_dir="${BUILD_WORK_DIR:-${repo_dir}/build/runtime-toolchain}"
downloads_dir="${work_dir}/downloads"
extract_dir="${work_dir}/extract"
bundle_root="${output_dir}/toolchain"
archive_path="${output_dir}/${artifact_name}.tar.gz"
manifest_output="${output_dir}/MANIFEST.txt"

node_archive="node-${NODE_VERSION}-linux-arm64.tar.xz"
node_url="https://nodejs.org/dist/${NODE_VERSION}/${node_archive}"

uv_archive="uv-aarch64-unknown-linux-gnu.tar.gz"
uv_url="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${uv_archive}"

python_url="https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_STANDALONE_RELEASE}/${PYTHON_STANDALONE_ASSET}"

nvm_archive="nvm-${NVM_VERSION#v}.tar.gz"
nvm_url="https://github.com/nvm-sh/nvm/archive/refs/tags/${NVM_VERSION}.tar.gz"

extract_single_child_dir() {
  local source_dir="$1"
  local destination_dir="$2"
  local child_dir

  child_dir="$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [[ -n "$child_dir" ]] || fail "no extracted directory found in ${source_dir}"
  mv "$child_dir" "$destination_dir"
}

write_exec_wrapper() {
  local name="$1"
  local target="$2"

  cat > "${bundle_root}/bin/${name}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
script_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\${script_dir}/../${target}" "\$@"
EOF
  chmod +x "${bundle_root}/bin/${name}"
}

write_nvm_wrapper() {
  cat > "${bundle_root}/bin/nvm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../env.sh
source "${script_dir}/../env.sh"
nvm "$@"
EOF
  chmod +x "${bundle_root}/bin/nvm"
}

rm -rf "$work_dir" "$output_dir"
ensure_dir "$downloads_dir"
ensure_dir "$extract_dir"
ensure_dir "${bundle_root}/opt"
ensure_dir "${bundle_root}/bin"

log_step "Downloading Node.js ${NODE_VERSION}"
download_file "$node_url" "${downloads_dir}/${node_archive}"
extract_archive "${downloads_dir}/${node_archive}" "${extract_dir}/node"
extract_single_child_dir "${extract_dir}/node" "${bundle_root}/opt/node"

log_step "Downloading uv ${UV_VERSION}"
download_file "$uv_url" "${downloads_dir}/${uv_archive}"
extract_archive "${downloads_dir}/${uv_archive}" "${extract_dir}/uv"
extract_single_child_dir "${extract_dir}/uv" "${bundle_root}/opt/uv"

log_step "Downloading Python standalone ${PYTHON_STANDALONE_ASSET}"
download_file "$python_url" "${downloads_dir}/${PYTHON_STANDALONE_ASSET}"
extract_archive "${downloads_dir}/${PYTHON_STANDALONE_ASSET}" "${extract_dir}/python"
[[ -d "${extract_dir}/python/python" ]] || fail "python standalone archive layout changed"
mv "${extract_dir}/python/python" "${bundle_root}/opt/python"

log_step "Downloading nvm ${NVM_VERSION}"
download_file "$nvm_url" "${downloads_dir}/${nvm_archive}"
extract_archive "${downloads_dir}/${nvm_archive}" "${extract_dir}/nvm"
extract_single_child_dir "${extract_dir}/nvm" "${bundle_root}/opt/nvm"

log_step "Writing command wrappers"
write_exec_wrapper node "opt/node/bin/node"
write_exec_wrapper npm "opt/node/bin/npm"
write_exec_wrapper npx "opt/node/bin/npx"
write_exec_wrapper corepack "opt/node/bin/corepack"
write_exec_wrapper python "opt/python/bin/python"
write_exec_wrapper python3 "opt/python/bin/python3"
write_exec_wrapper pip "opt/python/bin/pip"
write_exec_wrapper pip3 "opt/python/bin/pip3"
write_exec_wrapper uv "opt/uv/uv"
write_nvm_wrapper

cat > "${bundle_root}/env.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TOOLCHAIN_ROOT="${script_dir}"
export NVM_DIR="${TOOLCHAIN_ROOT}/opt/nvm"
export PATH="${TOOLCHAIN_ROOT}/bin:${PATH}"

if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "${NVM_DIR}/nvm.sh"
fi
EOF
chmod +x "${bundle_root}/env.sh"

cat > "${bundle_root}/README.txt" <<EOF
ARM64 runtime bundle contents

- node, npm, npx, corepack
- python, python3, pip, pip3
- uv
- nvm

Usage:
  source ./env.sh
  node --version
  npm --version
  python3 --version
  uv --version
  nvm --version

Compatibility note:
  This bundle targets linux-arm64 with glibc. It is suitable for arm64 rootfs,
  containers, chroot/proot style environments, and similar Linux userspaces.
  It is not a direct replacement for fully static /system/bin binaries on stock Android.
EOF

cat > "$manifest_output" <<EOF
ARTIFACT_NAME=${artifact_name}
NODE_VERSION=${NODE_VERSION}
UV_VERSION=${UV_VERSION}
NVM_VERSION=${NVM_VERSION}
PYTHON_STANDALONE_RELEASE=${PYTHON_STANDALONE_RELEASE}
PYTHON_STANDALONE_ASSET=${PYTHON_STANDALONE_ASSET}
NODE_URL=${node_url}
UV_URL=${uv_url}
PYTHON_URL=${python_url}
NVM_URL=${nvm_url}
EOF

tar -czf "$archive_path" -C "$output_dir" toolchain

log_step "Runtime bundle written to ${archive_path}"