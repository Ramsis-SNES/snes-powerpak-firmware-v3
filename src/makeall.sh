#!/bin/bash

echo '-- ASSEMBLING SNES POWERPAK FIRMWARE --'

echo -e '\n-- generating POWERPAK.CFG --'
dd if=/dev/zero of=out/POWERPAK/POWERPAK.CFG  bs=512  count=1

echo -e '\n-- generating LASTGAME.LOG --'
dd if=/dev/zero of=out/POWERPAK/LASTGAME.LOG  bs=512  count=1

echo -e '\n-- generating ERROR.LOG --'
dd if=/dev/zero of=out/POWERPAK/ERROR.LOG  bs=2K  count=1

echo -e '\n-- assembling boot ROM --'

make -B

cp bootrom.sfc out/bootrom.sfc
cp bootrom.sfc out/POWERPAK/UPDATE.ROM
