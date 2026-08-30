# AGENTS.md — Rolling Balance 16

## Purpose
This repository contains a Godot 4.7.2 3D rolling-ball game targeting Android 16. Treat this file as the primary repository-level instruction set for Codex.

## Product goal
Build an original mobile balance/rolling-ball game inspired by the general feel of classic 3D ball obstacle games, without copying copyrighted assets, level layouts, names, music, or textures.

## Toolchain
- Engine: Godot 4.7.2 stable.
- Language: GDScript.
- Renderer: GL Compatibility.
- Android target SDK: 36 (Android 16).
- Android minimum SDK: 29.
- Android architecture: ARM64-v8a only.
- Android export preset: `Android 16`.
- CI: GitHub Actions in `.github/workflows/build-android-apk.yml`.

## Repository map
- `project.godot`: engine, rendering, viewport, and orientation settings.
- `main.tscn`: application entry scene.
- `game.gd`: active game implementation and procedural level generation.
- `export_presets.cfg`: Android export configuration.
- `ARCHITECTURE.md`: current system design and extension points.
- `CODEX.md`: practical workflow notes and example Codex tasks.
- `.github/workflows/build-android-apk.yml`: smoke test + Android APK build.

## Source-of-truth rules
- `game.gd` is the active gameplay script.
- Do not recreate the obsolete `main.gd` or `main_fixed.gd` files.
- Keep `main.tscn` as the entry scene unless a task explicitly introduces a scene-based architecture.
- If splitting `game.gd`, use descriptive scripts such as `player_ball.gd`, `mobile_controls.gd`, `level_builder.gd`, and `hud.gd` and update `ARCHITECTURE.md`.

## Mandatory compatibility constraints
- Preserve automatic phone rotation between portrait and landscape.
- Preserve responsive UI layout after viewport size/orientation changes.
- Keep `handheld/orientation=6` unless a task explicitly changes orientation behavior.
- Preserve `stretch/aspect="expand"` unless a replacement is tested in both portrait and landscape.
- Keep GL Compatibility renderer for broad Android support unless a task explicitly changes rendering strategy.
- Do not add x86, x86_64, or armeabi-v7a Android builds unless requested.
- Do not lower target SDK below 36.

## GDScript rules
- Code must parse cleanly on Godot 4.7.2.
- Prefer explicit types when expressions involve `clamp`, `min`, `max`, arithmetic on Variants, arrays, or API calls that can return Variant.
- Avoid ambiguous `var x := ...` inference when Godot can infer Variant; use forms such as `var x: float = ...`.
- Treat parse warnings that can become build errors as failures.
- Keep public constants and gameplay tuning values grouped near the top of their owning script.
- Use descriptive function names and keep physics code deterministic where practical.
- Avoid per-frame allocation in hot paths when a simple cached value is sufficient.

## Mobile input requirements
- Movement must be usable with touch only.
- The left side of the screen owns movement/virtual-stick interaction.
- The right side owns camera-look gestures unless a future control scheme explicitly replaces this.
- Movement direction should remain camera-relative.
- Touch targets should remain comfortably usable in both portrait and landscape.
- Desktop WASD and respawn controls should continue to work for development/testing.

## Physics requirements
- The ball is a `RigidBody3D` and should continue to feel physically simulated rather than kinematic.
- Preserve checkpoint respawn behavior.
- Avoid extreme forces that make the ball tunnel through geometry or become uncontrollable.
- If changing movement force, torque, damping, mass, or maximum speed, test LIGHT, BALANCED, and HEAVY modes.

## Visual/content rules
- Prefer original procedural materials or repository-owned assets.
- Do not import copyrighted Ballance assets or cloned level geometry.
- Keep mobile GPU cost reasonable: avoid unnecessarily large textures, excessive transparent layers, and large numbers of dynamic lights.
- If external assets are introduced, document their license and source in the repository.

## Runtime smoke test
Before considering a gameplay change complete, run:

```bash
godot --headless --path . --quit-after 5 --verbose 2>&1 | tee smoke.log
```

Success requires:
- process exits successfully;
- log contains `ROLLING_BALANCE_READY`;
- no `SCRIPT ERROR`, `Parse Error`, invalid-call, or similar runtime/script errors.

The helper target is:

```bash
make check
```

If Godot is not installed in the current Codex environment, report that limitation and rely on the repository GitHub Actions workflow after committing the change.

## Android build validation
For a full local/CI Android build, use:

```bash
make build-android
```

Equivalent Godot export command:

```bash
godot --headless --verbose --path . --install-android-build-template --export-debug "Android 16" build/RollingBalance16.apk
```

A successful APK build is not enough by itself; the runtime smoke test must pass first.

## Generated files
Do not commit:
- `.godot/`;
- `build/`;
- APK/AAB binaries;
- `smoke.log`;
- local export credentials or signing secrets.

## CI expectations
- Keep the runtime smoke-test step before Android export.
- Do not weaken the smoke test merely to make CI green.
- A change that breaks the `ROLLING_BALANCE_READY` startup marker is incomplete unless the marker is intentionally replaced everywhere, including CI.

## Definition of done
For code changes:
1. Inspect relevant repository files before editing.
2. Preserve Android 16 and orientation constraints unless explicitly changed.
3. Run `make check` when Godot is available.
4. Run/build through GitHub Actions when Android validation is needed.
5. Update documentation when architecture, controls, build steps, or file responsibilities change.
6. Summarize what changed, what was tested, and any remaining device-only validation that cannot be performed in the current environment.
