# Working on Rolling Balance 16 with Codex

This repository is prepared for Codex-based development.

## Start here
Codex should read `AGENTS.md` before editing. That file defines engine versions, Android constraints, source-of-truth files, validation commands, and mobile-control requirements.

Then read `ARCHITECTURE.md` for the current design.

## Recommended first instruction to Codex

```text
Read AGENTS.md and ARCHITECTURE.md first. Inspect the current Godot project before editing. Keep Android 16 target SDK 36, ARM64, GL Compatibility, sensor rotation, responsive portrait/landscape UI, and the runtime smoke test working. After changes, run the prescribed checks if Godot is available and summarize any validation that must be delegated to GitHub Actions or a real Android device.
```

## Useful task examples

### Improve controls
```text
Improve the mobile rolling-ball controls so low-speed steering is precise but high-speed movement remains stable. Preserve camera-relative movement, the left virtual stick, right-side camera swipe, and all three ball modes. Run the smoke test afterward.
```

### Refactor the monolithic script
```text
Refactor game.gd into focused Godot scripts/scenes without changing gameplay behavior. Follow the decomposition suggested in ARCHITECTURE.md, keep main.tscn as the entry point, and keep ROLLING_BALANCE_READY working.
```

### Add a new level
```text
Add a second original level and a simple level-selection flow. Do not copy Ballance assets or layouts. Preserve Android orientation support and keep the existing level playable.
```

### Add audio
```text
Add an audio system architecture for rolling, collision, checkpoint, collectible, and finish sounds. Use placeholder/generated or appropriately licensed assets only. Rolling sound behavior should support different surface materials.
```

## Validation
If Godot 4.7.2 is installed in the Codex environment:

```bash
make check
```

For Android export when the Android toolchain is available:

```bash
make build-android
```

If the environment lacks Godot or Android SDK/export templates, Codex should still make coherent source changes, state what could not be executed locally, and use/inspect GitHub Actions for final build validation when available.

## Device-only checks
Some behavior still requires a real Android device and cannot be fully proven by headless CI:
- touch feel and joystick ergonomics;
- portrait/landscape rotation timing;
- display cutouts/safe areas;
- frame pacing and GPU performance;
- device-specific input/renderer behavior.
