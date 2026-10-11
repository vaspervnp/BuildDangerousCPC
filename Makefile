RASM ?= rasm
IDSK ?= iDSK
PY   ?= python3
B    := build

ASSETS := $(B)/tiles.bin $(B)/thanos.bin $(B)/room_test.bin
SRC    := $(wildcard src/*.asm)

all: $(B)/bd.dsk

$(B):
	mkdir -p $@

$(B)/tiles.bin: assets/gfx/tiles.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py tiles $< $@

$(B)/thanos.bin: assets/gfx/thanos.png tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py sprites $< $@ --mirror

$(B)/room_%.bin: assets/rooms/%.txt tools/cpcgfx.py | $(B)
	$(PY) tools/cpcgfx.py room $< $@

$(B)/bd.bin: $(SRC) $(ASSETS)
	$(RASM) src/main.asm -I. -ob $@ -os $(B)/bd.sym -s -sl

$(B)/bd.dsk: $(B)/bd.bin
	rm -f $@
	$(IDSK) $@ -n
	$(IDSK) $@ -i $< -t 1 -c 1000 -e 1000

# Headless smoke run: walks Thanos around the test room and saves screenshots to build/shots/.
test: $(B)/bd.bin
	$(PY) tools/cpcrun.py $(B)/bd.bin --sym $(B)/bd.sym --script tests/smoke.txt --out $(B)/shots

clean:
	rm -rf $(B)

.PHONY: all test clean
