#==========================================================================================
#
#   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
#   (c) 2019 by ManuLöwe (https://manuloewe.de/)
#
#	*** MAKEFILE ***
#
#==========================================================================================



# This requires Linux (on Windows, use the provided *.bat scripts instead), and the
# WLA DX cross assembler (v10.4).
# Also, you need to download and compile smconv from the tools folder of PVSnesLib
# (https://github.com/alekmaul/pvsneslib), I use v0.1.0 (newer versions untested).
# Graphics conversion (not implemented yet) will require superfamiconv
# (https://github.com/Optiroc/SuperFamiconv).

AS=wla-65816
ASFLAGS=-x -o
LD=wlalink
LDFLAGS=-r -s

itsource=music/parforceritt_b2_downsampled.it
target=bootrom

lnk=$(target).lnk
obj=$(target).obj
sfc=$(target).sfc
src=$(target).asm
sym=$(target).sym

.PHONY: all clean gfx soundbank

all:	$(sfc)
	dd if=/dev/zero of=out/POWERPAK/POWERPAK.CFG bs=512 count=1; \
	dd if=/dev/zero of=out/POWERPAK/LASTGAME.LOG bs=512 count=1; \
	dd if=/dev/zero of=out/POWERPAK/ERROR.LOG bs=2K count=1; \
	cp -u bootrom.sfc out/bootrom.sfc; \
	cp -u bootrom.sfc out/POWERPAK/UPDATE.ROM

$(obj): $(src) soundbank
	$(AS) $(ASFLAGS) $@ $<

$(sfc): $(obj)
	echo '[objects]\n$<' > $(lnk)
	$(LD) $(LDFLAGS) $(lnk) $@

clean:
	-rm -f $(lnk) $(obj) $(sfc) $(sym) soundbnk.*

gfx:
	cd gfx-rom; \
#	superfamiconv

soundbank:
	smconv -s -o soundbnk $(itsource)
