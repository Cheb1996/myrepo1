# Architecture — Rolling Balance 16

## Overview
Rolling Balance 16 is currently a compact Godot project whose level, materials, player, camera, UI, checkpoints, collectibles, and moving obstacles are created programmatically by `game.gd`.

The intentionally small structure makes the project easy to prototype, but future growth should split responsibilities into focused scripts/scenes rather than continuing to expand one monolithic file indefinitely.

## Startup flow
1. Godot loads `project.godot`.
2. `run/main_scene` opens `main.tscn`.
3. `main.tscn` attaches `game.gd` to the root `Node3D`.
4. `_ready()` creates materials, environment, level geometry, player ball, camera, UI, checkpoint positions, and responsive layout.
5. A successful startup prints `ROLLING_BALANCE_READY`; CI depends on this marker.

## Current systems

### Procedural level
`game.gd` creates `StaticBody3D` and `AnimatableBody3D` geometry at runtime. The course includes platforms, ramps, rails, checkpoint gates, moving platforms, sweepers, a goal, and kill/respawn volume.

### Materials and textures
Surface textures are generated with Godot `Image`/`ImageTexture` code at startup. This keeps the repository free of external texture dependencies and makes the current build self-contained.

### Player ball
The player is a `RigidBody3D` with a spherical collision shape. Input applies central force and torque. Three modes tune mass/response and appearance:
- LIGHT
- BALANCED
- HEAVY

### Controls
Desktop development controls use WASD and keyboard respawn/camera helpers.

Mobile controls use two touch roles:
- left-side movement using a floating virtual joystick;
- right-side horizontal drag for camera rotation.

Movement is camera-relative.

### Camera
A `Camera3D` follows the ball using a yaw-controlled offset. When the player is moving quickly and has not recently looked manually, the camera can gradually align with travel direction.

### UI and orientation
The HUD is generated in code. `Viewport.size_changed` triggers layout recalculation. The project is configured with sensor orientation and an expanding square reference viewport so UI can reflow between portrait and landscape.

### Progress
The course uses checkpoints for respawn progression and collectible energy orbs for optional score/progress feedback. The finish gate requires checkpoint progression.

## Android pipeline
`export_presets.cfg` defines an Android debug export with:
- Gradle build enabled;
- min SDK 29;
- target SDK 36;
- ARM64-v8a only.

GitHub Actions uses Godot 4.7.2, performs a runtime smoke test, ensures Android SDK packages, exports the APK, and uploads it as a workflow artifact.

## Recommended refactor path
When a task starts adding substantial new gameplay, prefer this decomposition:

```text
main.tscn
scripts/
  game.gd
  player_ball.gd
  mobile_controls.gd
  follow_camera.gd
  level_builder.gd
  hud.gd
  checkpoint_system.gd
resources/
  materials/
scenes/
  player_ball.tscn
  ui.tscn
```

Do the split incrementally and keep the game runnable after each step.

## Safe extension points
Good next systems include:
- main menu and level selection;
- multiple authored/procedural levels;
- audio manager with surface-dependent rolling sounds;
- save/progress system;
- pause/settings menu;
- graphics-quality presets;
- more robust camera collision;
- device safe-area handling;
- performance telemetry/debug overlay;
- automated gameplay/unit tests where practical.

## Important invariant
An APK that merely exports successfully is not considered healthy. The startup smoke test must load the scene, execute `game.gd`, and emit `ROLLING_BALANCE_READY` before Android packaging is trusted.
