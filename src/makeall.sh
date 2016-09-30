#!/bin/bash

echo '-- ASSEMBLING SNES POWERPAK SOFTWARE --'

echo '-- generating POWERPAK.CFG --'
dd if=/dev/zero of=out/POWERPAK/POWERPAK.CFG  bs=512  count=1

echo '-- generating LASTGAME.LOG --'
dd if=/dev/zero of=out/POWERPAK/LASTGAME.LOG  bs=512  count=1

echo '-- generating ERROR.LOG --'
dd if=/dev/zero of=out/POWERPAK/ERROR.LOG  bs=2K  count=1

#echo -- copying TOPLEVEL.BIT --
#cp TOPLEVEL.BIT out/POWERPAK/TOPLEVEL.BIT

#echo '-- preparing SOUNDBANK --'
#smconv -s -o soundbnk "music\parforceritt_b2_downsampled.it"

echo -e '[objects]\nbootrom.o' >> bootrom.lnk
wla-65816 -x -o bootrom.o bootrom.asm
wlalink -r -s bootrom.lnk bootrom.sfc
cp bootrom.sfc out/bootrom.sfc
cp bootrom.sfc out/POWERPAK/UPDATE.ROM
rm bootrom.lnk
rm bootrom.o

echo '-- FINISHED! --'
echo 'Press any key to continue...'
read -n 1 -s
