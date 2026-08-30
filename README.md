# Rolling Balance 16

Godot 4.7.2 3D rolling-ball game prototype for Android 16. The project is prepared for iterative development with Codex and GitHub Actions.

The game uses original procedural geometry and generated materials; it does not contain copied Ballance assets, levels, textures, or music.

## Current status

- Version: 0.2.1.
- Engine: Godot 4.7.2 stable.
- Renderer: GL Compatibility.
- Android: target SDK 36, minimum SDK 29.
- Architecture: ARM64-v8a.
- Automatic portrait/landscape sensor rotation.
- Runtime smoke test before every Android CI build.

## Gameplay

- Physics-driven `RigidBody3D` ball.
- Camera-relative movement.
- WASD desktop controls for development.
- Floating touch joystick on the left side.
- Right-side swipe camera control.
- LIGHT / BALANCED / HEAVY ball modes.
- Procedural stone, wood, moss, metal, and ball textures.
- Checkpoints and respawn.
- Moving platforms and rotating obstacles.
- Collectible energy orbs.
- Responsive HUD for portrait and landscape.

## Codex

Read these files in order:

1. `AGENTS.md` — repository rules, constraints, and mandatory validation.
2. `ARCHITECTURE.md` — current system design and recommended refactor path.
3. `CODEX.md` — practical Codex workflow and example tasks.

OpenAI Codex supports repository guidance through `AGENTS.md`, so the project keeps stable development rules there.

## Project structure

```text
project.godot
main.tscn          # entry scene
game.gd            # active gameplay implementation
export_presets.cfg # Android 16 export preset
AGENTS.md           # Codex repository instructions
ARCHITECTURE.md     # design map
CODEX.md            # Codex workflow notes
Makefile            # local smoke/build commands
.github/workflows/build-android-apk.yml
```

## Run locally

Install Godot 4.7.2 Standard, import `project.godot`, and press Play.

Desktop controls:
- WASD — move;
- R — respawn;
- Q/E — camera helpers.

## Validate

```bash
make check
```

The smoke test must load the scene and print `ROLLING_BALANCE_READY` without GDScript/runtime errors.

## Build Android APK

With a configured Android SDK and Godot Android export templates:

```bash
make build-android
```

GitHub Actions also builds a debug APK after pushes to `main`. The workflow performs the runtime smoke test before packaging.

## Important

A successful APK export alone does not prove the game starts. The smoke test was added after an earlier build produced a gray screen because a GDScript parse error prevented the gameplay script from loading.
