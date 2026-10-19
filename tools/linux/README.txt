BUILD DANGEROUS - for Linux (x86-64)
REVIVE8BIT - 2026 - VASPER

An Amstrad CPC game, with the emulator that runs it included.

TO PLAY
  Run BuildDangerous.run - double-click it (if your file manager asks, choose "Run"),
  or from a terminal:

      ./BuildDangerous.run

  Nothing is installed: the first time, it unpacks the emulator and the game to
  ~/.local/share/BuildDangerous (about 15 MB), then starts. The REVIVE8BIT screen comes
  first (10 seconds, or press SPACE), then the game loads.

  If it won't start, make it executable first:  chmod +x BuildDangerous.run

  Needs a 64-bit PC with a recent distribution: Ubuntu 24.04, Debian 13, Fedora 39,
  Linux Mint 22 or later (glibc 2.38), with X11 or Wayland and sound through PulseAudio,
  PipeWire or ALSA.

KEYS
  Cursor keys or Q A O P   walk, climb stairs; Up jumps, Down ducks
  SPACE                    set off a trap / answer the phone / start / continue
  M                        sign off the room
  ESC                      pause
  L                        English / Greek (on the title screen)
  A joystick works too (Fire 1 = SPACE, Fire 2 = M, both together = pause).

  F1 opens the emulator's menu, F2 switches to full screen, F10 quits.

The manual: manual.pdf (English), manual_gr.pdf (Greek).

THE EMULATOR
  Caprice32, https://github.com/ColinPitrat/caprice32 - free software under the GNU GPL,
  version 2 (licences/Caprice32-GPL.txt); its source code is at that address. It comes
  with SDL2 (zlib licence), FreeType (FreeType licence), libpng, libsamplerate, libdecor,
  Brotli and bzip2, and the Amstrad CPC system ROMs, which Amstrad allows to be
  distributed with emulators.
