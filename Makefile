SHELL := /bin/bash
GODOT ?= godot

.PHONY: check smoke build-android clean

check: smoke

smoke:
	@command -v $(GODOT) >/dev/null || { echo "Godot executable not found. Set GODOT=/path/to/godot"; exit 127; }
	@set -o pipefail; $(GODOT) --headless --path . --quit-after 5 --verbose 2>&1 | tee smoke.log
	@grep -q "ROLLING_BALANCE_READY" smoke.log || { echo "Startup marker missing"; exit 1; }
	@! grep -Eiq "SCRIPT ERROR|Parse Error|Invalid call|Invalid set index|Invalid get index|Nonexistent function|Attempt to call function|Cannot assign|Cannot call method" smoke.log || { echo "Runtime/script error detected"; exit 1; }
	@echo "Smoke test passed"

build-android: check
	@mkdir -p build
	$(GODOT) --headless --verbose --path . --install-android-build-template --export-debug "Android 16" build/RollingBalance16.apk
	@test -s build/RollingBalance16.apk
	@ls -lh build/RollingBalance16.apk

clean:
	rm -rf build smoke.log
