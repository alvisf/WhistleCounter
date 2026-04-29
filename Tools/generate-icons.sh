#!/usr/bin/env bash
# Render Tools/icon.html to three 1024x1024 PNGs using headless Chrome.
#
# Chrome writes the screenshot in ~1 second then lingers doing cleanup
# that can take 30+ seconds (or hang entirely). So we poll for the
# output file and kill Chrome as soon as it appears.

set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [[ ! -x "$CHROME" ]]; then
  echo "Error: Google Chrome not found at $CHROME" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HTML_PATH="$REPO_ROOT/Tools/icon.html"
OUTPUT_DIR="$REPO_ROOT/WhistleCounter/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUTPUT_DIR"

# Max seconds to wait for the screenshot file to appear.
MAX_WAIT=15

render_variant() {
  local variant="$1"
  local output_file="$2"
  local transparent="$3"

  rm -f "$output_file"

  local url="file://${HTML_PATH}?variant=${variant}"
  local tmp_profile
  tmp_profile="$(mktemp -d)"

  local -a flags=(
    --headless=new
    --disable-gpu
    --no-sandbox
    --user-data-dir="$tmp_profile"
    --window-size=1024,1024
    --virtual-time-budget=1500
    --hide-scrollbars
    --screenshot="$output_file"
  )
  if [[ "$transparent" == "yes" ]]; then
    flags+=(--default-background-color=00000000)
  fi

  # Launch Chrome in background.
  "$CHROME" "${flags[@]}" "$url" >/dev/null 2>&1 &
  local chrome_pid=$!

  # Poll for the output file.
  local waited=0
  while [[ ! -s "$output_file" ]] && (( waited < MAX_WAIT )); do
    sleep 0.5
    waited=$((waited + 1))
  done

  # Kill Chrome and its children once we've got the file (or timed out).
  pkill -9 -P "$chrome_pid" 2>/dev/null || true
  kill -9 "$chrome_pid" 2>/dev/null || true
  wait "$chrome_pid" 2>/dev/null || true
  rm -rf "$tmp_profile"

  if [[ -s "$output_file" ]]; then
    echo "Wrote $output_file ($(wc -c < "$output_file") bytes)"
  else
    echo "FAILED to produce $output_file" >&2
    return 1
  fi
}

render_variant "any"    "$OUTPUT_DIR/AppIcon.png"         "no"
render_variant "dark"   "$OUTPUT_DIR/AppIcon-Dark.png"    "yes"
render_variant "tinted" "$OUTPUT_DIR/AppIcon-Tinted.png"  "yes"

echo "Done."
