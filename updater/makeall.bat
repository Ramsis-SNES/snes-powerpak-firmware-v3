@echo off

echo -- ASSEMBLING SIv1.MAP --
echo [objects] > siv1.lnk
echo siv1.o >> siv1.lnk
wla-65816 -o siv1.asm siv1.o
wlalink -rs siv1.lnk siv1.sfc
head -c 5120 siv1.sfc > ..\out\POWERPAK\SIv1.MAP

echo -- ASSEMBLING SIv2.MAP --
echo [objects] > siv2.lnk
echo siv2.o >> siv2.lnk
wla-65816 -o siv2.asm siv2.o
wlalink -rs siv2.lnk siv2.sfc
head -c 5120 siv2.sfc > ..\out\POWERPAK\SIv2.MAP

del *.o
del *.lnk
del *.sfc
del *.sym

pause
