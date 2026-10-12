RASM ?= rasm
IDSK ?= iDSK
PY   ?= python3
B    := build

BUILDINGS := sunnyvale test gallery mall hotel hospital hardknock skyscraper
CAMPAIGN  := sunnyvale mall hotel hospital hardknock skyscraper
ROUTES    := $(CAMPAIGN:%=tests/route_%.txt)
ASSETS := $(B)/tiles.bin $(B)/font.bin $(B)/thanos.bin $(B)/vignettes.bin \
          $(B)/hazards.bin $(B)/people.bin $(B)/tasha.bin $(B)/strings.asm $(B)/room_outdoor.asm $(B)/title.asm \
          $(BUILDINGS:%=$(B)/bld_%.asm)
SRC    := $(wildcard src/*.asm)

all: $(B)/bd.dsk $(B)/bd.cdt

$(B):
	mkdir -p $@

$(B)/tiles.bin: assets/gfx/tiles.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py tiles $< $@

$(B)/font.bin: assets/gfx/font.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py tiles $< $@

$(B)/thanos.bin: assets/gfx/thanos.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py sprites $< $@ --mirror

$(B)/vignettes.bin: assets/gfx/vignettes.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py sprites $< $@

$(B)/hazards.bin: assets/gfx/hazards.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py sprites8 $< $@

$(B)/people.bin: assets/gfx/people.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py sprites $< $@

$(B)/tasha.bin: assets/gfx/tasha.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py portrait $< $@ 12 22 8 8    # the mouth: MOUTH_* in src/phone.asm

$(B)/title.asm: assets/title.txt tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py tilemap $< $@ title_logo

$(B)/room_outdoor.asm: assets/rooms/outdoor.txt tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py room $< $@ room_outdoor

$(B)/strings.asm: assets/text/strings.txt assets/gfx/font.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py text $< $@ assets/gfx/font.png

$(B)/bld_%.asm: assets/buildings/%.txt $(wildcard assets/rooms/*.txt) tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py building $< $@ bld_$*

$(B)/bd.bin: $(SRC) $(ASSETS)
	$(RASM) src/main.asm -I. -ob $@ -os $(B)/bd.sym -s -sl

# The loading screen: the picture -> Mode 0 screen + the BASIC loader (BD.BAS). It is
# 1024x572: 28 px off each side (clear of BUILD and the crane), then stretched ~6% to 16:10.
# On the disk REVIVE8BIT's screen comes first (assets/revive8b.scr, inks from its note):
# 10 seconds or Space.
$(B)/screen.bin $(B)/bd.bas $(B)/inks.bin: assets/gfx/loadscreen_cartoon.jpg assets/revive8b.txt tools/loadscreen.py | $(B)
	$(PY) tools/loadscreen.py $< $(B)/screen.bin $(B)/bd.bas --crop 28,0,996,572 --inks-out $(B)/inks.bin \
	    --splash assets/revive8b.txt

# The disk: RUN"BD finds BD.BAS (loader: REVIVE8B.SCR for 10 s, then inks, SCREEN.BIN to
# #C000, RUN"GAME").
$(B)/bd.dsk: $(B)/bd.bin $(B)/screen.bin $(B)/bd.bas assets/revive8b.scr
	rm -f $@
	cp $(B)/bd.bin $(B)/game.bin
	cp assets/revive8b.scr $(B)/revive8b.scr
	$(IDSK) $@ -n
	$(IDSK) $@ -i $(B)/bd.bas -t 0
	$(IDSK) $@ -i $(B)/revive8b.scr -t 1 -c c000
	$(IDSK) $@ -i $(B)/screen.bin -t 1 -c c000
	$(IDSK) $@ -i $(B)/game.bin -t 1 -c 0b00 -e 0b00

# Planned clean runs through each campaign building (tools/route.py), run by `make test`.
tests/route_%.txt: assets/buildings/%.txt $(wildcard assets/rooms/*.txt) tools/route.py tools/cpcgfx.py
	$(PY) tools/route.py $< $@

# The tape, for the CPC 464: RUN"" loads the loader (src/tape_loader.asm), which sets the
# picture's inks and loads SCREEN to #C000 and GAME to #0B00. 2000 baud (SPEED WRITE 1).
$(B)/tapeldr.bin: src/tape_loader.asm $(B)/inks.bin
	$(RASM) src/tape_loader.asm -I. -ob $@

$(B)/bd.cdt: $(B)/tapeldr.bin $(B)/screen.bin $(B)/bd.bin tools/mkcdt.py
	$(PY) tools/mkcdt.py $@ "BUILD DANGEROUS:$(B)/tapeldr.bin:0x0A00" \
	    SCREEN:$(B)/screen.bin:0xC000 GAME:$(B)/bd.bin:0x0B00

# Headless runs of every tests/*.txt script; screenshots go to build/shots/.
test: $(B)/bd.bin $(ROUTES)
	@set -e; for t in tests/*.txt; do \
	  echo "== $$t"; \
	  $(PY) tools/cpcrun.py $(B)/bd.bin --sym $(B)/bd.sym --script $$t --out $(B)/shots; \
	done

# The manuals, English and Greek, as PDFs (needs: pip install markdown fpdf2).
manual: manual.pdf manual_gr.pdf

manual%.pdf: manual%.md tools/mkmanual.py $(wildcard docs/img/*.png)
	$(PY) tools/mkmanual.py $< $@

clean:
	rm -rf $(B)

.PHONY: all test clean manual
