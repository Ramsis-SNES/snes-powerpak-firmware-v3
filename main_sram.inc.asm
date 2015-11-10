;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** MAIN CODE SECTION: SRAM HANDLER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.ACCU 8
.INDEX 16

; ************************* SRAM save handler **************************

BattUsedInitSaveSRAM:
	DrawFrame 0, 11, 31, 11

	lda #92					; patch HDMA table in WRAM with scanline values matching the questions "window" border
	sta HDMAtable.ColorMath+0

	lda #86
	sta HDMAtable.ColorMath+3

	lda #%00001000				; enable color math channel
	tsb DP_HDMAchannels

	SetCursorPos 11, 0
	PrintString "The game you've played features battery-backed SRAM\n"
	PrintString "to save your progress. Please choose an option:"

	SetCursorPos 14, 1

	jsr LoadLastGame			; load last game info

	lda saveName.sCluster			; if cluster=0, no file loaded previously
	bne __AutoSaveEntry

	lda saveName.sCluster+1
	bne __AutoSaveEntry

	lda saveName.sCluster+2
	bne __AutoSaveEntry

	lda saveName.sCluster+3
	bne __AutoSaveEntry

	PrintString "(No SRAM file loaded previously, auto-saving disabled)"

	lda #$A0
	sta cursorY

	bra __AutoSaveMenuNext

__AutoSaveEntry:
	lda #$88				; cursor line = (cursorY - $18) / $08 (in this case, $0E=14)
	sta cursorY

	PrintString "Save SRAM to the previously loaded file:"

	ldy #$0000

-	lda saveName, y				; copy save name to tempEntry for printing
	sta tempEntry, y
	iny
	cpy #$0038				; only copy 56 characters
	bne -

	SetCursorPos 15, 1
	jsr PrintTempEntry

__AutoSaveMenuNext:
	SetCursorPos 17, 1
	PrintString "Select a file ..."

	SetCursorPos 18, 1
	PrintString "Cancel and discard SRAM!"

	lda #$0D
	sta cursorX

	stz Joy1New				; reset input buttons
	stz Joy1New+1
	stz Joy1Press
	stz Joy1Press+1



; -------------------------- SRAM handler questions loop
SRAMQuestionsLoop:
	wai



; -------------------------- check for A button = make a selection
	lda Joy1New
	and #%10000000
	bne __SRAMSelectionMade



; -------------------------- check for d-pad up = change selection
	lda Joy1New+1
	and #%00001000
	beq +

	jsr PrevButton				; up pressed

+



; -------------------------- check for d-pad down = change selection
	lda Joy1New+1
	and #%00000100
	beq +

	jsr NextButton				; down pressed

+

	bra SRAMQuestionsLoop



; -------------------------- selection made
__SRAMSelectionMade:
	lda cursorY
	cmp #$88				; if at "Save to previous file", do just that :-)
	beq __AutoSaveSRAM

	cmp #$A0				; if at "Select a file", go to SRAM browser
	beq __SelectSRAMFile

	jmp __SRAMSavedOrCancelled		; otherwise, discard SRAM

__SelectSRAMFile:
	lda #%00001000				; disable color math channel
	trb DP_HDMAchannels

	jsr SpriteMessageLoading
	jsr SRAMBrowser				; load SRAM browser

	lda SelectionFlags			; back from browser, check if SRM file was picked or not
	and #%00000001
	bne __SRAMFilePicked

	jmp BattUsedInitSaveSRAM		; no SRM file picked --> go back to questions

__AutoSaveSRAM:
	lda saveName.sCluster			; if cluster=0, no file loaded previously ...
	bne __SRAMFilePicked

	lda saveName.sCluster+1
	bne __SRAMFilePicked

	lda saveName.sCluster+2
	bne __SRAMFilePicked

	lda saveName.sCluster+3
	bne __SRAMFilePicked

	jmp SRAMQuestionsLoop			; ... so go back to questions loop

__SRAMFilePicked:
	jsr PrintClearScreen

	DrawFrame 0, 15, 31, 5			; draw a smaller frame for success message

	lda #124				; patch HDMA table in WRAM with scanline values matching the message "window" border
	sta HDMAtable.ColorMath+0

	lda #38
	sta HDMAtable.ColorMath+3

	lda #%00001000				; enable color math channel
	tsb DP_HDMAchannels

	jsr SaveSRAMFile

	WaitForUserInput

__SRAMSavedOrCancelled:				; if cursor was at "Cancel" (cursorY=$A8), go back to intro as well
	lda #$0F

-	wai					; screen fade-out loop

	dec a					; 15 / 3 = 5 frames
	dec a
	dec a
	sta $2100
	bne -

	lda #%00000001				; no more battery flag
	sta CONFIGWRITESTATUS

	HideCursorSprite

	lda #%00001000				; disable color math channel
	trb DP_HDMAchannels

 	lda #52					; reset scanline values in WRAM HDMA table to the SPC player "window" border
	sta HDMAtable.ColorMath+0

	lda #126
	sta HDMAtable.ColorMath+3

	jsr PrintClearScreen
rts



; ************************** SRAM navigation ***************************

NextButton:					; $88 -> $A0 -> $A8
	lda cursorY
	clc
	adc #$08
	sta cursorY
	cmp #$B0
	bne __NextButtonDone

	lda #$88
	sta cursorY
	bra __NextButtonDone2

__NextButtonDone:
	lda cursorY
	cmp #$90
	bne __NextButtonDone2
	lda #$A0
	sta cursorY

__NextButtonDone2:

rts



PrevButton:					; $A8 -> $A0 -> $88
	lda cursorY
	sec
	sbc #$08
	sta cursorY
	cmp #$80
	bne __PrevButtonDone

	lda #$A8
	sta cursorY
	bra __PrevButtonDone2

__PrevButtonDone:
	lda cursorY
	cmp #$98
	bne __PrevButtonDone2
	lda #$88
	sta cursorY

__PrevButtonDone2:

rts



; ************************** SRAM filebrowser **************************

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



SRAMBrowser:
	FindFile "SAVES.   "

	lda #$01				; number of file types to look for (1, SRM only)
	sta extNum
	stz extNum+1

	lda #'S'
	sta extMatch1

	lda #'R'
	sta extMatch2

	lda #'M'
	sta extMatch3

	jsr __InitFileBrowserOtherDir		; go to filebrowser, start in "SAVES" folder

	stz Joy1New				; reset input buttons
	stz Joy1New+1
	stz Joy1Press
	stz Joy1Press+1



SRAMBrowserLoop:
	wai

	DpadUpHold2Scroll
	DpadDownHold2Scroll
	DpadLeftScrollUp
	DpadRightScrollDown



; -------------------------- check for left shoulder button = page up
	lda Joy1New
	and #%00100000
	beq +

	jsr PageUp

+



; -------------------------- check for right shoulder button = page down
	lda Joy1New
	and #%00010000
	beq +

	jsr PageDown

+



; -------------------------- check for A button = select file / load dir
	lda Joy1New
	and #%10000000
	beq ++

	lda #%00000011				; use SDRAM buffer, skip hidden files in next dir
	sta CLDConfigFlags

	jsr DirGetEntry				; get selected entry

	lda tempEntry.tempFlags			; check for "dir" flag
	and #$01
	bne +

	jmp __SRAMFileSelected

+	jsr NextDir

++



; -------------------------- check for B button = go up one directory / return to where we were
	lda Joy1New+1
	and #%10000000
	beq ++

	rep #A_8BIT				; A = 16 bit

	lda sourceCluster			; check if current dir = root dir ...
	cmp rootDirCluster
	bne +

	lda sourceCluster+2
	cmp rootDirCluster+2
	bne +

	sep #A_8BIT				; ... if so, A = 8 bit ...

	stz SelectionFlags			; ... and return (no SRM file selected)
rts

.ACCU 16

+	lda #$0001				; otherwise, load entry $0001, which is always "/.." (except for when in root dir)
	sta selectedEntry

	sep #A_8BIT				; A = 8 bit

	lda #%00000011				; use SDRAM buffer, skip hidden files in next dir
	sta CLDConfigFlags

	jsr DirGetEntry
	jsr NextDir

++

	jmp SRAMBrowserLoop			; end of loop



; -------------------------- SRAM file selected
__SRAMFileSelected:
	lda #%00000001				; SRM file selected
	sta SelectionFlags

	rep #A_8BIT				; A = 16 bit

	ldy #$0000

-	lda tempEntry, y			; copy SRM file name + cluster
	sta saveName, y
	iny
	iny
	cpy #$0080				; 128 bytes
	bne -

	sep #A_8BIT				; A = 8 bit
rts



; ***************************** SRAM saver *****************************

SaveSRAMFile:
	jsr SpriteInit				; purge OAM to suppress sprite artifacts

	rep #A_8BIT				; A = 16 bit

	lda saveName.sCluster			; copy save cluster to source cluster
	sta sourceCluster

	lda saveName.sCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI
	lda #$F8
	sta DMAWRITEBANK

	SetCursorPos 15, 0
	PrintString "Saving SRAM file to CF card ..."

	wai					; make sure the message appears on the screen

	lda #kSourceSDRAM
	sta sourceType

	jsr CardWriteFile

	SetCursorPos 15, 0
	PrintString "SRAM file saved successfully!  "	; don't remove trailing spaces

	SetCursorPos 16, 0
	PrintString "Press any button to return to the titlescreen."
rts



; ******************************** EOF *********************************
