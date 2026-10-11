RASM ?= rasm
IDSK ?= iDSK
PY   ?= python3
B    := build

ASSETS := $(B)/tiles.bin $(B)/font.bin $(B)/thanos.bin $(B)/vignettes.bin \
          $(B)/hazards.bin $(B)/room_test.bin $(B)/room_gallery.bin $(B)/strings.asm
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

$(B)/strings.asm: assets/text/strings.txt assets/gfx/font.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py text $< $@ assets/gfx/font.png

$(B)/room_%.bin: assets/rooms/%.txt tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py room $< $@

$(B)/bd.bin: $(SRC) $(ASSETS)
	$(RASM) src/main.asm -I. -ob $@ -os $(B)/bd.sym -s -sl

$(B)/bd.dsk: $(B)/bd.bin
	rm -f $@
	$(IDSK) $@ -n
	$(IDSK) $@ -i $< -t 1 -c 1000 -e 1000

# Headless runs of every tests/*.txt script; screenshots go to build/shots/.
test: $(B)/bd.bin
	@set -e; for t in tests/*.txt; do \
	  echo "== $$t"; \
	  $(PY) tools/cpcrun.py $(B)/bd.bin --sym $(B)/bd.sym --script $$t --out $(B)/shots; \
	done

clean:
	rm -rf $(B)

.PHONY: all test clean
