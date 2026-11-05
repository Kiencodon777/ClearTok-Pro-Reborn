#!/usr/bin/env bash
set -euo pipefail
python3 "$(dirname "$0")/build_obfuscated.py" ios --symbols "${1:?Private symbol directory required}" --flutter "${FLUTTER_BIN:-flutter}"
