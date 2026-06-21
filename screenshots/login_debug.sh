#!/bin/bash
# Login driver with full debug screenshots between steps
set -e
DEV="emulator-5554"

adb -s $DEV shell am force-stop au.com.jobdun.app
adb -s $DEV shell pm clear au.com.jobdun.app > /dev/null
sleep 2
adb -s $DEV shell pm grant au.com.jobdun.app android.permission.POST_NOTIFICATIONS > /dev/null
adb -s $DEV shell am start -n au.com.jobdun.app/.MainActivity > /dev/null
sleep 8

echo "=== STEP 1: FTUE ==="
adb -s $DEV shell input tap 961 195
sleep 4
adb -s $DEV exec-out screencap -p > /tmp/dbg_01_post_skip.png
echo "post-skip screenshot saved"

# Verify we're on login
adb -s $DEV shell uiautomator dump /sdcard/d.xml 2>&1 | tail -1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml 2>&1 | tail -1
echo "Login screen content-descs:"
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -5

echo "=== STEP 2: tap email field ==="
# Use exact bounds from the dump
EMAIL_BOUNDS=$(tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="Email"[^/]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1)
echo "Email label bounds: $EMAIL_BOUNDS"
# But we need the EditText, not the label
EDIT_BOUNDS=$(tr '>' '\n' < /tmp/d.xml | grep -oE 'class="android.widget.EditText"[^/]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1)
echo "First EditText bounds: $EDIT_BOUNDS"
COORDS=$(echo "$EDIT_BOUNDS" | grep -oE '[0-9]+' | head -4)
X1=$(echo "$COORDS" | sed -n 1p)
Y1=$(echo "$COORDS" | sed -n 2p)
X2=$(echo "$COORDS" | sed -n 3p)
Y2=$(echo "$COORDS" | sed -n 4p)
EX=$(( (X1+X2)/2 ))
EY=$(( (Y1+Y2)/2 ))
echo "Tapping email EditText at ($EX, $EY)"
adb -s $DEV shell input tap $EX $EY
sleep 2

echo "=== STEP 3: type email ==="
adb -s $DEV shell "input text 'jam@jobdun.com.au'"
sleep 2
adb -s $DEV exec-out screencap -p > /tmp/dbg_02_email_typed.png
echo "post-email screenshot saved"

# Verify email is in the field
adb -s $DEV shell uiautomator dump /sdcard/d.xml 2>&1 | tail -1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml 2>&1 | tail -1
echo "Text in fields now:"
tr '>' '\n' < /tmp/d.xml | grep -oE 'text="[^"]+"' | head -5

echo "=== STEP 4: tap password field ==="
# Password is the 2nd EditText. With keyboard up, the layout shifts.
# Use the dump bounds
EDIT2_BOUNDS=$(tr '>' '\n' < /tmp/d.xml | grep -oE 'class="android.widget.EditText"[^/]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | sed -n 2p)
echo "Second EditText bounds: $EDIT2_BOUNDS"
COORDS=$(echo "$EDIT2_BOUNDS" | grep -oE '[0-9]+' | head -4)
X1=$(echo "$COORDS" | sed -n 1p)
Y1=$(echo "$COORDS" | sed -n 2p)
X2=$(echo "$COORDS" | sed -n 3p)
Y2=$(echo "$COORDS" | sed -n 4p)
PX=$(( (X1+X2)/2 ))
PY=$(( (Y1+Y2)/2 ))
echo "Tapping password EditText at ($PX, $PY)"
adb -s $DEV shell input tap $PX $PY
sleep 2

echo "=== STEP 5: type password ==="
adb -s $DEV shell "input text '123Jobdun_'"
sleep 2
adb -s $DEV exec-out screencap -p > /tmp/dbg_03_pw_typed.png
echo "post-pw screenshot saved"

# Check what got typed
adb -s $DEV shell uiautomator dump /sdcard/d.xml 2>&1 | tail -1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml 2>&1 | tail -1
echo "Text fields now:"
tr '>' '\n' < /tmp/d.xml | grep -oE 'text="[^"]+"' | head -5

echo "=== STEP 6: tap LOG IN ==="
LOGIN_BOUNDS=$(tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="LOG IN"[^/]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1)
echo "LOG IN: $LOGIN_BOUNDS"
COORDS=$(echo "$LOGIN_BOUNDS" | grep -oE '[0-9]+' | head -4)
X1=$(echo "$COORDS" | sed -n 1p)
Y1=$(echo "$COORDS" | sed -n 2p)
X2=$(echo "$COORDS" | sed -n 3p)
Y2=$(echo "$COORDS" | sed -n 4p)
LX=$(( (X1+X2)/2 ))
LY=$(( (Y1+Y2)/2 ))
echo "Tapping LOG IN at ($LX, $LY)"
adb -s $DEV shell input tap $LX $LY
sleep 12
adb -s $DEV exec-out screencap -p > /tmp/dbg_04_post_login.png
echo "post-login screenshot saved"

echo "=== STEP 7: check result ==="
adb -s $DEV logcat -d 2>&1 | grep -iE "authapi" | tail -3
echo "---"
adb -s $DEV shell uiautomator dump /sdcard/d.xml 2>&1 | tail -1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml 2>&1 | tail -1
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -8
