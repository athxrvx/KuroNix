#!/usr/bin/env bash
set -euo pipefail

geometry="${1:?missing capture geometry}"
tmpdir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/kuro-ocr.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

grim -l 0 -g "$geometry" "$tmpdir/region.png"
text="$(tesseract "$tmpdir/region.png" stdout 2>/dev/null | sed '/^[[:space:]]*$/d')"

if [[ -z "$text" ]]; then
  notify-send "Kuro OCR" "No text was found in the selected region."
  exit 0
fi

printf '%s' "$text" | wl-copy
notify-send "Kuro OCR" "Recognized text copied to the clipboard."
