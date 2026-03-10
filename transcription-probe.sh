#!/bin/zsh
set -euo pipefail

swift build --disable-sandbox --product TranscriptionProbe
exec ./.build/debug/TranscriptionProbe "$@"
