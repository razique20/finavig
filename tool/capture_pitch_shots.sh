#!/bin/bash
# Capture live simulator screenshots while the pitch tour integration test
# runs. Syncs on the test's ==SCREEN: NN_name== log markers, then captures
# mid-dwell.
set -u
cd "$(dirname "$0")/.."

LOG=build/pitch/test.log
SHOT_DIR=build/pitch/shots
mkdir -p "$SHOT_DIR"
rm -f "$LOG" "$SHOT_DIR"/*.png

UDID="816B282C-6BB0-45A2-BE69-A6D8EA25F6B3"

# Launch the tour detached; kill it when this script exits (success or fail).
flutter test integration_test/app_pitch_screenshots_test.dart \
  -d "$UDID" --timeout 300s >"$LOG" 2>&1 &
TEST_PID=$!
trap 'kill $TEST_PID 2>/dev/null' EXIT

ORDER=(01_home 02_documents 03_money 04_document_detail 05_expiry_list 06_global_search 07_budgets 08_envelopes 09_records 10_cash_flow 11_ai_summary 12_ai_budget_plan 13_profile 14_alerts)
SEEN=0
for i in $(seq 1 240); do
  sleep 1
  if ! kill -0 $TEST_PID 2>/dev/null; then
    echo "test process exited at loop $i"
    break
  fi
  while [ $SEEN -lt ${#ORDER[@]} ]; do
    NAME=${ORDER[$SEEN]}
    if grep -q "==SCREEN: $NAME==" "$LOG"; then
      sleep 2.5
      xcrun simctl io "$UDID" screenshot "$SHOT_DIR/$NAME.png" >/dev/null 2>&1
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
echo "---"
ls -la "$SHOT_DIR"
tail -3 "$LOG"
