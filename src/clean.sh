#!/bin/bash

if [ -f *.lst ]
    then rm *.lst
fi

if [ -f *.sfc ]
    then rm *.sfc
fi

if [ -f *.sym ]
    then rm *.sym
fi

if [ -f *.tmp ]
    then rm *.tmp
fi

if [ -f *.usage ]
    then rm *.usage
fi

#if [ -f soundbnk.* ]
#    then rm -f soundbnk.*
#fi

if [ -f Valid.ext ]
    then rm -f Valid.ext
fi

if [ -f out/*.log ]
    then rm out/*.log
fi

if [ -f out/*.usage ]
    then rm out/*.usage
fi
