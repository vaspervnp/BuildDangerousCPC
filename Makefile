RASM ?= rasm
IDSK ?= iDSK
PY   ?= python3
B    := build

BUILDINGS := sunnyvale test gallery mall hotel hospital skyscraper
CAMPAIGN  := sunnyvale mall hotel hospital skyscraper
ROUTES    := $(CAMPAIGN:%=tests/route_%.txt)
ASSETS := $(B)/tiles.bin $(B)/font.bin $(B)/thanos.bin $(B)/vignettes.bin \
          $(B)/hazards.bin $(B)/people.bin $(B)/tasha.bin $(B)/strings.asm $(B)/room_outdoor.asm \
          $(BUILDINGS:%=$(B)/bld_%.asm)
SRC    := $(wildcard src/*.asm)

all: $(B)/bd.dsk

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

$(B)/room_outdoor.asm: assets/rooms/outdoor.txt tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py room $< $@ room_outdoor

$(B)/strings.asm: assets/text/strings.txt assets/gfx/font.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py text $< $@ assets/gfx/font.png

$(B)/bld_%.asm: assets/buildings/%.txt $(wildcard assets/rooms/*.txt) tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py building $< $@ bld_$*

$(B)/bd.bin: $(SRC) $(ASSETS)
	$(RASM) src/main.asm -I. -ob $@ -os $(B)/bd.sym -s -sl

$(B)/bd.dsk: $(B)/bd.bin
	rm -f $@
	$(IDSK) $@ -n
	$(IDSK) $@ -i $< -t 1 -c 1000 -e 1000

# Planned clean runs through each campaign building (tools/route.py), run by `make test`.
tests/route_%.txt: assets/buildings/%.txt $(wildcard assets/rooms/*.txt) tools/route.py tools/cpcgfx.py
	$(PY) tools/route.py $< $@

# Headless runs of every tests/*.txt script; screenshots go to build/shots/.
test: $(B)/bd.bin $(ROUTES)
	@set -e; for t in tests/*.txt; do \
	  echo "== $$t"; \
	  $(PY) tools/cpcrun.py $(B)/bd.bin --sym $(B)/bd.sym --script $$t --out $(B)/shots; \
	done

clean:
	rm -rf $(B)

.PHONY: all test clean
