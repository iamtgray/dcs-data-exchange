#!/usr/bin/env bash
# Render all .drawio files to .drawio.png using the draw.io desktop app CLI.
# Usage: ./scripts/render-drawio.sh [optional-path-to-single-file.drawio]

set -euo pipefail

# Find draw.io binary
DRAWIO=""
if [ -d "/Applications/draw.io.app" ]; then
  DRAWIO="/Applications/draw.io.app/Contents/MacOS/draw.io"
elif command -v drawio &>/dev/null; then
  DRAWIO="drawio"
elif command -v draw.io &>/dev/null; then
  DRAWIO="draw.io"
fi

if [ -z "$DRAWIO" ]; then
  echo "ERROR: draw.io not found. Install from https://github.com/jgraph/drawio-desktop/releases"
  exit 1
fi

echo "Using draw.io at: $DRAWIO"

SCALE="${DRAWIO_SCALE:-2}"
FAILED=0
COUNT=0

if [ $# -eq 1 ]; then
  # Render a single file
  FILES="$1"
else
  # Find all .drawio files under docs/
  FILES=$(find docs -name "*.drawio" -type f)
fi

for f in $FILES; do
  OUT="${f}.png"
  echo "  Rendering: $f -> $OUT"
  if "$DRAWIO" --export --format png --scale "$SCALE" --output "$OUT" "$f" 2>/dev/null; then
    COUNT=$((COUNT + 1))
  else
    echo "  FAILED: $f"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "Done. Rendered $COUNT diagram(s), $FAILED failure(s)."
