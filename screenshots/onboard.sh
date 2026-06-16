#!/bin/bash
DEV="emulator-5554"

# Helper: get center of element matching a content-desc substring
get_center() {
  local desc="$1"
  adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
  adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
  python3 <<EOF
import re
with open('/tmp/d.xml') as f:
    data = f.read()
m = re.search(r'content-desc="[^"]*${desc}[^"]*"[^/]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', data)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print((x1 + x2) // 2, (y1 + y2) // 2)
EOF
}

# Capture current state
adb -s $DEV exec-out screencap -p > /tmp/onboard_start.png
echo "Onboarding start"

# Step 2: YOUR NAME field. Type a name
COORDS=$(get_center "YOUR NAME")
echo "YOUR NAME at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 2
adb -s $DEV shell "input text 'Test%sUser'"
sleep 2
adb -s $DEV exec-out screencap -p > /tmp/onboard_name.png
echo "Name typed"

# Tap CONTINUE
COORDS=$(get_center "CONTINUE")
echo "CONTINUE at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 4
adb -s $DEV exec-out screencap -p > /tmp/onboard_step3.png
echo "After CONTINUE - check state"
adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -8

# Try one more CONTINUE if there's a step 3
COORDS=$(get_center "CONTINUE")
if [ -n "$COORDS" ]; then
  echo "Tap CONTINUE again at: $COORDS"
  adb -s $DEV shell input tap $COORDS
  sleep 4
  adb -s $DEV exec-out screencap -p > /tmp/onboard_step4.png
fi
adb -s $DEV exec-out screencap -p > /tmp/onboard_final.png
echo "Onboarding done"