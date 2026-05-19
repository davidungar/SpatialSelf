# SpatialSelf

SwiftUI host for the Self VM on visionOS. Owns a `TerminalView` window and
links `Self.xcframework` produced from `~/self/vms/OurSelf/self64`.

## One-time project setup

The Swift sources are already laid out under `SpatialSelf/`; you just need to
create the Xcode project shell around them (`pbxproj` is too fragile to write
by hand).

1. **Build the xcframework** in OurSelf64:
   ```
   ~/self/vms/OurSelf/self64/vm64/cmake-xcframework.sh
   ```
   Drops `Self.xcframework` in `cmake-build-xcframework/`. Copy or symlink it
   into `SpatialSelf/Frameworks/`.

2. **Create the Xcode project** at `SpatialSelf/SpatialSelf.xcodeproj`:
   - File → New → Project → **visionOS → App**
   - Product Name: `SpatialSelf`
   - Interface: SwiftUI, Language: Swift
   - Save into `~/code/separatingForInlining/SpatialSelf/` (uncheck
     "Create Git repository").
   - Xcode will create stub `ContentView.swift` and `SpatialSelfApp.swift`
     — **delete those stubs** and add the existing files in this directory
     to the target:
     - `SpatialSelfApp.swift`
     - `SelfShellView.swift`
     - `SelfVMLauncher.swift`
     - `Terminal_IO_Redirector.swift`
     - `OutputStream.swift`

3. **Bridging header**: in Build Settings, set *Objective-C Bridging Header*
   to `SpatialSelf/SpatialSelf-Bridging-Header.h`.

4. **Link the xcframework**: drag `Frameworks/Self.xcframework` into the
   project navigator; in target's *Frameworks, Libraries, and Embedded
   Content*, set it to "Do Not Embed" (it's a static lib inside the
   xcframework).

5. **Package dependencies** (target → General → Frameworks, Libraries):
   - `Views` (from ReusableViews)
   - `DavesUtilities`
   - `VisionUtilities` (optional now; needed for future RealityKit work)

   These packages are already in `Enchilada.xcworkspace` as `FileRef`s, so
   they resolve as workspace packages.

6. **Workspace** already references `SpatialSelf/SpatialSelf.xcodeproj` —
   no manual add needed.

7. **Auto-rebuild xcframework on each build.** SpatialSelf has a
   `Run Script: build Self.xcframework` build phase that runs before the
   sources phase and invokes `scripts/build-self-vm.sh`. That script:
   - clears Xcode's build env (so cmake's nested xcodebuild doesn't crash),
   - augments PATH so Homebrew cmake/ninja are reachable,
   - runs `vm64/cmake-xcframework.sh`,
   - tees the full output to `/tmp/self-vm-build.log`, and
   - forwards only diagnostic lines (clang `file:line:col: error:`, ld
     errors, etc.) to Xcode so the issue navigator catches them.

   Run it standalone from a terminal whenever you want a manual VM
   rebuild without going through Xcode:
   ```sh
   ~/code/separatingForInlining/SpatialSelf/scripts/build-self-vm.sh
   ```
   Env overrides: `OURSELF64_PATH`, `CONFIG` (Debug/Release/RelWithDebInfo),
   `SELF_VM_LOG`.

## Running

Open `Enchilada.xcworkspace`, select the **SpatialSelf** scheme + an Apple
Vision Pro simulator (or device), ⌘R. The terminal window appears with the
Self VM's `#` prompt; type expressions, see output.
