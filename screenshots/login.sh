#!/bin/bash
# Login driver — uses 123Jobdun_ (no special characters, no shell escaping)
set -e
DEV="emulator-5554"

adb -s $DEV shell am force-stop au.com.jobdun.app
adb -s $DEV shell pm clear au.com.jobdun.app > /dev/null
sleep 2
adb -s $DEV shell pm grant au.com.jobdun.app android.permission.POST_NOTIFICATIONS > /dev/null
adb -s $DEV shell am start -n au.com.jobdun.app/.MainActivity > /dev/null
sleep 8

# SKIP FTUE — bounds [886,149][1036,241] → center (961, 195)
adb -s $DEV shell input tap 961 195
sleep 4

# Email field — bounds [66,478][1014,680] → center (540, 580)
adb -s $DEV shell input tap 540 580
sleep 2
adb -s $DEV shell "input text 'jam@jobdun.com.au'"
sleep 2

# Password field — bounds [66,770][1014,972] → center (540, 871)
adb -s $DEV shell input tap 540 871
sleep 2
# Now type the password — no special chars, no escaping needed
adb -s $DEV shell "input text '123Jobdun_'"
sleep 2

# Tap somewhere outside the keyboard to dismiss it (logo area is empty)
adb -s $DEV shell input tap 540 300
sleep 2

# Find LOG IN button bounds
adb -s $DEV shell uiautomator dump /sdcard/d.xml 2>&1 | tail -1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml 2>&1 | tail -1
LOGIN_BOUNDS=$(tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="LOG IN"[^/]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1)
echo "LOG IN: $LOGIN_BOUNDS"
COORDS=$(echo "$LOGIN_BOUNDS" | grep -oE '[0-9]+' | head -4)
X1=$(echo "$COORDS" | sed -n 1p)
Y1=$(echo "$COORDS" | sed -n 2p)
X2=$(echo "$COORDS" | sed -n 3p)
Y2=$(echo "$COORDS" | sed -n 4p)
if [ -n "$X2" ] && [ "$X2" -gt 0 ]; then
  CX=$(( (X1+X2)/2 ))
  CY=$(( (Y1+Y2)/2 ))
  echo "Tapping LOG IN at ($CX, $CY)"
  adb -s $DEV shell input tap $CX $CY
  sleep 12
else
  echo "LOG IN button not visible"
  adb -s $DEV shell input tap 540 1170
  sleep 12
fi

adb -s $DEV exec-out screencap -p > /tmp/post_login.png
echo "---"
adb -s $DEV logcat -d 2>&1 | grep -iE "authapi" | tail -3
echo "---"
adb -s $DEV shell uiautomator dump /sdcard/d.xml 2>&1 | tail -1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml 2>&1 | tail -1
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -5
