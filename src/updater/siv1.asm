;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** UPDATER (V1) CF MODULE ***
;
;==========================================================================================



; ****************************** Includes ******************************

	.INCLUDE "mapper.inc"		; MemoryMap, HeaderInfo
	.INCLUDE "vars1.asm"		; Global Variables



; ******************************** Main ********************************

Main:
	SEP #$20
	REP #$10

	lda #$FF				; hide logo (v1.0X)
	sta SpriteBuf1+17
	sta SpriteBuf1+21
	sta SpriteBuf1+25
	sta SpriteBuf1+29
	sta SpriteBuf2+1			; 32x32 sprites

	jump jPrintClearScreen

	SetCursorPos 2, 0
	PrintString " LOADING ..."

	jsr ConfigureFPGA

	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI
	sta DMAWRITEBANK

	jsr LoadUpdateFile

	SetCursorPos 2, 0
	PrintString " SNES POWERPAK FLASH UPDATER\n"
	PrintString " FOR CARTRIDGE ROM v1.0X\n"
	PrintString " (C) 2015 BY WWW.MANULOEWE.DE\n\n"
	PrintString " DETECTED CHIP ID: "

	jsr SPIdentification

	lda temp
	cmp #$1F
	bne +
	lda temp+1
	cmp #$D5
	bne +
	PrintString "AT29C010A"
	bra Flash_AT29C010A
+
	lda temp
	cmp #$BF
	bne +
	lda temp+1
	cmp #$B5
	bne +
	PrintString "SST39SF010A"
	brl Flash_SST39SF010A
+
	PrintString "UNKNOWN"
	brl error_UnknownFlashChip



Flash_AT29C010A:
	jsr msg_Warning

	sei					; disable NMI & IRQ
	stz REG_NMITIMEN

	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI
	sta DMAWRITEBANK

	ldx #$0000

__NextSectorBank0:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	ldy #$0000

-	lda DMAREADDATA
	sta $008000, x
	inx
	iny
	cpy #$0080
	bne -

	CheckToggleBit

	cpx #$8000
	bne __NextSectorBank0

	ldx #$0000

__NextSectorBank1:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	ldy #$0000

-	lda DMAREADDATA
	sta $018000, x
	inx
	iny
	cpy #$0080
	bne -

	CheckToggleBit

	cpx #$8000
	bne __NextSectorBank1

	ldx #$0000

__NextSectorBank2:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	ldy #$0000

-	lda DMAREADDATA
	sta $028000, x
	inx
	iny
	cpy #$0080
	bne -

	CheckToggleBit

	cpx #$8000
	bne __NextSectorBank2

	ldx #$0000

__NextSectorBank3:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	ldy #$0000

-	lda DMAREADDATA
	sta $038000, x
	inx
	iny
	cpy #$0080
	bne -

	CheckToggleBit

	cpx #$8000
	bne __NextSectorBank3

	WaitTwoFrames				; this helps prevent palette glitches after resetting

	lda #%10000001
	sta CONFIGWRITESTATUS			; reset PowerPak, stay in boot mode



Flash_SST39SF010A:
	jsr msg_Warning

	sei					; disable NMI & IRQ
	stz REG_NMITIMEN

	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI
	sta DMAWRITEBANK

	ldx #$0000

__Prepare4KBSectorBank0:
	lda #$AA				; sector erase command sequence
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$80
	sta $00D555
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$30
	sta $008000, x

	WaitTwoFrames

	ldy #$0000

__Write4KBSectorBank0:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	lda DMAREADDATA
	sta $008000, x

	CheckToggleBit

	inx
	iny
	cpy #$1000
	bne __Write4KBSectorBank0

	cpx #$8000
	bne __Prepare4KBSectorBank0

	ldx #$0000

__Prepare4KBSectorBank1:
	lda #$AA				; sector erase command sequence
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$80
	sta $00D555
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$30
	sta $018000, x

	WaitTwoFrames

	ldy #$0000

__Write4KBSectorBank1:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	lda DMAREADDATA
	sta $018000, x

	CheckToggleBit

	inx
	iny
	cpy #$1000
	bne __Write4KBSectorBank1

	cpx #$8000
	bne __Prepare4KBSectorBank1

	ldx #$0000

__Prepare4KBSectorBank2:
	lda #$AA				; sector erase command sequence
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$80
	sta $00D555
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$30
	sta $028000, x

	WaitTwoFrames

	ldy #$0000

__Write4KBSectorBank2:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	lda DMAREADDATA
	sta $028000, x

	CheckToggleBit

	inx
	iny
	cpy #$1000
	bne __Write4KBSectorBank2

	cpx #$8000
	bne __Prepare4KBSectorBank2

	ldx #$0000

__Prepare4KBSectorBank3:
	lda #$AA				; sector erase command sequence
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$80
	sta $00D555
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$30
	sta $038000, x

	WaitTwoFrames

	ldy #$0000

__Write4KBSectorBank3:
	lda #$AA
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$A0
	sta $00D555

	lda DMAREADDATA
	sta $038000, x

	CheckToggleBit

	inx
	iny
	cpy #$1000
	bne __Write4KBSectorBank3

	cpx #$8000
	bne __Prepare4KBSectorBank3

	WaitTwoFrames				; this helps prevent palette glitches after resetting

	lda #%10000001
	sta CONFIGWRITESTATUS			; reset PowerPak, stay in boot mode



; *************************** v1 Subroutines ***************************

LoadUpdateFile:
	lda #'R'
	sta exMatch1
	sta exMatch1+1
	sta exMatch1+2
	sta exMatch1+3

	lda #'O'
	sta exMatch2
	sta exMatch2+1
	sta exMatch2+2
	sta exMatch2+3

	lda #'M'
	sta exMatch3
	sta exMatch3+1
	sta exMatch3+2
	sta exMatch3+3

	lda baseDirCluster
	sta sourceCluster
	lda baseDirCluster+1
	sta sourceCluster+1
	lda baseDirCluster+2
	sta sourceCluster+2
	lda baseDirCluster+3
	sta sourceCluster+3

	jump jCardLoadDir			; "POWERPAK" directory

	jump jClearFindEntry

	lda #'U'
	sta findEntry+0
	lda #'P'
	sta findEntry+1
	lda #'D'
	sta findEntry+2
	lda #'A'
	sta findEntry+3
	lda #'T'
	sta findEntry+4
	lda #'E'
	sta findEntry+5

	jump jDirFindEntry			; get first cluster

	lda tempEntry+$1C			; v1.0X
	sta sourceCluster
	lda tempEntry+$1D
	sta sourceCluster+1
	lda tempEntry+$1E
	sta sourceCluster+2
	lda tempEntry+$1F
	sta sourceCluster+3

	stz bankCounter
	stz sectorCounter

	jump jCardReadFile

	jsr VerifyUpdateFile
rts



ConfigureFPGA:
	jump jClearFindEntry

	lda #'T'				; BIT extension hardcoded in loader maincode up to v2.00-beta2
	sta findEntry
	lda #'O'
	sta findEntry+1
	lda #'P'
	sta findEntry+2
	lda #'L'
	sta findEntry+3
	sta findEntry+7
	lda #'E'
	sta findEntry+4
	sta findEntry+6
	lda #'V'
	sta findEntry+5

	lda #$01
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA
	lda #$00
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	lda #$01
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA

	jump jCardLoadFPGA

	wai

	lda #%00000001
	sta CONFIGWRITESTATUS			; unlock SDRAM
rts



SPIdentification:
	sei					; disable NMI & IRQ
	stz $4200

	lda #$AA				; software product identification entry
	sta $00D555				; $5555 + $8000 (SNES LoROM address)
	lda #$55
	sta $00AAAA				; $2AAA + $8000 (SNES LoROM address)
	lda #$90
	sta $00D555

	WaitTwoFrames

	lda $008000				; manufacturer code (AT29C010A: $1F - SST39SF010A: $BF)
	sta temp
	lda $008001				; device code (AT29C010A: $D5 - SST39SF010A: $B5)
	sta temp+1

	lda #$AA				; software product identification exit
	sta $00D555
	lda #$55
	sta $00AAAA
	lda #$F0
	sta $00D555

	WaitTwoFrames

	lda #$81				; Vblank NMI + Auto Joypad Read
	sta $4200				; re-enable Vblank NMI
	cli
rts



msg_Warning:
	SetCursorPos 8, 0
	PrintString " WARNING!\n\n"
	PrintString " This update is performed AT\n"
	PrintString " YOUR OWN RISK! Don't switch\n"
	PrintString " off/reset the SNES while\n"
	PrintString " flashing. Any kind of power\n"
	PrintString " failure may permanently brick\n"
	PrintString " your SNES PowerPak!\n\n"
	PrintString " Reflashing takes about five\n"
	PrintString " seconds to complete, after\n"
	PrintString " which your SNES will reset.\n\n"
	PrintString " Press (A) to proceed ..."

	stz Joy1Press				; reset input buttons
	stz Joy1Press+1
	stz Joy1New
	stz Joy1New+1

-	wai

	lda Joy1New				; wait for user input
	and #%10000000				; A button
	beq -

	SetCursorPos 21, 0			; overwrite "Press the (A) button ..." message
	PrintString " REFLASHING, PLEASE WAIT ..."

	wai					; wait for the message to appear on the screen
rts



VerifyUpdateFile:
	lda #$C5				; string at offset $7FC5: PowerPak (part of internal ROM name),
	sta DMAWRITELO				; this ensures UPDATE.BIN actually contains a PowerPak bootloader
	lda #$7F				; while not preventing a possibly intended downgrade
	sta DMAWRITEHI
	lda #$00
	sta DMAWRITEBANK

	lda DMAREADDATA
	cmp #'P'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'o'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'w'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'e'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'r'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'P'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'a'
	bne error_UpdateFileCorrupt
	lda DMAREADDATA
	cmp #'k'
	bne error_UpdateFileCorrupt
rts



error_UpdateFileCorrupt:
	SetCursorPos 4, 0

	PrintString " ERROR!\n\n"
	PrintString " UPDATE.ROM appears to be\n"
	PrintString " corrupt.\n\n"
	PrintString " Please perform the following\n"
	PrintString " steps before trying again:\n\n"
	PrintString " - Redownload the firmware\n"
	PrintString "   package.\n"
	PrintString " - Reformat the CF card with\n"
	PrintString "   FAT32, and copy only the\n"
	PrintString "   /POWERPAK folder onto it.\n"
	PrintString " - Switch to another SNES\n"
	PrintString "   console."

	jump jForever



error_UnknownFlashChip:
	SetCursorPos 8, 0

	PrintString " ERROR!\n\n"
	PrintString " The in-system flash upgrade\n"
	PrintString " isn't available for your SNES\n"
	PrintString " PowerPak. Please revert to a\n"
	PrintString " previous firmware package,\n"
	PrintString " or reflash your ROM chip\n"
	PrintString " manually."

	jump jForever



; ******************************** EOF *********************************
