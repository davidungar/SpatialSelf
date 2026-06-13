# SpatialSelf

SwiftUI host for the Self VM, with a **visionOS** variant (`VisionSpatialSelf`) and
a **macOS** variant (`MacSpatialSelf`). Both targets share one Swift codebase under
`SpatialSelf/Shared/` and link the Self VM, which is **built from source** as a
cross-project dependency on CMake-generated `Self.xcodeproj`s in
`~/self/vms/OurSelf/self64`. The two targets exist only because the VM ships as two
separate static libs (one per SDK) from two generated projects; the Swift is 100%
shared.

## The Self VM dependency (read this first)

Each target has a cross-project reference to a generated `Self.xcodeproj`, links that
project's static-lib product, and depends on its `Self` target — so Xcode builds the
VM before the app:

| Target | Generated VM project | Linked lib | SDK |
|---|---|---|---|
| `VisionSpatialSelf` | `cmake-build-AVP-compilation-check/Self.xcodeproj` | `libSelfVM-visionos.a` | `xros` / `xrsimulator` |
| `MacSpatialSelf`    | `cmake-build-macos-lib/Self.xcodeproj`            | `libSelfVM-macos.a`    | `macosx` |

**Those VM projects are GENERATED, not checked in.** On a fresh checkout, or after
deleting/cleaning build dirs, regenerate the one(s) you need *before* building
SpatialSelf:

```sh
cd ~/self/vms/OurSelf/self64 && vm64/configure.sh visionos    # -> cmake-build-AVP-compilation-check
cd ~/self/vms/OurSelf/self64 && vm64/configure.sh macos-lib   # -> cmake-build-macos-lib
```

The visionOS project builds both the `xros` (device) and `xrsimulator` slices on
demand — Xcode picks the SDK from the active destination; CMake does not bake the
sysroot into the compile flags, so no separate per-slice configure is needed.

**arm64 only.** `libSelfVM.a` is arm64-only, so build for an **arm64** simulator or
device (the default on Apple Silicon). A *generic* simulator build that pulls in
x86_64 will fail to link (`found architecture 'arm64', required architecture
'x86_64'`); pick a concrete arm64 destination or pass `ARCHS=arm64`.

There is **no `Self.xcframework` and no "build the VM" Run Script anymore** — the VM
is an ordinary build dependency. A bonus of building from source: you can step from
Swift straight into the VM's C++ in the debugger.

> History: SpatialSelf used to link a prebuilt `SelfVM.xcframework` that a
> `scripts/build-self-vm.sh` Run Script phase rebuilt on every app build. That
> coupling was replaced by the cross-project dependency (May 2026). The leftover
> `Frameworks/SelfVM.xcframework` symlink and `scripts/build-self-vm.sh` are now
> unused. The `vm64/configure.sh xcframework` flow still exists if you ever need a
> standalone prebuilt framework.

## Recreating the Xcode project from scratch

The `.xcodeproj` shell is too fragile to write by hand, so rebuild it in the IDE.
The layout it must reproduce:

```
SpatialSelf/
  Shared/                       <- all Swift, shared by BOTH targets (synchronized folder)
    SelfApp.swift               (single @main -> SelfRootView)
    SelfRootView.swift          (terminal by default; macOS also offers the E.2 bridge test)
    SelfTerminalLauncher.swift
    SelfShellView.swift
    SnapshotStartView.swift
    SelfVM.swift                (shared VM-launch core)
    OutputStream.swift
    HostBridge.swift            \
    BridgeLauncher.swift         > macOS-only bridge trio, all #if os(macOS)
    BridgeTestView.swift        /
  SpatialSelf/                  <- visionOS target specifics
    SpatialSelf-Bridging-Header.h
  MacSpatialSelf/               <- macOS target specifics
    Assets.xcassets
```

1. Generate the VM projects once (see the dependency table above):
   `…/configure.sh visionos` and `…/configure.sh macos-lib`.
2. File → New → Project → **visionOS → App**; Product Name `SpatialSelf`;
   SwiftUI / Swift; save into `~/code/separatingForInlining/SpatialSelf/` (uncheck
   "Create Git repository"). Delete the stub `ContentView.swift` /
   `SpatialSelfApp.swift`. Add a second target: File → New → Target → **macOS →
   App**, Product Name `MacSpatialSelf`.
3. Rename the visionOS target/scheme `SpatialSelf` → `VisionSpatialSelf` (the scheme
   matches the target; keeps the two variants unambiguous).
4. Create the `Shared/` folder on disk with the files above and add it as a
   **synchronized folder group** to the project; in the group's File Inspector add it
   to *both* targets' membership. (In `project.pbxproj` it appears in each target's
   `fileSystemSynchronizedGroups`.) The macOS-only files compile away on visionOS via
   their `#if os(macOS)` guards, so no per-file membership exceptions are needed.
5. Build Settings shared by both targets:
   - *Objective-C Bridging Header* = `SpatialSelf/SpatialSelf-Bridging-Header.h`
   - add `$(HOME)/self/vms/OurSelf/self64/vm64/build_support/embed` to
     *Header Search Paths* (for `self_vm.h`)
   - add `-lc++` and `-lncurses` to *Other Linker Flags*
   - `ARCHS = arm64` (see the arm64-only note above).
   Per-target: `VisionSpatialSelf` → `SUPPORTED_PLATFORMS = xros xrsimulator`;
   `MacSpatialSelf` → `SDKROOT = macosx`.
6. Wire each target to its VM project. Drag
   `cmake-build-AVP-compilation-check/Self.xcodeproj` and
   `cmake-build-macos-lib/Self.xcodeproj` into the navigator; in *Frameworks,
   Libraries, and Embedded Content* add `libSelfVM-visionos.a` to `VisionSpatialSelf`
   and `libSelfVM-macos.a` to `MacSpatialSelf` ("Do Not Embed" — static libs). Xcode
   wires each cross-project file reference, product proxy, and build dependency.
7. Package dependencies (each target → General → Frameworks, Libraries):
   `Views` (from ReusableViews), `DavesUtilities`, and `VisionUtilities`
   (optional now; needed for future RealityKit work). These resolve as workspace
   packages from `Enchilada.xcworkspace`.
8. The workspace already references `SpatialSelf/SpatialSelf.xcodeproj`.
9. In the **MacSpatialSelf** scheme → Run → Arguments → Environment Variables, add
   `OS_ACTIVITY_MODE = disable` (silences os_log spew in the console). The generated
   VM project gets this automatically from CMake
   (`vm64/cmake/mac_osx.cmake` `XCODE_SCHEME_ENVIRONMENT`), but the hand-built
   SpatialSelf app scheme must set it by hand, so it is lost on every recreation.

## Running

Open `Enchilada.xcworkspace`, select the **VisionSpatialSelf** scheme (or
**MacSpatialSelf** for the macOS host) + an **arm64** Apple Vision Pro simulator
(or device), ⌘R. The terminal window appears with the Self VM's `#` prompt; type
expressions, see output.
