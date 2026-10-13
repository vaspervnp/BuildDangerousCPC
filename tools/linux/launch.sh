#!/bin/sh
# Build Dangerous for Linux: this script with the game and an Amstrad CPC emulator
# (Caprice32, GPL) appended as a tar.xz. The first run unpacks it to
# ${XDG_DATA_HOME:-~/.local/share}/BuildDangerous/<hash> - nothing is installed, and a new
# version unpacks beside the old one - then starts Caprice32 as a CPC 6128 with the disk
# in drive A, typing RUN"BD. Arguments go through to Caprice32 (-a "..." types something
# else instead of RUN"BD). Built by tools/mklinux.sh.
set -e
HASH=@HASH@
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/BuildDangerous/$HASH"
if [ ! -f "$DIR/.unpacked" ]; then
    rm -rf "$DIR"
    mkdir -p "$DIR"
    echo "Build Dangerous: unpacking to $DIR"
    tail -n +@SKIP@ "$0" | xz -dc | tar -x -C "$DIR"
    # the config, with this folder's paths in it
    sed "s|@DIR@|$DIR|g" "$DIR/cap32.cfg.in" > "$DIR/cap32.cfg"
    touch "$DIR/.unpacked"
fi
TYPE=yes
for a in "$@"; do [ "$a" = "-a" ] && TYPE=; done
cd "$DIR"
export LD_LIBRARY_PATH="$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [ -n "$TYPE" ]; then
    exec "$DIR/cap32" --cfg_file="$DIR/cap32.cfg" -a 'run"bd' "$@" "$DIR/bd.dsk"
fi
exec "$DIR/cap32" --cfg_file="$DIR/cap32.cfg" "$@" "$DIR/bd.dsk"
# --- the payload follows; nothing below this line is shell ---
