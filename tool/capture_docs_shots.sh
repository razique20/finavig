#!/bin/bash
# Capture live simulator screenshots of the new/updated screens and drop them
# into docs/screenshots/, at the gallery's uniform 1080x2400.
#
# Runs integration_test/docs_screenshots_test.dart on a booted simulator,
# syncs on its `==SCREEN: NN_name==` markers, shoots mid-dwell, then resamples
# every frame with tool/finalize_docs_shots.py.
#
# Override the device with DOCS_SHOT_UDID=<udid>.
set -u
cd "$(dirname "$0")/.."

LOG=build/docs-shots/test.log
RAW=build/docs-shots/raw
mkdir -p "$RAW"
rm -f "$LOG" "$RAW"/*.png

UDID="${DOCS_SHOT_UDID:-816B282C-6BB0-45A2-BE69-A6D8EA25F6B3}"

if ! xcrun simctl list devices booted | grep -q "$UDID"; then
  echo "No booted simulator $UDID — boot one or set DOCS_SHOT_UDID." >&2
  exit 1
fi

# Launch the tour detached; kill it when this script exits (success or fail).
flutter test integration_test/docs_screenshots_test.dart \
  -d "$UDID" --timeout 600s >"$LOG" 2>&1 &
TEST_PID=$!
trap 'kill $TEST_PID 2>/dev/null' EXIT

# Marker order must match the tour in integration_test/docs_screenshots_test.dart.
ORDER=(
  02-welcome
  04-login
  05-signup-form
  07-money
  34-money-credit
  13-records
  32-credits
  35-credit-settle
  33-app-lock
)

SEEN=0
for i in $(seq 1 600); do
  sleep 1
  if ! kill -0 $TEST_PID 2>/dev/null; then
    echo "test process exited at loop $i"
    break
  fi
  while [ $SEEN -lt ${#ORDER[@]} ]; do
    NAME=${ORDER[$SEEN]}
    if grep -q "==SCREEN: $NAME==" "$LOG"; then
      sleep 2.5
      xcrun simctl io "$UDID" screenshot "$RAW/$NAME.png" >/dev/null 2>&1
      echo "captured $NAME"
      SEEN=$((SEEN+1))
    else
      break
    fi
  done
  if [ $SEEN -eq ${#ORDER[@]} ]; then
    sleep 8
    break
  fi
done

wait $TEST_PID 2>/dev/null

echo "--- test result ---"
grep -E "All tests passed|Some tests failed|==TOUR DONE==|Exception|Test failed" "$LOG" | tail -5

echo "--- finalize ---"
python3 tool/finalize_docs_shots.py "$RAW"
