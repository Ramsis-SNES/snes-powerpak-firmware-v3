;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: FILE BROWSER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.INDEX 16

; **************************** File browser ****************************

; This routine loads a directory and prints its content to the screen so
; the user can choose a file. The name of the selected file + its 32-bit
; cluster are copied to the tempEntry variable for further use. The code
; section calling this routine must handle the case when no file is sel-
; ected at all on its own.
;
; The routine expects sourceCluster/extNum/extMatchX variables to con-
; tain meaningful values.

FileBrowser:
	Accu16

	lda	DP_SubDirCounter					; check how much subdir data needs to be pushed onto stack
	beq	+							; don't push anyhing if counter = 0
	pea	(cursorYmin << 8) + cursorXfilebrowser			; push initial cursor position onto stack
	pea	$0000							; push initial selectedEntry (always zero)
	pei	(rootDirCluster+2)					; push source cluster of root directory
	pei	(rootDirCluster)
	lda	DP_SubDirCounter
	cmp	#$0001
	beq	+							; if counter = 1, don't push any more data
	pea	(cursorYmin << 8) + cursorXfilebrowser			; cursor position
	pea	$0000							; selectedEntry
	pei	(baseDirCluster+2)					; source cluster of "POWERPAK" directory
	pei	(baseDirCluster)
+	lda	sourceCluster						; back up starting cluster of current dir
	sta	DP_sourceCluster_BAK
	lda	sourceCluster+2
	sta	DP_sourceCluster_BAK+2

	Accu8

	stz	DP_SelectionFlags					; clear all selection-related flags
	lda	#%00000011						; use SDRAM buffer, skip hidden files
	sta	CLDConfigFlags						; acknowledge flags set before this routine was called
	jsr	CardLoadDir						; load content of directory selected via sourceCluster (32-bit)
	jsr	FileBrowserCheckDirEmpty

.ACCU 16

	stz	selectedEntry						; reset entry index
	jsr	PrintPage

	lda	#(cursorYmin << 8) + cursorXfilebrowser
	sta	cursorX							; initial cursor position
	stz	Joy1New							; reset input buttons
	stz	Joy1Press

	Accu8



FileBrowserLoop:
	wai

.IFDEF SHOWDEBUGMSGS
	SetTextPos 22, 24
	PrintHexNum selectedEntry+1
	PrintString "-"
	PrintHexNum selectedEntry

	stz	BGPrintMon

	SetTextPos 23, 24
	PrintHexNum filesInDir+1
	PrintString "-"
	PrintHexNum filesInDir

	stz	BGPrintMon

;	SetTextPos 0, 22

;	tsx
;	stx	temp

;	PrintHexNum temp+1						; print stack pointer (initial value: $1FFF)
;	PrintHexNum temp
;	SetTextPos 1, 23
;	PrintHexNum DP_SubDirCounter
.ENDIF



; -------------------------- check for d-pad held up, scroll up after a short delay
	lda	Joy1Press+1
	and	#%00001000
	beq	@DpadUpDone

@UpPressed:
	lda	cursorYCounter
	bne	@DpadUpDone
	lda	scrollYCounter
	bne	@DpadUpDone
	lda	#$08
	sta	speedScroll
	lda	#$01
	sta	speedCounter
	jsr	ScrollUp

	lda	Joy1Old+1
	and	#%00001000
	bne	@UpHeld
	ldx	#14							; 14 frames

@UpLongDelay:
	wai
	lda	Joy1+1
	and	#%00001000
	beq	@DpadUpDone
	dex
	bne	@UpLongDelay

	bra	@UpPressed

@UpHeld:
	ldx	#2							; 2 frames

@UpShortDelay:
	wai
	lda	Joy1+1
	and	#%00001000
	beq	@DpadUpDone
	dex
	bne	@UpShortDelay

	bra	@UpPressed

@DpadUpDone:



; -------------------------- check for d-pad held down, scroll down after a short delay
	lda	Joy1Press+1
	and	#%00000100
	beq	@DpadDownDone

@DownPressed:
	lda	cursorYCounter
	bne	@DpadDownDone
	lda	scrollYCounter
	bne	@DpadDownDone
	lda	#$08
	sta	speedScroll
	lda	#$01
	sta	speedCounter
	jsr	ScrollDown

	lda	Joy1Old+1
	and	#%00000100
	bne	@DownHeld
	ldx	#14							; 14 frames

@DownLongDelay:
	wai
	lda	Joy1+1
	and	#%00000100
	beq	@DpadDownDone
	dex
	bne	@DownLongDelay

	bra	@DownPressed

@DownHeld:
	ldx	#2							; 2 frames

@DownShortDelay:
	wai
	lda	Joy1+1
	and	#%00000100
	beq	@DpadDownDone
	dex
	bne	@DownShortDelay

	bra	@DownPressed

@DpadDownDone:



; -------------------------- check for d-pad pressed left, scroll up very fast
	lda	Joy1Press+1
	and	#%00000010
	beq	@DpadLeftDone
	lda	cursorYCounter
	bne	@DpadLeftDone
	lda	scrollYCounter
	bne	@DpadLeftDone
	lda	#$08
;	lda	#$04
	sta	speedScroll
	lda	#$01
;	lda	#$02
	sta	speedCounter
	jsr	ScrollUp

@DpadLeftDone:



; -------------------------- check for d-pad pressed right, scroll down very fast
	lda	Joy1Press+1
	and	#%00000001
	beq	@DpadRightDone
	lda	cursorYCounter
	bne	@DpadRightDone
	lda	scrollYCounter
	bne	@DpadRightDone
	lda	#$08
;	lda	#$04
	sta	speedScroll
	lda	#$01
;	lda	#$02
	sta	speedCounter
	jsr	ScrollDown

@DpadRightDone:



; -------------------------- check for left shoulder button = page up
	lda	Joy1New
	and	#%00100000
	beq	@LButtonDone

	Accu16

	lda	#maxFiles						; if filesInDir <= maxFiles (i.e., there's only one "page"),
	cmp	filesInDir
	bcs	@PgUpDone						; then do nothing at all
	pei	(selectedEntry)						; preserve selectedEntry (16 bit)
	jsr	SyncPage						; make selectedEntry = entry no. of file at top of screen
	jsr	SelEntryDecPage
	jsr	PrintPage						; new parameters set, print previous page

	pla								; restore selectedEntry (16 bit)
	sta	selectedEntry
	jsr	SelEntryDecPage

@PgUpDone:
	Accu8

@LButtonDone:



; -------------------------- check for right shoulder button = page down
	lda	Joy1New
	and	#%00010000
	beq	@RButtonDone

	Accu16

	lda	#maxFiles						; if filesInDir <= maxFiles (i.e., there's only one "page"),
	cmp	filesInDir
	bcs	@PgDnDone						; then do nothing at all
	pei	(selectedEntry)						; preserve selectedEntry (16 bit)
	jsr	SyncPage						; make selectedEntry = entry no. of file at top of screen
	jsr	SelEntryIncPage
	jsr	PrintPage						; new parameters set, print next page

	pla								; restore selectedEntry (16 bit)
	sta	selectedEntry
	jsr	SelEntryIncPage

@PgDnDone:
	Accu8

@RButtonDone:



; -------------------------- check for A button = select file / load dir
	lda	Joy1New
	bpl	@AButtonDone

@AorStartPressed:
	lda	#%00000011						; use SDRAM buffer, skip hidden files in next dir
	sta	CLDConfigFlags
	jsr	DirGetEntry						; get selected entry

	lda	tempEntry.Flags						; check for "dir" flag
	and	#$01
	bne	+
	jmp	FileSelectedOrDirEmpty

+	Accu16

	lda	DP_SubDirCounter					; check if in root dir ...
	beq	@SkipEntryHandler

@EntryHandler:
	lda	selectedEntry
	beq	+							; ... no, don't push anything if selectedEntry = 0 (always /. when not in root dir)
	cmp	#$0001							; special case: selectedEntry = 1 (always /.. when not in root dir)
	beq	FileBrowserLoop@DirLevelUp

@SkipEntryHandler:
	pei	(cursorX)						; push current cursor position
	pei	(selectedEntry)						; push selectedEntry
	pei	(DP_sourceCluster_BAK+2)				; push source cluster of current directory
	pei	(DP_sourceCluster_BAK)
	inc	DP_SubDirCounter					; increment subdirectory counter
+	lda	tempEntry.Cluster					; copy cluster of new directory, and save backup copy
	sta	sourceCluster
	sta	DP_sourceCluster_BAK
	lda	tempEntry.Cluster+2
	sta	sourceCluster+2
	sta	DP_sourceCluster_BAK+2

	Accu8

	jsr	SpriteMessageLoading
	jsr	CardLoadDir						; CLDConfigFlags already set above
;	jsr	FileBrowserCheckDirEmpty				; don't bother, subdirectories are never empty (they always contain /. and /.. entries)

	Accu16

	stz	selectedEntry						; reset entry index
	jsr	PrintPage

	lda	#(cursorYmin << 8) + cursorXfilebrowser
	sta	cursorX							; initial cursor position

	Accu8

@AButtonDone:



; -------------------------- check for B button = go up one directory / return
	lda	Joy1New+1
	bpl	@BButtonDone

	Accu16

	lda	DP_SubDirCounter					; check if in root dir ...
	bne	@DirLevelUp

	Accu8

	jmp	FileSelectedOrDirEmpty@Done				; ... if so, return

@DirLevelUp:

.ACCU 16

	pla								; load previous dir, save copy of starting cluster
	sta	sourceCluster
	sta	DP_sourceCluster_BAK
	pla
	sta	sourceCluster+2
	sta	DP_sourceCluster_BAK+2

	Accu8

	lda	#%00000011						; use SDRAM buffer, skip hidden files
	sta	CLDConfigFlags
	jsr	SpriteMessageLoading
	jsr	CardLoadDir

	Accu16

	dec	DP_SubDirCounter					; decrement subdirectory counter
	pla								; restore previous selectedEntry
	sta	selectedEntry
	pla								; restore previous cursor position
	sta	DP_cursorX_BAK

	Accu8

	jsr	FileBrowserCheckDirEmpty				; reminder: only do this here in order not to end up with a corrupted stack

	Accu16

	pei	(selectedEntry)						; preserve previous selectedEntry as current selectedEntry

	Accu8

	lda	DP_cursorY_BAK						; the following code snippet does essentially the same as SyncPage, but with the backed-up cursor position (we don't want the cursor to appear on the screen yet)
	sec
	sbc	#cursorYmin						; subtract indention
	lsr	a
	lsr	a							; divide by 8 to get the difference between selectedEntry
	lsr	a							; and entry no. of the file at the top of the screen
	sta	temp
	stz	temp+1

	Accu16

	lda	selectedEntry
	sec								; make selectedEntry = file at the top of the screen
	sbc	temp
	bcs	+							; carry set --> new selectedEntry > 0
	eor	#$FFFF							; carry clear --> underflow, selectedEntry < 0
	inc	a							; make subtraction result positive
	sta	temp
	lda	filesInDir						; subtract underflow from filesInDir
	sec
	sbc	temp
+	sta	selectedEntry
	jsr	PrintPage						; new (old) parameters set, print page

	pla								; restore selectedEntry
	sta	selectedEntry
	lda	DP_cursorX_BAK						; make cursor appear on the screen
	sta	cursorX

	Accu8

@BButtonDone:



; -------------------------- check for Start button = select file / load dir
	lda	Joy1New+1
	and	#%00010000
	beq	@StartButtonDone
	jmp	@AorStartPressed

@StartButtonDone:

	jmp	FileBrowserLoop						; end of loop



; -------------------------- file selected, check for SPC file / end file browser
FileSelectedOrDirEmpty:
	ldx	#0
	jmp	FileBrowserCheckSPCFile

@FileIsNotSPC:
	lda	#%00000001						; back here means file is not SPC, set "file selected" flag
	sta	DP_SelectionFlags

@Done:
	Accu16

	lda	DP_SubDirCounter
	beq	+							; don't pull anything if in root dir
	tax
-	pla								; clean up the stack
	pla
	pla
	pla
	dex								; bytes to pull = DP_SubDirCounter * 8
	bne	-

+	Accu8

	rts



; ********************** File browser subroutines **********************

FileBrowserCheckDirEmpty:
	Accu16

	lda	filesInDir						; check if dir contains relevant files
	beq	+
	rts								; yes, return

+	pla								; no, clean up the stack (no rts from jsr FileBrowserCheckDirEmpty)

	Accu8

	jsr	ClearSpriteText						; edge case: no files/folders in root dir, and /POWERPAK is hidden
	jsr	SpriteMessageError

	SetTextPos 21, 1
	PrintString "No files/folders to display!\n"
	PrintString "  Press any button to return."

	WaitForUserInput

	bra	FileSelectedOrDirEmpty@Done



FileBrowserCheckSPCFile:
	phx								; preserve jump table value in X

	Accu16

	lda	tempEntry.Cluster					; copy file cluster to source cluster
	sta	sourceCluster
	lda	tempEntry.Cluster+2
	sta	sourceCluster+2

	Accu8

	ldx	#sectorBuffer1						; load first sector into sector RAM
	stx	destLo
	stz	destBank
	stz	sectorCounter
	stz	bankCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector

	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector						; sector -> WRAM

	plx								; restore jump table value
	ldy	#$0000
	lda	sectorBuffer1, y					; check for ASCII string "SNES-SPC700"
	cmp	#'S'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'N'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'E'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'S'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'-'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'S'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'P'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'C'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'7'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'0'
	bne	+
	iny
	lda	sectorBuffer1, y
	cmp	#'0'
	bne	+
	jmp	(PTR_FileBrowserFileIsSPC, x)
+	jmp	(PTR_FileBrowserFileNotSPC, x)

PTR_FileBrowserFileIsSPC:
	.DW	GotoSPCplayer						; order of entries in both tables: 1. normal file browser,
	.DW	InitWarmBoot						; 2. next SPC file,
	.DW	InitWarmBoot						; 3. previous SPC file

PTR_FileBrowserFileNotSPC:
	.DW	FileSelectedOrDirEmpty@FileIsNotSPC
	.DW	SPCPlayerLoop@CheckNextFile
	.DW	SPCPlayerLoop@CheckPrevFile



PrintPage:
	php

	Accu16

	pei	(selectedEntry)						; preserve selectedEntry (16 bit)

	Accu8

	stz	temp							; reset file counter
	jsr	PrintClearScreen

	SetTextPos 0, 0

@PrintPageLoop:
	inc	temp							; increment file counter
	jsr	DirPrintEntry

	Accu16

	inc	selectedEntry						; increment entry index
	lda	selectedEntry
	cmp	filesInDir						; check if last file reached
	bcc	+
	lda	#maxFiles						; yes, check if dir contains less files than can be put on the screen
	cmp	filesInDir
	bcs	@PrintPageLoopDone
	stz	selectedEntry						; there are more files, reset selectedEntry so that it "wraps around" 

+	Accu8

	lda	temp							; check if printY max reached
	cmp	#maxFiles
	bcc	@PrintPageLoop

@PrintPageLoopDone:
	Accu16

	pla								; restore selectedEntry (16 bit)
	sta	selectedEntry

	Accu8

	lda	#insertStandardTop					; standard values for scrolling
	sta	insertTop
	lda	#insertStandardBottom
	sta	insertBottom
	plp								; restore processor status
	rts



DirPrintEntry:
	lda	#%00000001						; use SDRAM buffer
	sta	CLDConfigFlags
	jsr	DirGetEntry

	stz	tempEntry+56						; NUL-terminate entry string after 56 characters
	ldy	#PTR_tempEntry
	lda	tempEntry.Flags						; if "dir" flag is set, then print a slash in front of entry name
	and	#%00000001
	beq	@PrintFileOnly

	PrintString " /%s\n"
	bra	@DirPrintEntryDone

@PrintFileOnly:
	PrintString "  %s\n"

@DirPrintEntryDone:
	stz	CLDConfigFlags						; reset CLDConfigFlags
	rts



ScrollDown:
	Accu16

	inc	selectedEntry						; increment entry index
	lda	selectedEntry						; check if selectedEntry >= filesInDir
	cmp	filesInDir
	bcc	@CheckBottom
	stz	selectedEntry						; yes, overflow --> reset selectedEntry
	lda	#maxFiles						; check if filesInDir > maxFiles
	cmp	filesInDir
	bcc	@CheckBottom

	Accu8

	lda	#cursorYmin-$08						; put cursor at top of screen
	sta	cursorY							; (subtraction necessary because it "scrolls in" from one line above)
	bra	@CheckMiddle

@CheckBottom:
	Accu8

	lda	cursorY
	cmp	#cursorYmax						; check if cursor at bottom
	bne	@CheckMiddle
	lda	speedCounter						; cursor at bottom, move background, leave cursor
	sta	scrollYCounter						; set scrollYCounter (8 or 4)
	lda	speedScroll
	sta	scrollYDown						; set scrollYDown to speed (1 or 2)
	stz	scrollYUp
	lda	insertBottom
	sta	temp
	jsr	PrintClearLine

	lda	temp
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	ora	#minPrintX						; add horizontal indention
	sta	DP_TextPos
	lda	temp
	lsr	a
	lsr	a
	lsr	a
	sta	DP_TextPos+1
	jsr	DirPrintEntry

	lda	insertBottom
	clc
	adc	#$01
	and	#%00011111
	sta	insertBottom
	lda	insertTop
	clc
	adc	#$01
	and	#%00011111
	sta	insertTop
	bra	@ScrollDownDone

@CheckMiddle:
	lda	speedCounter
	sta	cursorYCounter
	lda	speedScroll
	sta	cursorYDown
	stz	cursorYUp

@ScrollDownDone:
	rts



ScrollUp:
	Accu16

	dec	selectedEntry						; decrement entry index
	lda	selectedEntry
	cmp	#$FFFF							; check for underflow
	bne	@CheckTop
	lda	filesInDir						; underflow, set selectedEntry = filesInDir - 1
	dec	a
	sta	selectedEntry
	lda	#maxFiles						; check if filesInDir > maxFiles, which the cursor is restricted to, too
	cmp	filesInDir
	bcc	@CheckTop

	Accu8

	lda	filesInDir
	asl	a
	asl	a
	asl	a							; multiply by 8 for sprite height
	clc
	adc	#cursorYmin						; add Y indention
	sta	cursorY							; put cursor at bottom of list
	bra	@CheckMiddle

@CheckTop:
	Accu8

	lda	cursorY
	cmp	#cursorYmin						; check if cursor at top
	bne	@CheckMiddle
	lda	speedCounter
	sta	scrollYCounter						; cursor at top, scroll background, leave cursor
	lda	speedScroll
	sta	scrollYUp
	stz	scrollYDown
	lda	insertTop
	sta	temp
	jsr	PrintClearLine

	lda	temp
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	ora	#minPrintX						; add horizontal indention
	sta	DP_TextPos
	lda	temp
	lsr	a
	lsr	a
	lsr	a
	sta	DP_TextPos+1
	jsr	DirPrintEntry

	lda	insertBottom
	sec
	sbc	#$01
	and	#%00011111
	sta	insertBottom
	lda	insertTop
	sec
	sbc	#$01
	and	#%00011111
	sta	insertTop
	bra	@ScrollUpDone

@CheckMiddle:
	lda	speedCounter
	sta	cursorYCounter
	lda	speedScroll
	sta	cursorYUp
	stz	cursorYDown

@ScrollUpDone:
	rts



.ACCU 16

SelEntryDecPage:							; decrement selectedEntry by one "page", wrap around zero if necessary
	lda	selectedEntry
	sec
	sbc	#maxFiles						; subtract maxFiles for "previous page"
	bcs	+							; carry set --> new selectedEntry >= 0
	eor	#$FFFF							; carry clear --> underflow, selectedEntry < 0
	inc	a							; make subtraction result positive
	sta	temp+4
	lda	filesInDir						; subtract underflow from filesInDir
	sec
	sbc	temp+4
+	sta	selectedEntry						; e.g. if selectedEntry was $FFFE after the first subtraction, then it is now (filesInDir-2)
	rts



SelEntryIncPage:							; increment selectedEntry by one "page", wrap around zero if necessary
	lda	selectedEntry
	clc
	adc	#maxFiles						; add maxFiles for "next page"
	cmp	filesInDir
	bcc	+							; new selectedEntry < filesInDir
;	sec								; carry set (and thus, sec intentionally commented out) --> overflow, selectedEntry >= filesInDir
	sbc	filesInDir						; subtract filesInDir
+	sta	selectedEntry						; e.g. if selectedEntry was (filesInDir+5) after the first addition, then it is now $0005)
	rts



SyncPage:
	php

	Accu8

	lda	cursorY
	sec
	sbc	#cursorYmin						; subtract indention
	lsr	a
	lsr	a							; divide by 8 to get the difference between selectedEntry
	lsr	a							; and entry no. of the file at the top of the screen
	sta	temp
	stz	temp+1

	Accu16

	lda	selectedEntry
	sec								; subtract difference so that selectedEntry now corresponds
	sbc	temp							; to the file at the top of the screen
	bcs	+							; carry set --> new selectedEntry > 0
	eor	#$FFFF							; carry clear --> underflow, selectedEntry < 0
	inc	a							; make subtraction result positive
	sta	temp
	lda	filesInDir						; subtract underflow from filesInDir
	sec
	sbc	temp
+	sta	selectedEntry
	plp								; restore processor status
	rts



; ******************************** EOF *********************************
