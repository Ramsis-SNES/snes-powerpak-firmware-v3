;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: SETTINGS MENU ***
;
;==========================================================================================



.ACCU 8
.INDEX 16

GotoSettings:
	jsr	HideButtonSprites
	jsr	HideLogoSprites
	jsr	PrintClearScreen
	lda	#cursorXsettings					; put cursor on first menu line
	sta	cursorX
	lda	#cursorYsetmenu1
	sta	cursorY

__ReturnFromMenuSection:
	PrintSpriteText 9, 9, "Settings:", 7
	DrawFrame 7, 8, 17, 8
	SetCursorPos 9,  7
	PrintString "System info, hardware test"
	SetCursorPos 10,  7
	PrintString "Toggle DMA mode (currently"

	jsr	DisplayDMASetting					; look up DMA setting to complete the line

	SetCursorPos 11,  7
	PrintString "Select a theme ..."
	SetCursorPos 12,  7
	PrintString "View v3.00 developer's note"
	SetCursorPos 13,  7
	PrintString "Check for firmware update"



; -------------------------- Show button hints
	Accu16

	lda	#$9898							; Y, X
	sta	SpriteBuf1.Buttons
	lda	#$03A0							; tile properties, tile num for A button
	sta	SpriteBuf1.Buttons+2
	lda	#$A898							; Y, X
	sta	SpriteBuf1.Buttons+4
	lda	#$03A2							; tile properties, tile num for B button
	sta	SpriteBuf1.Buttons+6
	lda	#$B896							; Y, X
	sta	SpriteBuf1.Buttons+8
	lda	#$03AC							; tile properties, tile num for Start button highlighted
	sta	SpriteBuf1.Buttons+10

	Accu8

	SetCursorPos 18, 19
	PrintString "Accept"
	SetCursorPos 20, 19
	PrintString "Back"
	SetCursorPos 22, 19
	PrintString "Save settings"

.IFDEF SHOWDEBUGMSGS
	SetCursorPos 0, 22

	Accu16

	tsc								; print stack pointer (initial value: $1FFF)

	Accu8

	xba
	sta	temp

	PrintHexNum temp

	xba
	sta	temp

	PrintHexNum temp
.ENDIF

	stz	Joy1New							; reset input buttons
	stz	Joy1New+1
	stz	Joy1Press
	stz	Joy1Press+1



; *************************** Settings loop ****************************

SettingsLoop:
	wai

.IFDEF SHOWDEBUGMSGS
	SetCursorPos 2, 22

	PrintNum dontUseDMA
.ENDIF



; -------------------------- check for d-pad up, move cursor
	lda	Joy1New+1
	and	#%00001000
	beq	++
	lda	cursorY
	sec
	sbc	#SetMenLineHeight
	cmp	#cursorYsetmenu1-SetMenLineHeight
	bne	+
	lda	#cursorYsetmenu5
+	sta	cursorY
++



; -------------------------- check for d-pad down, move cursor
	lda	Joy1New+1
	and	#%00000100
	beq	++
	lda	cursorY
	clc
	adc	#SetMenLineHeight
	cmp	#cursorYsetmenu5+SetMenLineHeight
	bne	+
	lda	#cursorYsetmenu1
+	sta	cursorY
++



; -------------------------- check for A button = make a selection
	lda	Joy1New
	and	#%10000000
	beq	+
	bra	CheckSelection
+



; -------------------------- check for B button = back to intro
	lda	Joy1New+1
	and	#%10000000
	beq	+
	jsr	PrintClearScreen
	jmp	GotoIntroScreen
+



; -------------------------- check for Start button = save settings, reset to intro
	lda	Joy1New+1
	and	#%00010000
	beq	+
	jmp	ResetSystem
+



; -------------------------- show/hide hint
	lda	cursorY
	cmp	#cursorYsetmenu3					; cursor on "Select a theme"?
	bne	+

	SetCursorPos 16, 1
	PrintString "Please save your settings after selecting a new theme."

	bra	++

+	ClearLine 16

++
	jmp	SettingsLoop



; ************************* Selection handler **************************

CheckSelection:



; -------------------------- check for cursor position
	lda	cursorY
	cmp	#cursorYsetmenu1					; line = system info?
	bne	+
	jmp	ShowSysInfo

+	cmp	#cursorYsetmenu2					; line = toggle DMA?
	bne	++
	lda	dontUseDMA						; toggle DMA setting ...
	beq	+
	stz	dontUseDMA
	bra	__ToggleDMADone

+	lda	#$01
	sta	dontUseDMA

__ToggleDMADone:
	jsr	DisplayDMASetting
	jmp	SettingsLoop						; ... and return

++	cmp	#cursorYsetmenu3					; line = select theme?
	bne	+
	jmp	InitTHMBrowser

+	cmp	#cursorYsetmenu5					; line = firmware update?
	beq	CheckForUpdate
	jsr	SpriteMessageLoading					; otherwise, go to developer's note
	jsr	LoadDevMusic						; load music
	jmp	GotoDevNote



CheckForUpdate:
	jsr	SpriteMessageLoading

	FindFile "UPDATE.ROM"						; load update ROM file

	lda	Joy1Press
	and	#%01110000						; if user holds L+R+X ...
	cmp	#%01110000
	bne	+
	jmp	GotoFlashUpdater					; ... force launching of flash updater (for manual downgrade etc.)

+	lda	#<sectorBuffer1
	sta	destLo
	lda	#>sectorBuffer1
	sta	destHi							; load first sector to check if UPDATE.ROM is a "MUFASA" firmware, and newer than installed ROM
	stz	destBank
	stz	sectorCounter
	stz	bankCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector
	lda	#kDestWRAM
	sta	destType
	jsr	CardReadSector						; sector -> WRAM

	Accu16

	lda	#STR_Firmware_Codename					; look for "MUFASA"
	and	#$7FFF							; mask off SNES LoROM address gap ($8000)
	inc	a							; skip quotes
	tax
	lda	sectorBuffer1, x
	cmp	#$554D							; MU
	bne	+
	inx
	inx
	lda	sectorBuffer1, x
	cmp	#$4146							; FA
	bne	+
	inx
	inx
	lda	sectorBuffer1, x
	cmp	#$4153							; SA
	beq	__UpdateRomIsValid

+	Accu8

	jsr	ClearSpriteText						; remove "Loading ..." message
	jsr	SpriteMessageError

	SetCursorPos 20, 1
	PrintString "UPDATE.ROM is not a valid \"MUFASA\" firmware file.\n"
	PrintString "  Press any button ..."

	jmp	__WaitBeforeReturn

.ACCU 16

__UpdateRomIsValid:
	lda	#STR_Firmware_VerNum					; compare version of UPDATE.ROM against installed boot ROM
	tax
	and	#$7FFF							; mask off SNES LoROM address gap
	tay

	Accu8

-	lda	$0000, x						; compare major release version
	cmp	sectorBuffer1, y
	bcs	+
	jmp	GotoFlashUpdater

+	inx								; advance ROM offset
	iny								; advance sector buffer offset
	cpx	#STR_Firmware_VerNum_End
	bne	-

	Accu16

	lda	#STR_Firmware_BuildNum
	tax
	and	#$7FFF							; mask off SNES LoROM address gap
	tay

	Accu8

-	lda	$0000, x						; compare build no.
	cmp	sectorBuffer1, y
	bcs	+
	jmp	GotoFlashUpdater

+	inx
	iny
	cpx	#STR_Firmware_BuildNum_End
	bne	-

	jsr	ClearSpriteText						; remove "Loading ..." message

	PrintSpriteText 21, 3, "Firmware is up to date!", 5
	SetCursorPos 20, 1
	PrintString "Press any button ..."

__WaitBeforeReturn:
	WaitForUserInput

	jsr	ClearSpriteText						; remove "Firmware is ..."/"Error!" message

	ClearLine 20							; remove additional info
	ClearLine 21

	lda	#cursorXsettings					; restore cursor position
	sta	cursorX
	lda	#cursorYsetmenu5					; menu line: firmware update
	sta	cursorY
	jmp	__ReturnFromMenuSection					; return to settings menu



ShowSysInfo:
	HideCursorSprite

	jsr	HideButtonSprites
	jsr	PrintClearScreen
	jsr	ShowMainGFX
	jsr	PrintRomVersion
	jsr	PrintCardFS						; show CF card filesystem type
	jsr	ShowChipsetDMA						; show console chipset revision, perform hardware checks
	jsr	FPGACheck
	jsr	DSPCheck
	jsr	SDRAMCheck
	jsr	MemCheck						; test SDRAM, back here means SDRAM = O.K.
	jsr	PrintClearScreen
	jsr	HideLogoSprites
	jmp	GotoSettings						; return to settings menu



; ******************************* Reset ********************************

ResetSystem:
	HideCursorSprite

	jsr	HideButtonSprites
	jsr	PrintClearScreen

	PrintSpriteText 12, 9, "Saving settings ...", 7

	wai								; just to be sure
	jsr	SaveConfig
	lda	#$0F
-	wai								; screen fade-out loop
	dec	a							; 15 / 3 = 5 frames
	dec	a
	dec	a
	sta	$2100
	bne	-

	lda	#%10000001
	sta	CONFIGWRITESTATUS					; reset PowerPak, stay in boot mode



; ************************* Check DMA setting **************************

DisplayDMASetting:
	SetCursorPos 10, 20

	lda	dontUseDMA						; check for current DMA setting
	bne	+

	PrintString " on) "						; don't remove the trailing space

	bra	__DisplayDMASettingDone

+	PrintString " off)"

__DisplayDMASettingDone:
	rts



; *************************** Save settings ****************************

SaveConfig:
	FindFile "POWERPAK.CFG"						; file to save settings to

	ldy	#$0000
	lda	dontUseDMA						; save DMA setting
	sta	sectorBuffer1, y
	iny

	Accu16

	lda	DP_ThemeFileClusterLo					; save theme file cluster
	sta	sectorBuffer1, y
	iny
	iny
	lda	DP_ThemeFileClusterHi
	sta	sectorBuffer1, y
	iny
	iny

	Accu8

	lda	#$00							; zero out the rest of POWERPAK.CFG
-	sta	sectorBuffer1, y
	iny
	cpy	#$0200							; 512 bytes total
	bne	-

	lda	#<sectorBuffer1
	sta	sourceLo
	lda	#>sectorBuffer1
	sta	sourceHi
	stz	sourceBank
	lda	#kSourceWRAM
	sta	sourceType
	jsr	CardWriteFile
	rts



; **************************** SDRAM check *****************************

MemCheck:
	SetCursorPos 17, 1
	PrintString "SDRAM check:"

	Accu16

	lda	#$9898							; Y, X
	sta	SpriteBuf1.Buttons
	lda	#$03A2							; tile properties, tile num for B button
	sta	SpriteBuf1.Buttons+2

	Accu8

	SetCursorPos 18, 19
	PrintString "Cancel"

	wai
	stz	errorCode
	stz	temp
	stz	temp+1
	stz	temp+2
	lda	#$00							; reset SDRAM address
	sta	DMAWRITEBANK
	sta	DMAWRITELO
	sta	DMAWRITEHI

	SetCursorPos 18, 1
	PrintString "Writing bank $  \n  Please hold on ..."

MemCheckWriteLoop:
	lda	Joy1New+1						; check for user input
	and	#%10000000						; B button
	beq	+

	ClearLine 18
	SetCursorPos 17, 6
	PrintString "k cancelled!"					; "SDRAM check cancelled!"

	jmp	__MemCheckFinished

+	lda	errorCode
	sta	DMAREADDATA
	inc	errorCode
	lda	temp+2
	sta	temp+3

	Accu16

	lda	temp
	clc
	adc	#$000F
	sta	temp

	Accu8

	lda	temp+2
	adc	#$00
	sta	temp+2
	cmp	temp+3
	beq	MemCheckWriteLoopNext
	jsr	MemCheckUpdateBank

MemCheckWriteLoopNext:
	lda	temp+2
	cmp	#$FF
	bne	MemCheckWriteLoop

	stz	errorCode
	stz	temp
	stz	temp+1
	stz	temp+2
	lda	#$00							; reset SDRAM address
	sta	DMAWRITEBANK
	sta	DMAWRITELO
	sta	DMAWRITEHI

	SetCursorPos 18, 1
	PrintString "Read"						; "Reading bank"

MemCheckReadLoop:
	lda	Joy1New+1						; check for user input
	and	#%10000000						; B button
	beq	+

	ClearLine 18
	SetCursorPos 17, 6
	PrintString "k cancelled!"					; "SDRAM check cancelled!"

	bra	__MemCheckFinished

+	lda	DMAREADDATA
	sta	temp+4
	cmp	errorCode
	beq	+
	jmp	MemCheckError

+	inc	errorCode
	lda	temp+2
	sta	temp+3

	Accu16

	lda	temp
	clc
	adc	#$000F
	sta	temp

	Accu8

	lda	temp+2
	adc	#$00
	sta	temp+2
	cmp	temp+3
	beq	MemCheckReadLoopNext
	jsr	MemCheckUpdateBank

MemCheckReadLoopNext:
	lda	temp+2
	cmp	#$FF
	bne	MemCheckReadLoop

	ClearLine 17							; hide "SDRAM check"
	ClearLine 18							; hide bank no.
	PrintSpriteText 19, 3, "SDRAM O.K.!", 5

__MemCheckFinished:
	jsr	HideButtonSprites

	SetCursorPos 18, 1
	PrintString "Press any button ..."
	ClearLine 19							; remove "Please hold on ..."

	WaitForUserInput

	rts



MemCheckError:
	ClearLine 17							; hide "SDRAM check:"
	SetCursorPos 18, 19
	PrintString "      "						; hide cancel message

	jsr	HideButtonSprites

	PrintSpriteText 19, 3, "SDRAM error!", 4
	SetCursorPos 18, 9
	PrintString ", read byte value: $"
	PrintHexNum temp+4
	SetCursorPos 19, 1
	PrintString "Expected byte value: $"
	PrintHexNum errorCode
	PrintString " at address $"
	PrintHexNum temp+2
	PrintHexNum temp+1
	PrintHexNum temp
	SetCursorPos 20, 1
	PrintString "Trying again 4 times:"

	ldy	#$0004							; 4 retries, the exact amount doesn't really matter ;-)

-	PrintString "  $"

	lda	temp+2
	sta	DMAWRITEBANK
	lda	temp+1
	sta	DMAWRITEHI
	lda	temp+0
	sta	DMAWRITELO
	lda	DMAREADDATA
	sta	temp+4

	PrintHexNum temp+4

	dey
	bne	-

	SetCursorPos 22, 1
	PrintString "CRITICAL HARDWARE ERROR! PLEASE CHECK ERROR.LOG!"

	jsr	LogScreen						; save to ERROR.LOG for later review
	jmp	Forever							; SDRAM error means potentially faulty PowerPak --> halt



MemCheckUpdateBank:
	SetCursorPos 18, 8
	PrintHexNum temp+2						; show bank no. while writing/reading SDRAM

	rts



; ******************************** EOF *********************************
