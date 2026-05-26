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
# configure.sh xcframework does not inherit CONFIGURATION / BUILD_DIR / etc.
# and crash the build system. Augment PATH so cmake/ninja from Homebrew
# are reachable (Xcode's default PATH omits /opt/homebrew/bin).
CLEAN_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

env -i \
    HOME="$HOME" \
    USER="$USER" \
    PATH="$CLEAN_PATH" \
    ${CONFIG:+CONFIG="$CONFIG"} \
  "$OURSELF64_PATH/vm64/configure.sh" xcframework 2>&1 \
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

# --- force SpatialSelf to relink against the just-rebuilt VM -----------------
# configure.sh recreates SelfVM.xcframework every run (fresh mtime), but Xcode
# caches its *extracted* copy of the xcframework (the "ProcessXCFramework" step)
# and will NOT re-extract just because the inner libSelfVM.a changed -- so the
# app silently keeps linking a STALE VM. This bit us on the
# use_real_instead_of_cpu_timer A/B (flag flipped in the lib, but the running
# app still showed the old behavior). Bump the inner libs' mtime AND drop
# Xcode's cached extraction so the link step is forced to pick up the new lib.
# Best-effort; never fails the build. Xcode exports OBJROOT/SYMROOT/BUILD_ROOT
# to Run Script phases (terminal runs leave them unset -> skipped harmlessly).
# -- claude & dmu 5/2026
XCF="$OURSELF64_PATH/cmake-build-AVP-framework/SelfVM.xcframework"
find "$XCF" -name 'libSelfVM.a' -exec touch {} + 2>/dev/null || true
for _root in "$OBJROOT" "$SYMROOT" "$BUILD_ROOT"; do
    { [ -n "$_root" ] && [ -d "$_root" ]; } || continue
    find "$_root" -maxdepth 5 -type d -path '*XCFrameworkIntermediates*' \
        -name 'SelfVM*' -prune -exec rm -rf {} + 2>/dev/null || true
done
echo "build-self-vm.sh: bumped SelfVM.xcframework and cleared its XCFramework extraction cache to force a relink"
