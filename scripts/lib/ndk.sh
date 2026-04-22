#!/usr/bin/env bash
# Android NDK toolchain helpers.
# This file must be SOURCED, not executed directly.
# Requires scripts/lib/common.sh to be sourced first.

# -------------------------------------------------------------------
# ndk_locate
#   Prints the NDK root path. Prefers explicit NDK_ROOT, then
#   GitHub Actions pre-installed $ANDROID_NDK_LATEST_HOME, then
#   $ANDROID_NDK_ROOT, then $ANDROID_NDK_HOME.
# -------------------------------------------------------------------
ndk_locate() {
  local root="${NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}}}"
  [[ -n "$root" ]] || fail \
    "Android NDK not found. Set one of: NDK_ROOT, ANDROID_NDK_LATEST_HOME, ANDROID_NDK_ROOT, ANDROID_NDK_HOME"
  [[ -d "$root" ]] || fail "NDK path does not exist: $root"
  echo "$root"
}

# -------------------------------------------------------------------
# ndk_setup_env <api_level> [arch]
#   Exports CC, CXX, AR, AS, LD, NM, RANLIB, READELF, STRIP, OBJCOPY,
#   SYSROOT, ANDROID_NDK_ROOT, NDK_TOOLCHAIN, ANDROID_API,
#   ANDROID_TARGET, ANDROID_TARGET_API.
#
#   arch defaults to "aarch64".
#   api_level: e.g. 21, 28, 33
# -------------------------------------------------------------------
ndk_setup_env() {
  local api="${1:-21}"
  local arch="${2:-aarch64}"

  local ndk_root
  ndk_root="$(ndk_locate)"

  local host_tag="linux-x86_64"
  local toolchain="${ndk_root}/toolchains/llvm/prebuilt/${host_tag}"
  [[ -d "$toolchain" ]] || fail "NDK toolchain prebuilt not found: $toolchain"

  local target="${arch}-linux-android"

  export ANDROID_NDK_ROOT="$ndk_root"
  export NDK_TOOLCHAIN="$toolchain"
  export ANDROID_API="$api"
  export ANDROID_TARGET="$target"
  export ANDROID_TARGET_API="${target}${api}"
  export SYSROOT="${toolchain}/sysroot"

  export CC="${toolchain}/bin/${target}${api}-clang"
  export CXX="${toolchain}/bin/${target}${api}-clang++"
  export AR="${toolchain}/bin/llvm-ar"
  export AS="${toolchain}/bin/llvm-as"
  export LD="${toolchain}/bin/ld.lld"
  export NM="${toolchain}/bin/llvm-nm"
  export RANLIB="${toolchain}/bin/llvm-ranlib"
  export READELF="${toolchain}/bin/llvm-readelf"
  export STRIP="${toolchain}/bin/llvm-strip"
  export OBJCOPY="${toolchain}/bin/llvm-objcopy"

  [[ -f "$CC" ]] || fail "NDK clang not found: $CC. Check that API level ${api} is supported by this NDK."

  local ndk_version
  ndk_version="$(grep 'Pkg.Revision' "${ndk_root}/source.properties" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')"
  log_step "NDK ${ndk_version:-unknown} | target: ${ANDROID_TARGET_API} | toolchain: ${toolchain}"
}

# -------------------------------------------------------------------
# ndk_check_binary <path>
#   Verifies that <path> is an aarch64 ELF binary.
# -------------------------------------------------------------------
ndk_check_binary() {
  local binary="$1"
  [[ -f "$binary" ]] || fail "Binary not found: $binary"
  file "$binary" | grep -qE "aarch64|ARM aarch64" || \
    fail "Binary is not aarch64: $(file "$binary")"
  log_step "Verified: $(file "$binary")"
}
