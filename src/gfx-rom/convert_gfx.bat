@echo off

echo -- CONVERTING SPRITES --
gfx2snes -gs8 -mR! -pc16 -po16 -fpcx -n powerpak_128x128.pcx
gfx2snes -gs8 -mR! -pc16 -po16 -fpcx -n cursor_buttons.pcx

rem ****** Old command line for neviksti's tool:
rem ****** pcx2snes %filename% -n -s8 -c16 -o16
gfx2snes -gs8 -mR! -pc16 -po16 -fpcx -n powerpak_small.pcx

echo -- CONVERTING FONTS --
rem ****** No palettes, font palettes are defined in loader_gfxdata.inc
rem ****** gfx2snes seems to have issues converting 2bpp fonts, so we use pcx2snes for that
pcx2snes font-bg -n -s8 -c4 -o0
gfx2snes -gs8 -mR! -p! -pc16 -fbmp -n font-spr.bmp

echo -- FINISHED! --
pause
