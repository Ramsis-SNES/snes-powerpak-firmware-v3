;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** UPDATE MODULE ROM MAKEUP ***
;
;==========================================================================================



.DEFINE HEADER_OFF $0000



.MEMORYMAP
	DEFAULTSLOT 0
	SLOTSIZE $8000
	SLOT 0 $0200
.ENDME



.ROMBANKMAP
	BANKSTOTAL 4
	BANKSIZE $8000				; ROM banks are 32 KBytes in size
	BANKS 4					; 4 ROM banks = 1Mbit (CF modules will be "trimmed" in the make script)
.ENDRO



; ******************************** EOF *********************************
