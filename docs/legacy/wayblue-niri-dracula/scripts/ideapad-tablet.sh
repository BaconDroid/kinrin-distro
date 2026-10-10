#!/usr/bin/env bash
# IdeaPad Flex 5 auto-rotate for Niri/Wayblue.
#
# Drives display rotation from the accelerometer via `monitor-sensor`
# (iio-sensor-proxy). No root, no input-group, no raw event-device access
# required — monitor-sensor reads the sensor over D-Bus.
#
# The touchpad is disabled by the laptop firmware when folded; this script
# does not need to manage it.
#
# If the rotation is 90° off, swap the right-up/left-up mappings below.

set -u

OUTPUT="eDP-1"

log() { echo "[ideapad-autorotate] $*"; }

# Discover the niri IPC socket when NIRI_SOCKET is not set (e.g. when started
# by systemd before niri imported its environment).
if [ -z "${NIRI_SOCKET:-}" ]; then
    export NIRI_SOCKET="$(ls -t "$XDG_RUNTIME_DIR"/niri.wayland-*.sock 2>/dev/null | head -1)"
fi

apply_transform() {
    niri msg output "$OUTPUT" transform "$1" >/dev/null 2>&1 || true
}

if ! command -v monitor-sensor >/dev/null 2>&1; then
    log "monitor-sensor not found (install iio-sensor-proxy). Exiting."
    exit 1
fi

log "auto-rotating $OUTPUT from accelerometer"
monitor-sensor 2>/dev/null | while read -r line; do
    case "$line" in
        *"orientation changed: normal")    apply_transform normal ;;
        *"orientation changed: bottom-up") apply_transform 180 ;;
        *"orientation changed: right-up")  apply_transform 270 ;;
        *"orientation changed: left-up")   apply_transform 90 ;;
    esac
done
