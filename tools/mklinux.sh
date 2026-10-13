#!/bin/bash
# Build Dangerous for Linux (`make linux`):
#   build/linux/BuildDangerous.run            one file: tools/linux/launch.sh with Caprice32
#                                             (the emulator), its libraries, the CPC ROMs and
#                                             the game's disk appended as a tar.xz
#   build/linux/BuildDangerous-linux-x86_64.tar.gz   that, the manuals, how to play, licences
#
# Caprice32 has no Linux release download, so its binary, ROMs and resources come from the
# caprice32 snap (snap install caprice32), built on core24: it needs glibc 2.38+ and
# libstdc++ from GCC 13+ (Ubuntu 24.04, Debian 13, Fedora 39, Mint 22 and later). SDL2 and
# the less common libraries it uses travel with it; glibc, libstdc++ and the desktop's own
# libraries (X11/Wayland, ALSA/PulseAudio) are the user's.
set -e
cd "$(dirname "$0")/.."
B=build/linux
SNAP_DIR=/snap/caprice32/current
CORE=/snap/core24/current
[ -x $SNAP_DIR/usr/bin/cap32 ] || { echo "needs the caprice32 snap: snap install caprice32" >&2; exit 1; }

rm -rf $B/payload
mkdir -p $B/payload/lib $B/payload/screenshots $B/payload/snap
P=$B/payload
cp $SNAP_DIR/usr/bin/cap32 $P/
cp -r $SNAP_DIR/usr/bin/rom $P/rom
cp -r $SNAP_DIR/usr/bin/resources $P/resources
rm -rf $P/resources/freedesktop $P/resources/Info.plist
for lib in libSDL2-2.0.so.0 libdecor-0.so.0 libfreetype.so.6 libsamplerate.so.0; do
    cp -L $SNAP_DIR/usr/lib/x86_64-linux-gnu/$lib $P/lib/
done
for lib in libpng16.so.16 libbrotlidec.so.1 libbrotlicommon.so.1 libbz2.so.1.0; do
    cp -L $CORE/usr/lib/x86_64-linux-gnu/$lib $P/lib/
done
cp build/bd.dsk $P/bd.dsk
cp tools/linux/README.txt $P/BuildDangerous.txt
[ -f build/win/cap32-win64.zip ] || { mkdir -p build/win; curl -sfL -o build/win/cap32-win64.zip \
    https://github.com/ColinPitrat/caprice32/releases/download/latest/cap32-win64.zip; }
unzip -qjo build/win/cap32-win64.zip cap32-win64/COPYING.txt -d $P
python3 - $SNAP_DIR/etc/cap32.cfg $P/cap32.cfg.in <<'EOF'
import re, sys
cfg = open(sys.argv[1], encoding='latin-1').read()
for key, value in {
    'model': 2,                 # CPC6128: disk drive, RUN"BD
    'scr_scale': 3,             # 1152x810 window
    'scr_fps': 0,               # no FPS counter over the game
    'scr_led': 0,
    'auto_pause': 1,            # pause while the window is in the background
    'resources_path': '@DIR@/resources',
    'rom_path': '@DIR@/rom',
    'sdump_dir': '@DIR@/screenshots',
    'snap_path': '@DIR@/snap',
    'dsk_path': '@DIR@',
    'tape_path': '@DIR@',
    'cart_path': '@DIR@',
    'printer_file': '@DIR@/printer.dat',
}.items():
    cfg, n = re.subn(rf'^{key}=.*$', f'{key}={value}', cfg, flags=re.M)
    assert n == 1, key
open(sys.argv[2], 'w', encoding='latin-1').write(cfg)
EOF

# The self-extracting file: the launcher, then the payload from the line after it
rm -f $B/payload.tar.xz
tar -C $P -cf - . | xz -9 > $B/payload.tar.xz
HASH=$(sha1sum $B/payload.tar.xz | cut -c1-12)
SKIP=$(( $(wc -l < tools/linux/launch.sh) + 1 ))
sed -e "s/@HASH@/$HASH/" -e "s/@SKIP@/$SKIP/" tools/linux/launch.sh > $B/BuildDangerous.run
cat $B/payload.tar.xz >> $B/BuildDangerous.run
chmod +x $B/BuildDangerous.run

# The release
rm -rf $B/release $B/BuildDangerous-linux-x86_64.tar.gz
mkdir -p $B/release/BuildDangerous/licences
cp $B/BuildDangerous.run tools/linux/README.txt manual.pdf manual_gr.pdf $B/release/BuildDangerous/
cp $P/COPYING.txt $B/release/BuildDangerous/licences/Caprice32-GPL.txt
for d in libsdl2-2.0-0:SDL2 libfreetype6:FreeType libsamplerate0:libsamplerate libdecor-0-0:libdecor; do
    cp $SNAP_DIR/usr/share/doc/${d%%:*}/copyright $B/release/BuildDangerous/licences/${d#*:}.txt
done
for d in libpng16-16t64:libpng libbrotli1:Brotli libbz2-1.0:bzip2; do
    cp $CORE/usr/share/doc/${d%%:*}/copyright $B/release/BuildDangerous/licences/${d#*:}.txt
done
tar -C $B/release -czf $B/BuildDangerous-linux-x86_64.tar.gz BuildDangerous
ls -l $B/BuildDangerous.run $B/BuildDangerous-linux-x86_64.tar.gz
