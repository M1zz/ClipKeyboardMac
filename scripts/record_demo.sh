#!/bin/bash
# 맥 앱 시연 영상 녹화 - 데모 데이터로 뜬 Debug 빌드를 실제로 조작하며 화면을 찍는다.
#
#   1) 설치본을 끄고 Debug 빌드를 시연 모드로 띄운다 (실데이터 · iCloud 를 건드리지 않는다 - MacShotMode):
#        python3 -c "import sys,subprocess;sys.path.insert(0,'scripts');import shoot_mac as s;subprocess.Popen(['<Debug 빌드>.app/Contents/MacOS/ClipKeyboard.tap','-AppleLanguages','(ko)']+s.demo_args('ko')+['-ClipShotScreen','live'])"
#   2) sh scripts/record_demo.sh <출력.mov>      # 옆에 <출력>.marks (장면 시각) 가 생긴다
#   3) 창이 자리를 잡는 구간(*_click ~ *_placed)을 잘라 mp4 로 만든다:
#        ffmpeg -i out.mov -filter_complex "[0:v]fps=30,select='between(t,0.8,A)+between(t,B,C)+between(t,D,E)',setpts=N/30/TB,scale=1920:1080,format=yuv420p[v]" -map "[v]" -r 30 -c:v libx264 -crf 18 demo.mp4
#
# 좌표는 1600x900pt 화면, 메뉴바 자동 숨김 기준이다. 화면이 다르면 좌표부터 다시 잰다.
# 터미널에 화면 기록 · 손쉬운 사용 권한이 있어야 하고, cliclick 이 필요하다.
OUT="$1"
ks(){ osascript -e "tell application \"System Events\" to $1"; }
front(){ osascript -e 'tell application "TextEdit" to activate'; }
paste(){ front; sleep 0.4; ks 'key code 9 using command down'; sleep 0.9; ks 'key code 36'; ks 'key code 36'; }
# 메뉴바 아이콘 자리는 녹화 표시가 끼어들면 밀린다. 누를 때마다 다시 읽는다.
icon_x(){ osascript -e 'tell application "System Events" to tell process "ClipKeyboard.tap" to get item 1 of (get position of menu bar item 1 of menu bar 2)'; }
DX=0
popover(){ local x=$(( $(icon_x) + 17 )); DX=$(( x - 1145 )); cliclick -e 500 m:$x,140; cliclick -e 250 m:$x,1; sleep 1.0; cliclick m:$x,12 w:350 c:$x,12; sleep 1.1; }
MARKS="${OUT%.mov}.marks"; : > "$MARKS"
mark(){ python3 -c "import time,sys;print(sys.argv[1],time.time())" "$1" >> "$MARKS"; }
# 창은 늘 화면 맨 위에 붙어 열린다. 열리자마자 자리를 잡고, 그 사이는 편집에서 잘라 낸다.
place(){ mark "$1_click"; osascript -e "tell application \"System Events\" to tell process \"ClipKeyboard.tap\"" -e "repeat 40 times" -e "if exists window \"$2\" then exit repeat" -e "delay 0.05" -e "end repeat" -e "set position of window \"$2\" to {$3, $4}" -e "set size of window \"$2\" to {$5, $6}" -e "end tell"; sleep 0.3; mark "$1_placed"; }
px(){ echo $(( $1 + DX )); }

# 무대
osascript <<'OSA'
tell application "System Events" to tell process "ClipKeyboard.tap"
  repeat with w in (every window)
    try
      click button 1 of w
    end try
  end repeat
end tell
tell application "TextEdit"
  close every document saving no
  activate
  make new document with properties {text:"받는 사람: "}
  set size of every paragraph of front document to 26
  set bounds of front window to {0, 0, 1600, 900}
end tell
delay 0.8
tell application "System Events" to key code 125 using command down
OSA
cliclick m:700,560
sleep 0.5
mark t0
screencapture -x -C -k -v -V 80 "$OUT" &
sleep 2.5
mark hotkey

# 1. 빠른 붙여넣기 패널 (⌃⇧V)
ks 'key code 9 using {control down, shift down}'
sleep 1.4
cliclick -e 600 m:800,306; sleep 0.7; cliclick c:800,306
sleep 1.9
paste; sleep 0.8

# 2. 메뉴바에서 검색
popover
osascript -e 'tell application "System Events"' -e 'repeat with c in {"m","e","e","t"}' -e 'keystroke c' -e 'delay 0.18' -e 'end repeat' -e 'end tell'
sleep 0.9
cliclick -e 450 m:$(px 1100),140; sleep 0.5; cliclick c:$(px 1100),140
sleep 1.9
cliclick -e 400 m:760,520
paste; sleep 0.8

# 3. 단축어 목록, 카테고리
popover
cliclick -e 400 m:$(px 1042),519; sleep 0.4; cliclick c:$(px 1042),519
place list "단축어 목록" 560 170 480 560
sleep 1.3
cliclick -e 500 m:953,226; sleep 0.4; cliclick c:953,226
sleep 0.9
cliclick -e 350 m:947,298; sleep 0.5; cliclick c:947,298
sleep 2.0
cliclick -e 400 m:576,186; sleep 0.3; cliclick c:576,186
sleep 0.8

# 4. 클립보드 기록
popover
cliclick -e 400 m:$(px 1007),519; sleep 0.4; cliclick c:$(px 1007),519
place clip "클립보드 히스토리" 500 160 600 580
sleep 1.3
cliclick -e 500 m:800,435; sleep 0.8
cliclick -e 400 m:1044,435; sleep 0.4; cliclick c:1044,435
sleep 1.4
cliclick -e 400 m:516,176; sleep 0.3; cliclick c:516,176
sleep 0.6
paste
cliclick -e 400 m:900,640
sleep 2.0
mark end
echo "END $SECONDS"
wait
