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
        xor a
        ld (lang),a             ; English until L is pressed in the menu
        ld (keys),a
        ld hl,building_test
        call building_start
        call hud_init
        call player_init
        ei

main_loop:
        call wait_vbl
        call input_read
        call player_update
        call hud_update
        jr main_loop

        include "video.asm"
        include "input.asm"
        include "tiles.asm"
        include "room.asm"
        include "building.asm"
        include "hazards.asm"
        include "vignette.asm"
        include "player.asm"
        include "text.asm"
        include "hud.asm"
        include "build/strings.asm"

; ---------------------------------------------------------------- assets
tiles_gfx:      incbin "build/tiles.bin"
font_gfx:       incbin "build/font.bin"
thanos_gfx:     incbin "build/thanos.bin"
vignette_gfx:   incbin "build/vignettes.bin"
hazard_gfx:     incbin "build/hazards.bin"
room_test:      incbin "build/room_test.bin"

; ---------------------------------------------------------------- variables
        include "vars.asm"

code_end:
        assert code_end < #a600, "binary overlaps AMSDOS/firmware workspace at load time"
