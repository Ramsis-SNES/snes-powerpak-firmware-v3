;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: FLASH UPDATER ***
;
;==========================================================================================



.ACCU 8
.INDEX 16

GotoFlashUpdater:
	lda	#$00
	sta	CONFIGWRITEDSP						; turn off DSP chip
	lda	#$00							; reset SDRAM address
	sta	DMAWRITELO
	sta	DMAWRITEHI
	sta	DMAWRITEBANK
	stz	sectorCounter
	stz	bankCounter
	jsr	CardReadFile						; source cluster already set in CheckForUpdate section
	jsr	VerifyUpdateFile					; back here means file is OK
	jsr	ClearSpriteText						; remove "Loading ..." message

	PrintSpriteText 3, 2, "SNES PowerPak Flash Updater", 4
	SetCursorPos 2, 0
	PrintString "v3.01, (c) 2018 by https://manuloewe.de\n\n"
	PrintString "Detected flash ROM chip ID: "

	ldx	#$0000
-	lda.l	SPIdentification, x					; copy SPIdentification subroutine to WRAM
	sta	codeBuffer, x
	inx
	cpx	#SPIdentification_End-SPIdentification
	bne	-

	jsl	codeBuffer						; jump to SPIdentification subroutine in WRAM
	lda	temp							; check for detected chip ID
	cmp	#$1F
	bne	+
	lda	temp+1
	cmp	#$D5
	bne	+

	PrintString "AT29C010A"

	jmp	FlashUpdateWarning

+	lda	temp
	cmp	#$BF
	bne	+
	lda	temp+1
	cmp	#$B5
	bne	+

	PrintString "SST39SF010A"

	jmp	FlashUpdateWarning

+	PrintString "unknown"
	SetCursorPos 6, 0
	PrintString "ERROR!\n\n"
	PrintString "The in-system flash upgrade isn't available for\n"
	PrintString "your SNES PowerPak. Please revert to a previous\n"
	PrintString "firmware package, or reflash your ROM chip\n"
	PrintString "manually."

	jmp	Forever



FlashUpdateWarning:
	SetCursorPos 6, 0
	PrintString "WARNING!\n\n"
	PrintString "This update is performed AT YOUR OWN RISK!\n\n"
	PrintString "Don't switch off or reset the SNES while flashing.\n"
	PrintString "Any kind of power failure may permanently brick\n"
	PrintString "your SNES PowerPak!\n\n"
	PrintString "Reflashing takes about five seconds to complete,\n"
	PrintString "after which your SNES will reset automatically.\n\n"
	PrintString "Press the (A) button to proceed ..."

	stz	Joy1Press						; reset input buttons
	stz	Joy1Press+1
	stz	Joy1New
	stz	Joy1New+1



; -------------------------- wait for user to press A button
-	wai
	lda	Joy1New							; wait for user input
	and	#%10000000						; A button
	beq	-

	SetCursorPos 17, 0						; overwrite "Press the (A) button ..." message
	PrintString "FLASHING IN PROGRESS, PLEASE WAIT ..."

	wai								; wait for the message to appear on the screen
	ldx	#$0000							; reset X



; -------------------------- use AT29C010A flashing code
	lda	temp							; re-check chip ID (temp variable shouldn't have changed, but you never know ...)
	cmp	#$1F
	bne	+
	lda	temp+1
	cmp	#$D5
	bne	+
-	lda.l	Flash_AT29C010A, x					; copy AT29C010A flashing code to WRAM
	sta	codeBuffer, x
	inx
	cpx	#Flash_AT29C010A_End-Flash_AT29C010A
	bne	-

	jml	codeBuffer						; jump to AT29C010A flashing code in WRAM



; -------------------------- use SST39SF010A flashing code
+	lda	temp
	cmp	#$BF
	bne	+
	lda	temp+1
	cmp	#$B5
	bne	+
-	lda.l	Flash_SST39SF010A, x					; copy SST39SF010A flashing code to WRAM
	sta	codeBuffer, x
	inx
	cpx	#Flash_SST39SF010A_End-Flash_SST39SF010A
	bne	-

	jml	codeBuffer						; jump to SST39SF010A flashing code in WRAM



; -------------------------- WRAM (at the least) has been compromised --> cancel flashing
+	ClearLine 19
	SetCursorPos 19, 0
	PrintString "ERROR!\n\n"
	PrintString "Unknown chip ID error."

	jmp	Forever



; *********************** WRAM flashing routines ***********************

; These must be uploaded to WRAM before being executed.
; Reminder: Only use relative branches here (BRA/BSR macro/etc.), as
; JMP/JSR/etc. will jump to unwanted fixed locations!

SPIdentification:
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	lda	#$AA							; software product identification entry
	sta	$00D555							; $5555 + $8000 (SNES LoROM address)
	lda	#$55
	sta	$00AAAA							; $2AAA + $8000 (SNES LoROM address)
	lda	#$90
	sta	$00D555

	WaitTwoFrames

	lda	$008000							; manufacturer code (AT29C010A: $1F - SST39SF010A: $BF)
	sta	temp
	lda	$008001							; device code (AT29C010A: $D5 - SST39SF010A: $B5)
	sta	temp+1
	lda	#$AA							; software product identification exit
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$F0
	sta	$00D555

	WaitTwoFrames

	lda	#$81							; Vblank NMI + Auto Joypad Read
	sta	REG_NMITIMEN						; re-enable Vblank NMI
	cli
	rtl

SPIdentification_End:



Flash_AT29C010A:
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	lda	#$00
	sta	DMAWRITELO
	sta	DMAWRITEHI
	sta	DMAWRITEBANK
	ldx	#$0000

__NextSectorBank0:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	ldy	#$0000
-	lda	DMAREADDATA
	sta	$008000, x
	inx
	iny
	cpy	#$0080
	bne	-

	CheckToggleBit

	cpx	#$8000
	bne	__NextSectorBank0

	ldx	#$0000

__NextSectorBank1:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	ldy	#$0000
-	lda	DMAREADDATA
	sta	$018000, x
	inx
	iny
	cpy	#$0080
	bne	-

	CheckToggleBit

	cpx	#$8000
	bne	__NextSectorBank1

	ldx	#$0000

__NextSectorBank2:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	ldy	#$0000
-	lda	DMAREADDATA
	sta	$028000, x
	inx
	iny
	cpy	#$0080
	bne	-

	CheckToggleBit

	cpx	#$8000
	bne	__NextSectorBank2

	ldx	#$0000

__NextSectorBank3:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	ldy	#$0000
-	lda	DMAREADDATA
	sta	$038000, x
	inx
	iny
	cpy	#$0080
	bne	-

	CheckToggleBit

	cpx	#$8000
	bne	__NextSectorBank3

	WaitTwoFrames							; this helps prevent palette glitches after resetting

	lda	#%10000001
	sta	CONFIGWRITESTATUS					; reset PowerPak, stay in boot mode

Flash_AT29C010A_End:



Flash_SST39SF010A:
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	lda	#$00
	sta	DMAWRITELO
	sta	DMAWRITEHI
	sta	DMAWRITEBANK
	ldx	#$0000

__Prepare4KBSectorBank0:
	lda	#$AA							; sector erase command sequence
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$80
	sta	$00D555
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$30
	sta	$008000, x

	WaitTwoFrames

	ldy	#$0000

__Write4KBSectorBank0:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	lda	DMAREADDATA
	sta	$008000, x

	CheckToggleBit

	inx
	iny
	cpy	#$1000
	bne	__Write4KBSectorBank0

	cpx	#$8000
	bne	__Prepare4KBSectorBank0

	ldx	#$0000

__Prepare4KBSectorBank1:
	lda	#$AA							; sector erase command sequence
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$80
	sta	$00D555
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$30
	sta	$018000, x

	WaitTwoFrames

	ldy	#$0000

__Write4KBSectorBank1:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	lda	DMAREADDATA
	sta	$018000, x

	CheckToggleBit

	inx
	iny
	cpy	#$1000
	bne	__Write4KBSectorBank1

	cpx	#$8000
	bne	__Prepare4KBSectorBank1

	ldx	#$0000

__Prepare4KBSectorBank2:
	lda	#$AA							; sector erase command sequence
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$80
	sta	$00D555
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$30
	sta	$028000, x

	WaitTwoFrames

	ldy	#$0000

__Write4KBSectorBank2:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	lda	DMAREADDATA
	sta	$028000, x

	CheckToggleBit

	inx
	iny
	cpy	#$1000
	bne	__Write4KBSectorBank2

	cpx	#$8000
	bne	__Prepare4KBSectorBank2

	ldx	#$0000

__Prepare4KBSectorBank3:
	lda	#$AA							; sector erase command sequence
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$80
	sta	$00D555
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$30
	sta	$038000, x

	WaitTwoFrames

	ldy	#$0000

__Write4KBSectorBank3:
	lda	#$AA
	sta	$00D555
	lda	#$55
	sta	$00AAAA
	lda	#$A0
	sta	$00D555
	lda	DMAREADDATA
	sta	$038000, x

	CheckToggleBit

	inx
	iny
	cpy	#$1000
	bne	__Write4KBSectorBank3

	cpx	#$8000
	bne	__Prepare4KBSectorBank3

	WaitTwoFrames							; this helps prevent palette glitches after resetting

	lda	#%10000001
	sta	CONFIGWRITESTATUS					; reset PowerPak, stay in boot mode

Flash_SST39SF010A_End:



; **************************** Subroutines *****************************

VerifyUpdateFile:
	lda	#$C5							; string at offset $7FC5: "PowerPak" (part of internal ROM name),
	sta	DMAWRITELO						; this ensures UPDATE.ROM actually contains a PowerPak bootloader
	lda	#$7F							; while not preventing a possibly intended downgrade
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	lda	DMAREADDATA
	cmp	#'P'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'o'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'w'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'e'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'r'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'P'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'a'
	bne	__CorruptUpdateROM
	lda	DMAREADDATA
	cmp	#'k'
	bne	__CorruptUpdateROM
	rts

__CorruptUpdateROM:
	jsr	ClearSpriteText						; remove "Loading ..." message

	PrintSpriteText 3, 2, "Error!", 4
	SetCursorPos 3, 0
	PrintString "UPDATE.ROM appears to be a corrupt file.\n\n"
	PrintString "Please perform the following steps before trying\n"
	PrintString "again:\n\n"
	PrintString "- Redownload the firmware update package.\n"
	PrintString "- Ensure your CF card works flawlessly with the\n"
	PrintString "  SNES PowerPak.\n"
	PrintString "- Reformat the card with FAT32, and copy nothing\n"
	PrintString "  but the /POWERPAK folder onto it.\n"
	PrintString "- If you have another SNES console available,\n"
	PrintString "  switch to that."

	jmp	Forever



; ******************************** EOF *********************************
