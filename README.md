# SpatialSelf

SwiftUI host for the Self VM on visionOS. Owns a `TerminalView` window and links
the Self VM, which is **built from source** as a cross-project dependency on the
CMake-generated `Self.xcodeproj` in `~/self/vms/OurSelf/self64`.

## The Self VM dependency (read this first)

SpatialSelf's Xcode project has a cross-project reference to

```
~/self/vms/OurSelf/self64/cmake-build-AVP-compilation-check/Self.xcodeproj
```

links its `libSelfVM.a` product, and depends on its `Self` target — so Xcode builds
the VM (for whichever destination you pick, device or simulator) before the app.

**That VM project is GENERATED, not checked in.** On a fresh checkout, or after
deleting/cleaning build dirs, regenerate it *before* building SpatialSelf:

```sh
cd ~/self/vms/OurSelf/self64 && vm64/configure.sh visionos
```

That (re)creates `cmake-build-AVP-compilation-check/Self.xcodeproj`. The one
generated project builds both the `xros` (device) and `xrsimulator` slices on
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

The Swift sources live under `SpatialSelf/`; the `.xcodeproj` shell is too fragile
to write by hand, so rebuild it in the IDE:

1. Generate the VM project once:
   `~/self/vms/OurSelf/self64/vm64/configure.sh visionos`.
2. File → New → Project → **visionOS → App**; Product Name `SpatialSelf`;
   SwiftUI / Swift; save into `~/code/separatingForInlining/SpatialSelf/` (uncheck
   "Create Git repository"). Delete the stub `ContentView.swift` /
   `SpatialSelfApp.swift` and add the existing files to the target:
   `SpatialSelfApp.swift`, `SelfShellView.swift`, `SelfVMLauncher.swift`,
   `Terminal_IO_Redirector.swift`, `OutputStream.swift`.
3. Build Settings:
   - *Objective-C Bridging Header* = `SpatialSelf/SpatialSelf-Bridging-Header.h`
   - add `$(HOME)/self/vms/OurSelf/self64/vm64/build_support/embed` to
     *Header Search Paths* (for `self_vm.h`)
   - add `-lc++` and `-lncurses` to *Other Linker Flags*.
4. Drag `cmake-build-AVP-compilation-check/Self.xcodeproj` into the project
   navigator; in the target's *Frameworks, Libraries, and Embedded Content* add
   `libSelfVM.a` from its products ("Do Not Embed" — it's a static lib). Xcode
   wires the cross-project file reference, product proxy, and build dependency.
5. Package dependencies (target → General → Frameworks, Libraries):
   `Views` (from ReusableViews), `DavesUtilities`, and `VisionUtilities`
   (optional now; needed for future RealityKit work). These resolve as workspace
   packages from `Enchilada.xcworkspace`.
6. The workspace already references `SpatialSelf/SpatialSelf.xcodeproj`.

## Running

Open `Enchilada.xcworkspace`, select the **VisionSpatialSelf** scheme (or
**MacSpatialSelf** for the macOS host) + an **arm64** Apple Vision Pro simulator
(or device), ⌘R. The terminal window appears with the Self VM's `#` prompt; type
expressions, see output.
