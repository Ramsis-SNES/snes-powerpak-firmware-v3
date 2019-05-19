;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: SRAM HANDLER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.ACCU 8
.INDEX 16

; ************************* Init SRAM browser **************************

; File extensions to look for, mapped to search variables:
;
;           |     | +1  | +2  | +3  | +4  | +5  | +6  | +7  | +8  | +9  | +10 |
; ------------------------------------------------------------------------------
; extMatch1 |  S  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch2 |  R  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch3 |  M  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------



InitSRMBrowser:
	FindFile "SAVES.   "

	lda	#$01							; number of file types to look for (1, SRM only)
	sta	extNum
	stz	extNum+1
	lda	#'S'
	sta	extMatch1
	lda	#'R'
	sta	extMatch2
	lda	#'M'
	sta	extMatch3
	lda	#2							; set subdirectory counter accordingly
	sta	DP_SubDirCounter
	stz	DP_SubDirCounter+1
	jsr	FileBrowser
	lda	DP_SelectionFlags					; check if file was selected
	and	#%00000001
	beq	@SRAMBrowserEnd					; no, jump out

	Accu16								; SRM file selected

	ldy	#$0000
-	lda	tempEntry, y						; copy SRM file name + cluster
	sta	saveName, y
	iny
	iny
	cpy	#$0080							; 128 bytes
	bne	-

	Accu8

@SRAMBrowserEnd:
	rts



; ************************* SRAM save handler **************************

BattUsedInitSaveSRAM:
	DrawFrame 0, 11, 31, 11

	lda	#92							; patch HDMA table in WRAM with scanline values matching the questions "window" border
	sta	HDMAtable.ColorMath+0
	lda	#86
	sta	HDMAtable.ColorMath+3
	lda	#%00001000						; enable color math channel
	tsb	DP_HDMAchannels

	SetTextPos 11, 0
	PrintString "The game you've played features battery-backed SRAM\n"
	PrintString "to save your progress. Please choose an option:"
	SetTextPos 14, 1

	jsr	LoadLastGame						; load last game info
	lda	saveName.Cluster					; if cluster=0, no file loaded previously
	bne	@AutoSaveEntry
	lda	saveName.Cluster+1
	bne	@AutoSaveEntry
	lda	saveName.Cluster+2
	bne	@AutoSaveEntry
	lda	saveName.Cluster+3
	bne	@AutoSaveEntry

	PrintString "(No SRAM file loaded previously, auto-saving disabled)"

	lda	#$A0
	sta	cursorY
	bra	@AutoSaveMenuNext

@AutoSaveEntry:
	lda	#$88							; cursor line = (cursorY - $18) / $08 (in this case, $0E=14)
	sta	cursorY

	PrintString "Save SRAM to the previously loaded file:"

	ldy	#$0000
-	lda	saveName, y						; copy save name to tempEntry for printing
	sta	tempEntry, y
	iny
	cpy	#$0038							; only copy 56 characters
	bne	-

	SetTextPos 15, 1

	jsr	PrintTempEntry

@AutoSaveMenuNext:
	SetTextPos 17, 1
	PrintString "Select a file ..."
	SetTextPos 18, 1
	PrintString "Cancel and discard SRAM!"

	lda	#$0D
	sta	cursorX
	stz	Joy1New							; reset input buttons
	stz	Joy1New+1
	stz	Joy1Press
	stz	Joy1Press+1



; -------------------------- SRAM handler questions loop
SRAMQuestionsLoop:
	wai



; -------------------------- check for A button = make a selection
	lda	Joy1New
	bmi	SRAMSelectionMade

@AButtonDone:



; -------------------------- check for d-pad up = change selection
	lda	Joy1New+1
	and	#%00001000
	beq	@DpadUpDone
	jsr	PrevButton						; up pressed

@DpadUpDone:



; -------------------------- check for d-pad down = change selection
	lda	Joy1New+1
	and	#%00000100
	beq	@DpadDownDone
	jsr	NextButton						; down pressed

@DpadDownDone:

	bra	SRAMQuestionsLoop



; -------------------------- selection made
SRAMSelectionMade:
	lda	cursorY
	cmp	#$88							; if at "Save to previous file", do just that :-)
	beq	@AutoSaveSRAM
	cmp	#$A0							; if at "Select a file", go to SRAM browser
	beq	@SelectSRAMFile
	jmp	@SRAMSavedOrCancelled					; otherwise, discard SRAM

@SelectSRAMFile:
	lda	#%00001000						; disable color math channel
	trb	DP_HDMAchannels
	jsr	SpriteMessageLoading
	jsr	InitSRMBrowser						; launch SRAM browser

	lda	DP_SelectionFlags					; back from browser, check again if SRM file was picked or not
	and	#%00000001
	bne	@SRAMFilePicked
	jmp	BattUsedInitSaveSRAM					; no SRM file picked --> go back to questions

@AutoSaveSRAM:
	lda	saveName.Cluster					; if cluster=0, no file loaded previously ...
	bne	@SRAMFilePicked
	lda	saveName.Cluster+1
	bne	@SRAMFilePicked
	lda	saveName.Cluster+2
	bne	@SRAMFilePicked
	lda	saveName.Cluster+3
	bne	@SRAMFilePicked
	jmp	SRAMQuestionsLoop					; ... so go back to questions loop

@SRAMFilePicked:
	jsr	PrintClearScreen

	DrawFrame 0, 15, 31, 5						; draw a smaller frame for success message

	lda	#124							; patch HDMA table in WRAM with scanline values matching the message "window" border
	sta	HDMAtable.ColorMath+0
	lda	#38
	sta	HDMAtable.ColorMath+3
	lda	#%00001000						; enable color math channel
	tsb	DP_HDMAchannels
	jsr	SaveSRAMFile

	WaitForUserInput

@SRAMSavedOrCancelled:							; if cursor was at "Cancel" (cursorY=$A8), go back to intro as well
	lda	#$0F
-	wai								; screen fade-out loop
	dec	a							; 15 / 3 = 5 frames
	dec	a
	dec	a
	sta	REG_INIDISP
	bne	-

	lda	#%00000001						; no more battery flag
	sta	CONFIGWRITESTATUS

	HideCursorSprite

	lda	#%00001000						; disable color math channel
	trb	DP_HDMAchannels
 	lda	#52							; reset scanline values in WRAM HDMA table to the SPC player "window" border
	sta	HDMAtable.ColorMath+0
	lda	#126
	sta	HDMAtable.ColorMath+3
	jsr	PrintClearScreen
	rts



; ************************** SRAM navigation ***************************

NextButton:								; $88 -> $A0 -> $A8
	lda	cursorY
	clc
	adc	#$08
	sta	cursorY
	cmp	#$B0
	bne	@NextButtonDone
	lda	#$88
	sta	cursorY
	bra	@NextButtonDone2

@NextButtonDone:
	lda	cursorY
	cmp	#$90
	bne	@NextButtonDone2
	lda	#$A0
	sta	cursorY

@NextButtonDone2:
	rts



PrevButton:								; $A8 -> $A0 -> $88
	lda	cursorY
	sec
	sbc	#$08
	sta	cursorY
	cmp	#$80
	bne	@PrevButtonDone
	lda	#$A8
	sta	cursorY
	bra	@PrevButtonDone2

@PrevButtonDone:
	lda	cursorY
	cmp	#$98
	bne	@PrevButtonDone2
	lda	#$88
	sta	cursorY

@PrevButtonDone2:
	rts



; ***************************** SRAM saver *****************************

SaveSRAMFile:
	jsr	SpriteInit						; purge OAM to suppress sprite artifacts // FIXME, prob. unnecessary (use HideCursorSprite)

	Accu16

	lda	saveName.Cluster					; copy save cluster to source cluster
	sta	sourceCluster
	lda	saveName.Cluster+2
	sta	sourceCluster+2

	Accu8

	lda	#$00
	sta	DMAWRITELO
	sta	DMAWRITEHI
	lda	#$F8
	sta	DMAWRITEBANK

	SetTextPos 15, 0
	PrintString "Saving SRAM file to CF card ..."

	wai								; make sure the message appears on the screen
	lda	#kSDRAM
	sta	DP_DestOrSrcType
	jsr	CardWriteFile

	SetTextPos 15, 0
	PrintString "SRAM file saved successfully!  "			; don't remove trailing spaces
	SetTextPos 16, 0
	PrintString "Press any button to return to the titlescreen."

	rts



; ******************************** EOF *********************************
