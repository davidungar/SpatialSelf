#!/bin/bash
#
# build-self-vm.sh — rebuild Self.xcframework for SpatialSelf.
#
# Invoked by SpatialSelf's "Run Script: build Self.xcframework" build phase
# before the Sources/Frameworks/Resources phases, so the C++ Self VM library
# is always fresh when SpatialSelf links. Also runnable from a terminal.
#
# Env vars:
#   OURSELF64_PATH  VM source checkout (default: $HOME/self/vms/OurSelf/self64)
#   CONFIG          Debug | Release | RelWithDebInfo (default in xcframework script)
#   SELF_VM_LOG     full output log (default: /tmp/self-vm-build.log)
#

set -o pipefail

OURSELF64_PATH="${OURSELF64_PATH:-$HOME/self/vms/OurSelf/self64}"
SELF_VM_LOG="${SELF_VM_LOG:-/tmp/self-vm-build.log}"

# Strip outer xcodebuild env so the nested xcodebuild inside
# cmake-xcframework.sh does not inherit CONFIGURATION / BUILD_DIR / etc.
# and crash the build system. Augment PATH so cmake/ninja from Homebrew
# are reachable (Xcode's default PATH omits /opt/homebrew/bin).
CLEAN_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

env -i \
    HOME="$HOME" \
    USER="$USER" \
    PATH="$CLEAN_PATH" \
    ${CONFIG:+CONFIG="$CONFIG"} \
  "$OURSELF64_PATH/vm64/cmake-xcframework.sh" 2>&1 \
  | tee "$SELF_VM_LOG" \
  | awk '
      # clang/gcc native diagnostics (Xcode parses these verbatim)
      /^[ \t]*\/.+:[0-9]+:[0-9]+: (error|warning|note):/ { sub(/^[ \t]+/, ""); print; next }
      /^[ \t]*\/.+:[0-9]+: (error|warning|note):/        { sub(/^[ \t]+/, ""); print; next }

      # tool-prefixed errors
      /^(ld|clang|libtool): (error|warning):/ { print; next }

      # CMake errors — rewrite into file:line: error: form so Xcode parses
      /^CMake Error at / {
        match($0, /at .+:[0-9]+/)
        if (RSTART > 0) {
          loc = substr($0, RSTART+3, RLENGTH-3)
          print loc ": error: " $0
        }
        next
      }
      /^CMake Warning at / {
        match($0, /at .+:[0-9]+/)
        if (RSTART > 0) {
          loc = substr($0, RSTART+3, RLENGTH-3)
          print loc ": warning: " $0
        }
        next
      }

      /^[Ee]rror:/   { print; next }
      /BUILD FAILED/ { print; next }
    '

status=${PIPESTATUS[0]}
if [ "$status" -ne 0 ]; then
    echo "error: Self VM build failed — full log: $SELF_VM_LOG"
    exit "$status"
fi
