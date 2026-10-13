#!/bin/bash
# Build Dangerous for Windows (run from WSL; `make windows`):
#   build/win/BuildDangerous.exe          one file: the launcher, with Caprice32 (the
#                                         emulator), its ROMs and the game's disk inside
#   build/win/BuildDangerous-win64.zip    that exe, the manuals, how to play, the licences
# The launcher (tools/windows/Launcher.cs) is compiled by the .NET Framework's csc.exe on the
# Windows side; Caprice32's Windows release is downloaded once into build/win/.
set -e
cd "$(dirname "$0")/.."
B=build/win
CAP_URL=https://github.com/ColinPitrat/caprice32/releases/download/latest/cap32-win64.zip
CSC=/mnt/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe

mkdir -p $B
[ -f $B/cap32-win64.zip ] || curl -sfL -o $B/cap32-win64.zip $CAP_URL

# The payload: Caprice32 as released, set up for the game, and the disk
rm -rf $B/payload $B/payload.zip
mkdir -p $B/payload
unzip -q $B/cap32-win64.zip -d $B/payload
mv $B/payload/cap32-win64/* $B/payload/
rmdir $B/payload/cap32-win64
rm -rf $B/payload/resources/freedesktop $B/payload/resources/Info.plist
cp build/bd.dsk $B/payload/bd.dsk
mkdir -p $B/payload/screenshots $B/payload/snap     # where F3 / Shift+F3 save
cp tools/windows/README.txt $B/payload/BuildDangerous.txt
python3 - $B/payload/cap32.cfg <<'EOF'
import re, sys
p = sys.argv[1]
cfg = open(p, encoding='latin-1').read()
for key, value in {
    'model': 2,                 # CPC6128: disk drive, RUN"BD
    'scr_scale': 3,             # 1152x810 window
    'scr_fps': 0,               # no FPS counter over the game
    'scr_led': 0,
    'auto_pause': 1,            # pause while the window is in the background
}.items():
    cfg, n = re.subn(rf'^{key}=.*$', f'{key}={value}', cfg, flags=re.M)
    assert n == 1, key
open(p, 'w', encoding='latin-1').write(cfg)
EOF
(cd $B/payload && zip -qr ../payload.zip .)

# The icon: Thanos, from the game's own sprite
python3 - $B/icon.ico <<'EOF'
import sys
from PIL import Image
sheet = Image.open('assets/gfx/thanos.png').convert('RGBA')
frame = sheet.crop((0, 0, 16, 16))
frame.resize((256, 256), Image.NEAREST).save(sys.argv[1], sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
EOF

# Compile on the Windows side (csc wants Windows paths, and local ones are safest)
WTMP=$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")/bd-launcher
rm -rf "$WTMP"
mkdir -p "$WTMP"
cp tools/windows/Launcher.cs $B/payload.zip $B/icon.ico "$WTMP/"
(cd "$WTMP" && "$CSC" /nologo /optimize /target:winexe /out:BuildDangerous.exe \
    /win32icon:icon.ico /resource:payload.zip,payload.zip \
    /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll \
    /r:System.Windows.Forms.dll Launcher.cs | tr -d '\r')
cp "$WTMP/BuildDangerous.exe" $B/BuildDangerous.exe
rm -rf "$WTMP"

# The release zip
rm -rf $B/release $B/BuildDangerous-win64.zip
mkdir -p $B/release/BuildDangerous/licences
cp $B/BuildDangerous.exe tools/windows/README.txt manual.pdf manual_gr.pdf $B/release/BuildDangerous/
cp $B/payload/COPYING.txt $B/release/BuildDangerous/licences/Caprice32-GPL.txt
cp $B/payload/licenses/* $B/release/BuildDangerous/licences/
(cd $B/release && zip -qr ../BuildDangerous-win64.zip BuildDangerous)
ls -l $B/BuildDangerous.exe $B/BuildDangerous-win64.zip
