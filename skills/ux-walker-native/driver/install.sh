#!/usr/bin/env bash
# Builds the nativeui driver into ~/.claude/bin. Idempotent and cheap to re-run:
# it recompiles only when the source is newer than the binary, so a skill can
# call it unconditionally at the start of a walk.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nativeui.swift"
BIN_DIR="${HOME}/.claude/bin"
BIN="${BIN_DIR}/nativeui"

mkdir -p "${BIN_DIR}"

if [ -x "${BIN}" ] && [ "${BIN}" -nt "${SRC}" ]; then
    echo "nativeui already current: ${BIN}"
else
    echo "building nativeui…"
    swiftc -O -o "${BIN}" "${SRC}" -framework AppKit -framework ApplicationServices
    echo "built ${BIN}"
fi

# Report permission state here rather than letting the first snapshot fail
# halfway into a walk.
"${BIN}" doctor
