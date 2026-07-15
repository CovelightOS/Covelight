# /app

Tier 1: the Android kiosk wrapper. A plain Kotlin/Gradle app that embeds
the shell by depending on the stock Godot Android engine library
(`org.godotengine:godot`, Maven Central) — not through Godot's own
self-contained Android export. Device Owner provisioning, lock-task kiosk
mode, radios disabled by policy, and launcher replacement are T2.2, not
here. No Google Play Services dependency (CLAUDE.md #9), enforced by CI
(`assertNoGoogleDependencies`, wired into every build via `preBuild`), not
just discipline.

Protection here is **policy-based**, not structural — never describe it with
"air gap" or "cannot network" (CLAUDE.md #7; ARCHITECTURE.md §3.3).

**Tier:** tier1

**Status:** T2.1 (Godot Android export embedded in a Kotlin host app) —
engineering-complete, **awaiting human verification on a physical Android
8+ device** (`docs/plan/03-phase2-kiosk.md`'s `[CC+human]` acceptance —
not checked off until that happens).

## Why an embedded library, not Godot's own Android export

Godot has two ways to get a project onto Android: its own self-contained
export (produces a ready-to-install APK/AAB directly, optionally through a
Godot-generated Gradle project nested under `/shell`), or embedding the
engine as a library dependency inside an app you otherwise own. The repo
layout calls for `/app` to be a separate, ordinary Kotlin project — that
only fits the second shape, and it's the one that keeps T2.2's Device
Owner / lock-task code (real security surface, `security` review label per
CLAUDE.md) inside a normal, auditable Gradle project instead of mixed into
Godot-generated scaffolding.

## How it fits together

- `org.godotengine:godot:4.7.1.stable` (Maven Central) is the stock,
  unmodified Godot 4.7 engine, added as a normal Gradle dependency. Its own
  published dependency graph is exactly `kotlin-stdlib`,
  `androidx.fragment`, `androidx.documentfile` — verified against Maven
  Central's Gradle module metadata for this exact version, not assumed.
- `MainActivity` extends the library's `GodotActivity`. It adds fullscreen
  immersive mode and keeps the screen on; it does **not** add hardware
  back-button handling — `GodotActivity` already consumes back presses
  itself (forwards them into the running engine via `GodotLib.back()`
  rather than finishing the Activity — verified directly against
  `GodotActivity.kt`/`Godot.kt` at the 4.7-stable tag, not assumed from the
  docs).
- `shell.pck` — `/shell`'s resources, packed for Android
  (`godot --export-pack "Android"`, `shell/export_presets.cfg`'s
  `"Android"` preset) — ships as a plain asset
  (`app/src/main/assets/shell.pck`) and is loaded via
  `GodotHost#getCommandLine()` appending `--main-pack shell.pck`
  (`MainActivity.getCommandLine()`).
- The T1.4 GDExtension (`shell/rust/pck_verify`, Ed25519 PCK signature
  verification — the thing that makes constraint #3, "unsigned content
  never loads," real) is cross-compiled for Android
  (`shell/rust/build_gdextension_android.sh`, `arm64-v8a` +
  `armeabi-v7a`) and placed directly in `app/src/main/jniLibs/<abi>/` —
  **not** bundled inside `shell.pck`. Verified by testing, not assumed:
  `--export-pack` does not embed `.gdextension`-declared native libraries
  into the pck at all (only the `.gdextension` config file itself gets
  packed); Godot's Android runtime resolves the library by basename
  through the standard Android dynamic-linker search path either way, so
  this reaches the exact same runtime behavior Godot's own official
  Android export gets, just via ordinary Gradle native-library packaging
  instead of Godot's own exporter doing the copying. See
  `shell/README.md`'s "Android (T2.1)" section for the full chain of
  verification (engine source citations included) behind this.
- `assertNoGoogleDependencies` (`app/build.gradle.kts`) walks the resolved
  `debug`/`release` compile and runtime classpaths (dependency-graph
  metadata, not artifact downloads, so it can't be defeated by a
  dependency that merely fails to resolve) and fails the build if
  `com.google.android.gms`, `com.google.firebase`,
  `com.google.android.play`, or `com.android.billingclient` appears
  anywhere in the tree, direct or transitive. Wired into `preBuild`, so it
  runs on every build, not as an opt-in check — confirmed to actually
  catch a violation by temporarily adding
  `com.google.android.gms:play-services-base` and watching it fail on both
  the direct dependency and its transitive ones, then reverting.

## Building

Prerequisites beyond `/shell`'s own (Godot 4.7 editor, Rust toolchain):
an Android SDK (platform 36, build-tools 36.1.0) and NDK
`27.0.12077973` — matches exactly what `org.godotengine:godot:4.7.1.stable`
was itself built with
(`godotengine/godot`'s `platform/android/java/app/config.gradle` at the
`4.7-stable` tag), not chosen independently. JDK 17.

```sh
just android-apk
```

Or the underlying commands directly (also what CI runs):

```sh
shell/rust/build_gdextension_android.sh --release
godot --headless --path shell --export-pack "Android" build/shell.pck
# copy shell/build/shell.pck -> app/app/src/main/assets/shell.pck
# copy shell/addons/covelight_pck_verify/bin/android/<abi>/libcovelight_pck_verify.so
#   -> app/app/src/main/jniLibs/<abi>/
cd app && ./gradlew assembleDebug
```

`shell.pck` and `jniLibs/` are gitignored generated artifacts (same
convention as `shell/addons/covelight_pck_verify/bin/` — a compiled
output, not source), built fresh each time, not committed.

**Only real ARM devices (or an ARM system image) can run the result.**
The Godot engine AAR itself ships native code for `x86`/`x86_64` too, but
the GDExtension above is only cross-compiled for `arm64-v8a`/`armeabi-v7a`
(ARCHITECTURE.md's "phone already in the drawer" target — Android x86
hardware isn't part of that population) — on an x86_64 emulator the
engine would start but the GDExtension load would fail, which currently
means the whole project fails to compile at the script level (same
"missing binary breaks the whole project" behavior `shell/README.md`
documents for desktop). This is exactly why T2.1's acceptance criterion is
a **physical device** test, not an emulator one.

## What's not here yet

- Device Owner, lock-task, radio policy, status-bar suppression, install
  blocking, boot persistence — all T2.2.
- The parent exit path (T2.3), Companion provisioning (T2.4), signed PCK
  import over USB (T2.6) — all later Phase 2 tasks.
- App icon / launcher branding — `AndroidManifest.xml` currently has no
  `android:icon`; this is design work, out of scope for "the shell runs on
  Android."
