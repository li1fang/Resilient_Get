#!/bin/bash

set -euo pipefail

echo "[test] Starting rget tests"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TMPDIR="$SCRIPT_DIR/tmp_test"
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"

STATE_FILE="$HOME/.rget.state"
rm -f "$STATE_FILE"

echo "[test] Using state file: $STATE_FILE"

# Helper to compute SHA256
hash_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "" # no hasher; tests will skip hash checks
  fi
}

# Case 1: Dynamic failure → Fallback success
echo "FALLBACK_CONTENT" > "$TMPDIR/fallback.txt"
FALLBACK_URL="file://$TMPDIR/fallback.txt"
FALLBACK_HASH="$(hash_of "$TMPDIR/fallback.txt")"

echo "[test] Case1: dynamic fails, fallback succeeds"
bash ./rget.sh \
  --name "wasm-shim" \
  --dynamic-cmd "echo https://invalid.example.tld/nonexistent.tar.gz" \
  --fallback-url "$FALLBACK_URL" \
  --hash "$FALLBACK_HASH" \
  "$TMPDIR/out1.txt"

[ -f "$TMPDIR/out1.txt" ] || { echo "[test] out1 missing"; exit 1; }
diff -q "$TMPDIR/out1.txt" "$TMPDIR/fallback.txt" >/dev/null || { echo "[test] out1 content mismatch"; exit 1; }
echo "[test] Case1 passed"

# Case 2: Dynamic success → State file creation
echo "DYNAMIC_CONTENT" > "$TMPDIR/dynamic.txt"
DYNAMIC_URL="file://$TMPDIR/dynamic.txt"
DYNAMIC_HASH="$(hash_of "$TMPDIR/dynamic.txt")"

echo "[test] Case2: dynamic succeeds and writes state"
bash ./rget.sh \
  --name "wasm-shim" \
  --dynamic-cmd "echo $DYNAMIC_URL" \
  --hash "$DYNAMIC_HASH" \
  "$TMPDIR/out2.txt"

grep -q -E "^wasm-shim=${DYNAMIC_URL}$" "$STATE_FILE" || { echo "[test] state missing or incorrect"; cat "$STATE_FILE"; exit 1; }
[ -f "$TMPDIR/out2.txt" ] || { echo "[test] out2 missing"; exit 1; }
diff -q "$TMPDIR/out2.txt" "$TMPDIR/dynamic.txt" >/dev/null || { echo "[test] out2 content mismatch"; exit 1; }
echo "[test] Case2 passed"

# Case 3: Next run → Success via State file (no dynamic/fallback provided)
echo "[test] Case3: replay from state"
bash ./rget.sh \
  --name "wasm-shim" \
  --hash "$DYNAMIC_HASH" \
  "$TMPDIR/out3.txt"

[ -f "$TMPDIR/out3.txt" ] || { echo "[test] out3 missing"; exit 1; }
diff -q "$TMPDIR/out3.txt" "$TMPDIR/dynamic.txt" >/dev/null || { echo "[test] out3 content mismatch"; exit 1; }
echo "[test] Case3 passed"

# Case 4: Override state file path via --state-file
CUSTOM_STATE="$TMPDIR/custom.state"
rm -f "$CUSTOM_STATE"
echo "CUSTOM_DYNAMIC" > "$TMPDIR/custom.txt"
CUSTOM_URL="file://$TMPDIR/custom.txt"
CUSTOM_HASH="$(hash_of "$TMPDIR/custom.txt")"

echo "[test] Case4: using --state-file"
bash ./rget.sh \
  --name "custom-item" \
  --state-file "$CUSTOM_STATE" \
  --dynamic-cmd "echo $CUSTOM_URL" \
  --hash "$CUSTOM_HASH" \
  "$TMPDIR/out4.txt"

grep -q -E "^custom-item=${CUSTOM_URL}$" "$CUSTOM_STATE" || { echo "[test] custom state missing or incorrect"; cat "$CUSTOM_STATE"; exit 1; }
[ -f "$TMPDIR/out4.txt" ] || { echo "[test] out4 missing"; exit 1; }
diff -q "$TMPDIR/out4.txt" "$TMPDIR/custom.txt" >/dev/null || { echo "[test] out4 content mismatch"; exit 1; }
echo "[test] Case4 passed"

echo "[test] All tests passed"