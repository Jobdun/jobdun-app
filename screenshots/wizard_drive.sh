#!/bin/bash
# Drive the wizard: fill step 1, advance to step 2, etc.
DEV="emulator-5554"

get_center() {
  local desc="$1"
  adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
  adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
  python3 -c "
import re
with open('/tmp/d.xml') as f:
    data = f.read()
m = re.search(r'content-desc=\"[^\"]*${desc}[^\"]*\"[^/]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', data)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print(f'{(x1+x2)//2} {(y1+y2)//2}')
"
}

echo "=== Step 1: Type title and pick trade ==="
# Find the JOB TITLE EditText (the first EditText on screen)
adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
python3 -c "
import re
with open('/tmp/d.xml') as f:
    data = f.read()
m = re.search(r'class=\"android.widget.EditText\"[^/]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', data)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print(f'TITLE at: {(x1+x2)//2} {(y1+y2)//2}')
" > /tmp/coords.txt
COORDS=$(cat /tmp/coords.txt | awk '{print $3, $4}')
echo "Tap title field at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 2
adb -s $DEV shell "input text 'Install%s3-phase%sswitchboard%sat%scommercial%ssite'"
sleep 2
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/20_wizard_step1_filled.png

# Pick Electrician
COORDS=$(get_center "Electrician")
echo "Electrician at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 1
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/21_wizard_step1_electrician.png

# Tap CONTINUE
COORDS=$(get_center "CONTINUE")
echo "CONTINUE at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 4
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/22_wizard_step2_location.png

echo "=== Step 2: location ==="
adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
echo "Step 2 content-descs:"
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -8

# Tap location field
python3 -c "
import re
with open('/tmp/d.xml') as f:
    data = f.read()
m = re.search(r'class=\"android.widget.EditText\"[^/]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', data)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print(f'{(x1+x2)//2} {(y1+y2)//2}')
" > /tmp/coords.txt
COORDS=$(cat /tmp/coords.txt)
adb -s $DEV shell input tap $COORDS
sleep 2
adb -s $DEV shell "input text 'Parramatta%sNSW'"
sleep 2
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/23_wizard_step2_typed.png

# Tap CONTINUE
COORDS=$(get_center "CONTINUE")
echo "CONTINUE at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 4
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/24_wizard_step3_details.png

echo "=== Step 3: description ==="
adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -10

# Tap description
python3 -c "
import re
with open('/tmp/d.xml') as f:
    data = f.read()
m = re.search(r'class=\"android.widget.EditText\"[^/]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', data)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print(f'{(x1+x2)//2} {(y1+y2)//2}')
" > /tmp/coords.txt
COORDS=$(cat /tmp/coords.txt)
adb -s $DEV shell input tap $COORDS
sleep 2
adb -s $DEV shell "input text 'Need%sa%slicensed%ssparky%sto%supgrade%sour%s3-phase%sswitchboard%sfrom%s100A%sto%s200A.%sSite%saccess%svia%sGate%s3,%sswitchroom%sis%sin%sthe%sbasement.%sPower%scan%sbe%scut%sfor%s4%shours%son%sSunday.'"
sleep 2
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/25_wizard_step3_typed.png

# Tap CONTINUE
COORDS=$(get_center "CONTINUE")
echo "CONTINUE at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 4
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/26_wizard_step4_pricing.png

echo "=== Step 4: pricing ==="
adb -s $DEV shell uiautomator dump /sdcard/d.xml >/dev/null 2>&1
adb -s $DEV pull /sdcard/d.xml /tmp/d.xml >/dev/null 2>&1
tr '>' '\n' < /tmp/d.xml | grep -oE 'content-desc="[^"]+"' | head -10

# Pick "Set price" then continue
COORDS=$(get_center "Set price")
if [ -n "$COORDS" ]; then
  adb -s $DEV shell input tap $COORDS
  sleep 1
fi
# Tap rate field
python3 -c "
import re
with open('/tmp/d.xml') as f:
    data = f.read()
m = re.search(r'class=\"android.widget.EditText\"[^/]*bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"', data)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print(f'{(x1+x2)//2} {(y1+y2)//2}')
" > /tmp/coords.txt
COORDS=$(cat /tmp/coords.txt)
adb -s $DEV shell input tap $COORDS
sleep 2
adb -s $DEV shell "input text '90'"
sleep 2
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/27_wizard_step4_filled.png

# CONTINUE
COORDS=$(get_center "CONTINUE")
echo "CONTINUE at: $COORDS"
adb -s $DEV shell input tap $COORDS
sleep 4
adb -s $DEV exec-out screencap -p > /home/jam/Projects/jobdun-app/screenshots/cleaned/28_wizard_step5_review.png
echo "Done with wizard"
