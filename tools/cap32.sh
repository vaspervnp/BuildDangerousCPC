#!/bin/bash
# Run the game in the Caprice32 snap, typing the keys in a script file.
#   tools/cap32.sh [autocmd-file] [model] [image]
# The file holds what to type (e.g. run"bd, then keys); \(CAP32_SCRNSHOT) saves a
# screenshot to ~/snap/caprice32/current/screenshots, \(CAP32_EXIT) quits,
# \(CAP32_TAPEPLAY) presses the tape's Play key, \(CAP32_SPEED) lifts the speed limit.
# Runs of a harmless key (x) work as delays. Model: 0 = 464, 2 = 6128 (default).
# Image: build/bd.dsk (default) or build/bd.cdt.
set -e
U=~/snap/caprice32/current
IMG=${3:-$(dirname "$0")/../build/bd.dsk}
NAME=bd.${IMG##*.}
cp "$IMG" "$U/disk/$NAME"
if [ -n "$1" ]; then cp "$1" "$U/bd_autocmd.txt"; else printf 'run"bd\n' > "$U/bd_autocmd.txt"; fi
cat > "$U/bd.sh" <<INNER
#!/bin/bash
exec \$SNAP/usr/bin/cap32 --cfg_file=\$SNAP_USER_DATA/etc/cap32.cfg -O system.model=\${1:-2} \\
    -a "\$(cat \$SNAP_USER_DATA/bd_autocmd.txt)" "\$SNAP_USER_DATA/disk/$NAME"
INNER
chmod +x "$U/bd.sh"
snap run --shell caprice32.launcher -c "\$SNAP_USER_DATA/bd.sh ${2:-2}"
