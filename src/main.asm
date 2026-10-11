; Build Dangerous - Amstrad CPC (64K), Mode 1
; Loaded by AMSDOS at #1000 (RUN"BD), then takes over the machine: firmware and ROMs off.

        org #1000

start:
        di
        ld sp,#c000
        ld bc,#fa7e             ; disc drive motor off (we never return to AMSDOS)
        xor a
        out (c),a
        ld hl,#c9fb             ; RST #38 handler = EI : RET
        ld (#0038),hl
        im 1
        call video_init         ; also pages out the ROMs, so #0038 now reads our RAM
        ld hl,room_test
        call room_load
        call room_draw
        call player_init
        ei

main_loop:
        call wait_vbl
        call input_read
        call player_update
        jr main_loop

        include "video.asm"
        include "input.asm"
        include "tiles.asm"
        include "room.asm"
        include "player.asm"

; ---------------------------------------------------------------- assets
tiles_gfx:      incbin "build/tiles.bin"
thanos_gfx:     incbin "build/thanos.bin"
room_test:      incbin "build/room_test.bin"

; ---------------------------------------------------------------- variables
        include "vars.asm"

code_end:
        assert code_end < #a600, "binary overlaps AMSDOS/firmware workspace at load time"
