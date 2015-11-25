@echo off

:main
echo -- ASSEMBLING SNES POWERPAK SOFTWARE --

echo -- generating POWERPAK.CFG --
zerofill -f -q 0x200 out\POWERPAK\POWERPAK.CFG

echo -- generating LASTGAME.LOG --
zerofill -f -q 0x200 out\POWERPAK\LASTGAME.LOG

echo -- generating ERROR.LOG --
zerofill -f -q 0x800 out\POWERPAK\ERROR.LOG

rem echo -- copying TOPLEVEL.BIT --
rem copy TOPLEVEL.BIT out\POWERPAK\TOPLEVEL.BIT

echo -- preparing SOUNDBANK --
smconv -s -o soundbnk "music\parforceritt_b2_downsampled.it"

echo -- assembling BOOTROM.SFC/UPDATE.ROM --
echo [objects] > bootrom.lnk
echo bootrom.o >> bootrom.lnk
wla-65816 -xo bootrom.asm bootrom.o
wlalink -rs bootrom.lnk bootrom.sfc
copy bootrom.sfc out\bootrom.sfc
copy bootrom.sfc out\POWERPAK\UPDATE.ROM
del bootrom.o
del bootrom.lnk

echo -- FINISHED! --
pause
