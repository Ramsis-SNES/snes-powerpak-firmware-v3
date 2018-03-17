#!/bin/bash

echo '-- ASSEMBLING SNES POWERPAK SOFTWARE --'

echo '-- generating POWERPAK.CFG --'
dd if=/dev/zero of=out/POWERPAK/POWERPAK.CFG  bs=512  count=1

echo '-- generating LASTGAME.LOG --'
dd if=/dev/zero of=out/POWERPAK/LASTGAME.LOG  bs=512  count=1

echo '-- generating ERROR.LOG --'
dd if=/dev/zero of=out/POWERPAK/ERROR.LOG  bs=2K  count=1

make -B

cp bootrom.sfc out/bootrom.sfc
cp bootrom.sfc out/POWERPAK/UPDATE.ROM

echo '-- FINISHED! --'
