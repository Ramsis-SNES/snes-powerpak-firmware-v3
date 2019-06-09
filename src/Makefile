#==========================================================================================
#
#   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
#   (c) 2018 by ManuLöwe (https://manuloewe.de/)
#
#	*** MAKEFILE ***
#
#==========================================================================================



# This requires the WLA DX assembler (v9.8 or newer).
# Also, you need to download and compile smconv from the tools folder of PVSnesLib
# (https://github.com/alekmaul/pvsneslib).
# Graphics conversion (not supported yet) will require the Foxen snes-tile-tool.py
# (https://github.com/fo-fo/snes-tile-tool) and Python2.

AS=wla-65816
ASFLAGS=-x -o
LD=wlalink
LDFLAGS=-r -s

itsource=music/parforceritt_b2_downsampled.it
pyscript_gfx=snes-tile-tool.py
target=bootrom

lnk=$(target).lnk
obj=$(target).obj
sfc=$(target).sfc
src=$(target).asm
sym=$(target).sym

.PHONY: clean

all: soundbank $(sfc)

$(sfc): $(obj)
	printf %b "[objects]\n$<\n" > $(lnk)
	$(LD) $(LDFLAGS) $(lnk) $@

$(obj): $(src)
	$(AS) $(ASFLAGS) $@ $<

clean:
	-rm $(lnk) $(obj) $(sfc) $(sym) soundbnk.* Valid.Ext

graphics:
	cd gfx && \
	python $(pyscript_gfx)

soundbank:
	smconv -s -o soundbnk $(itsource)
