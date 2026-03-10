#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

export MCWHISPER_APPSHOT_RECORDING_PANEL=1
exec "$PROJECT_DIR/.build/debug/McWhisper"
