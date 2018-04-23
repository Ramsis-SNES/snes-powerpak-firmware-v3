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
	sta	CLDConfigFlags
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



__FileBrowserLoop:
	wai

.IFDEF SHOWDEBUGMSGS
	SetCursorPos 22, 24
	PrintHexNum selectedEntry+1
	PrintString "-"
	PrintHexNum selectedEntry

	stz	BGPrintMon

	SetCursorPos 23, 24
	PrintHexNum filesInDir+1
	PrintString "-"
	PrintHexNum filesInDir

	stz	BGPrintMon

;	SetCursorPos 0, 22

;	tsx
;	stx	temp

;	PrintHexNum temp+1						; print stack pointer (initial value: $1FFF)
;	PrintHexNum temp
;	SetCursorPos 1, 23
;	PrintHexNum DP_SubDirCounter
.ENDIF



; -------------------------- check for d-pad held up, scroll up after a short delay
	lda	Joy1Press+1
	and	#%00001000
	beq	__FileBrowserUpCheckDone

__UpPressed:
	lda	cursorYCounter
	bne	__FileBrowserUpCheckDone
	lda	scrollYCounter
	bne	__FileBrowserUpCheckDone
	lda	#$08
	sta	speedScroll
	lda	#$01
	sta	speedCounter
	jsr	ScrollUp
	lda	Joy1Old+1
	and	#%00001000
	bne	__UpHeld
	ldx	#14							; 14 frames

__UpLongDelay:
	wai
	lda	Joy1+1
	and	#%00001000
	beq	__FileBrowserUpCheckDone
	dex
	bne	__UpLongDelay

	bra	__UpPressed

__UpHeld:
	ldx	#2							; 2 frames

__UpShortDelay:
	wai
	lda	Joy1+1
	and	#%00001000
	beq	__FileBrowserUpCheckDone
	dex
	bne	__UpShortDelay

	bra	__UpPressed

__FileBrowserUpCheckDone:



; -------------------------- check for d-pad held down, scroll down after a short delay
	lda	Joy1Press+1
	and	#%00000100
	beq	__FileBrowserDownCheckDone

__DownPressed:
	lda	cursorYCounter
	bne	__FileBrowserDownCheckDone
	lda	scrollYCounter
	bne	__FileBrowserDownCheckDone
	lda	#$08
	sta	speedScroll
	lda	#$01
	sta	speedCounter
	jsr	ScrollDown
	lda	Joy1Old+1
	and	#%00000100
	bne	__DownHeld
	ldx	#14							; 14 frames

__DownLongDelay:
	wai
	lda	Joy1+1
	and	#%00000100
	beq	__FileBrowserDownCheckDone
	dex
	bne	__DownLongDelay

	bra	__DownPressed

__DownHeld:
	ldx	#2							; 2 frames

__DownShortDelay:
	wai
	lda	Joy1+1
	and	#%00000100
	beq	__FileBrowserDownCheckDone
	dex
	bne	__DownShortDelay

	bra	__DownPressed

__FileBrowserDownCheckDone:



; -------------------------- check for d-pad pressed left, scroll up very fast
	lda	Joy1Press+1
	and	#%00000010
	beq	__FileBrowserLeftCheckDone
	lda	cursorYCounter
	bne	__FileBrowserLeftCheckDone
	lda	scrollYCounter
	bne	__FileBrowserLeftCheckDone
	lda	#$08
;	lda	#$04
	sta	speedScroll
	lda	#$01
;	lda	#$02
	sta	speedCounter
	jsr	ScrollUp

__FileBrowserLeftCheckDone:



; -------------------------- check for d-pad pressed right, scroll down very fast
	lda	Joy1Press+1
	and	#%00000001
	beq	__FileBrowserRightCheckDone
	lda	cursorYCounter
	bne	__FileBrowserRightCheckDone
	lda	scrollYCounter
	bne	__FileBrowserRightCheckDone
	lda	#$08
;	lda	#$04
	sta	speedScroll
	lda	#$01
;	lda	#$02
	sta	speedCounter
	jsr	ScrollDown

__FileBrowserRightCheckDone:



; -------------------------- check for left shoulder button = page up
	lda	Joy1New
	and	#%00100000
	beq	__FileBrowserLCheckDone

	Accu16

	lda	filesInDir						; if filesInDir <= maxFiles (i.e., there's only one "page"),
	cmp	#maxFiles+1
	bcc	__PgUpDone						; then do nothing at all
	pei	(selectedEntry)						; preserve selectedEntry (16 bit)
	jsr	SyncPage						; make selectedEntry = entry no. of file at top of screen
	jsr	SelEntryDecPage
	jsr	PrintPage						; new parameters set, print previous page
	pla								; restore selectedEntry (16 bit)
	sta	selectedEntry
	jsr	SelEntryDecPage

__PgUpDone:
	Accu8

__FileBrowserLCheckDone:



; -------------------------- check for right shoulder button = page down
	lda	Joy1New
	and	#%00010000
	beq	__FileBrowserRCheckDone

	Accu16

	lda	filesInDir						; if filesInDir <= maxFiles (i.e., there's only one "page"),
	cmp	#maxFiles+1
	bcc	__PgDnDone						; then do nothing at all
	pei	(selectedEntry)						; preserve selectedEntry (16 bit)
	jsr	SyncPage						; make selectedEntry = entry no. of file at top of screen
	jsr	SelEntryIncPage
	jsr	PrintPage						; new parameters set, print next page
	pla								; restore selectedEntry (16 bit)
	sta	selectedEntry
	jsr	SelEntryIncPage

__PgDnDone:
	Accu8

__FileBrowserRCheckDone:



; -------------------------- check for A button = select file / load dir
	lda	Joy1New
	and	#%10000000
	beq	__FileBrowserACheckDone

__FileBrowserAorStartPressed:
	lda	#%00000011						; use SDRAM buffer, skip hidden files in next dir
	sta	CLDConfigFlags
	jsr	DirGetEntry						; get selected entry
	lda	tempEntry.Flags						; check for "dir" flag
	and	#$01
	bne	+
	jmp	__FileBrowserFileSelected

+	Accu16

	lda	DP_SubDirCounter					; check if in root dir ...
	beq	__FileBrowserSkipEntryHandler

__FileBrowserEntryHandler:
	lda	selectedEntry
	beq	+							; ... no, don't push anything if selectedEntry = 0 (always /. when not in root dir)
	cmp	#$0001							; special case: selectedEntry = 1 (always /.. when not in root dir)
	beq	__FileBrowserDirLevelUp

__FileBrowserSkipEntryHandler:
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

__FileBrowserACheckDone:



; -------------------------- check for B button = go up one directory / return
	lda	Joy1New+1
	and	#%10000000
	beq	__FileBrowserBCheckDone

	Accu16

	lda	DP_SubDirCounter					; check if in root dir ...
	bne	__FileBrowserDirLevelUp

	Accu8

	jmp	__FileBrowserDone					; ... if so, return

__FileBrowserDirLevelUp:

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

__FileBrowserBCheckDone:



; -------------------------- check for Start button = select file / load dir
	lda	Joy1New+1
	and	#%00010000
	beq	__FileBrowserStartCheckDone
	jmp	__FileBrowserAorStartPressed

__FileBrowserStartCheckDone:

	jmp	__FileBrowserLoop					; end of loop



; -------------------------- file selected, check for SPC file / end file browser
__FileBrowserFileSelected:
	ldx	#0
	jmp	FileBrowserCheckSPCFile

__FileBrowserFileIsNotSPC:
	lda	#%00000001						; back here means file is not SPC, set "file selected" flag
	sta	DP_SelectionFlags

__FileBrowserDone:
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

	SetCursorPos 21, 1
	PrintString "No files/folders to display!\n"
	PrintString "  Press any button to return."

	WaitForUserInput

	bra	__FileBrowserDone



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

	lda	#kDestWRAM
	sta	destType
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
	jmp	(FileBrowserFileIsSPCTable, x)

+	jmp	(FileBrowserFileIsNotSPCTable, x)



FileBrowserFileIsSPCTable:
	.DW	GotoSPCplayer						; order of entries in both tables: 1. normal file browser,
	.DW	__InitWarmBoot						; 2. next SPC file,
	.DW	__InitWarmBoot						; 3. previous SPC file



FileBrowserFileIsNotSPCTable:
	.DW	__FileBrowserFileIsNotSPC
	.DW	__SPCLoopCheckNextFile
	.DW	__SPCLoopCheckPrevFile



PrintPage:
	php

	Accu16

	pei	(selectedEntry)						; preserve selectedEntry (16 bit)

	Accu8

	stz	temp							; reset file counter
	jsr	PrintClearScreen

	SetCursorPos 0, 0

-	inc	temp							; increment file counter
	jsr	DirPrintEntry

	Accu16

	inc	selectedEntry						; increment entry index
	lda	selectedEntry
	cmp	filesInDir						; check if last file reached
	bcc	+
	lda	filesInDir						; yes, check if dir contains less files than can be put on the screen
	cmp	#maxFiles+1
	bcc	__PrintPageLoopDone
	stz	selectedEntry						; there are more files, reset selectedEntry so that it "wraps around" 

+	Accu8

	lda	temp							; check if printY max reached
	cmp	#maxFiles
	bcc	-

__PrintPageLoopDone:
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
	beq	__PrintFileOnly

	PrintString " /%s\n"
	bra	__DirPrintEntryDone

__PrintFileOnly:
	PrintString "  %s\n"

__DirPrintEntryDone:
	stz	CLDConfigFlags						; reset CLDConfigFlags
	rts



ScrollDown:
	Accu16

	inc	selectedEntry						; increment entry index
	lda	selectedEntry						; check if selectedEntry >= filesInDir
	cmp	filesInDir
	bcc	__ScrollDownCheckBottom
	stz	selectedEntry						; yes, overflow --> reset selectedEntry
	lda	filesInDir						; check if filesInDir > maxFiles
	cmp	#maxFiles+1
	bcs	__ScrollDownCheckBottom

	Accu8

	lda	#cursorYmin-$08						; put cursor at top of screen
	sta	cursorY							; (subtraction necessary because it "scrolls in" from one line above)
	bra	__ScrollDownCheckMiddle

__ScrollDownCheckBottom:
	Accu8

	lda	cursorY
	cmp	#cursorYmax						; check if cursor at bottom
	bne	__ScrollDownCheckMiddle
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
	sta	Cursor
	lda	temp
	lsr	a
	lsr	a
	lsr	a
	sta	Cursor+1
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
	bra	__ScrollDownDone

__ScrollDownCheckMiddle:
	lda	speedCounter
	sta	cursorYCounter
	lda	speedScroll
	sta	cursorYDown
	stz	cursorYUp

__ScrollDownDone:
	rts



ScrollUp:
	Accu16

	dec	selectedEntry						; decrement entry index
	lda	selectedEntry
	cmp	#$FFFF							; check for underflow
	bne	__ScrollUpCheckTop
	lda	filesInDir						; underflow, set selectedEntry = filesInDir - 1
	dec	a
	sta	selectedEntry
	lda	filesInDir						; check if filesInDir > maxFiles, which the cursor is restricted to, too
	cmp	#maxFiles+1						; reminder: "+1" needed due to the way CMP affects the carry bit
	bcs	__ScrollUpCheckTop

	Accu8

	lda	filesInDir
	asl	a
	asl	a
	asl	a							; multiply by 8 for sprite height
	clc
	adc	#cursorYmin						; add Y indention
	sta	cursorY							; put cursor at bottom of list
	bra	__ScrollUpCheckMiddle

__ScrollUpCheckTop:
	Accu8

	lda	cursorY
	cmp	#cursorYmin						; check if cursor at top
	bne	__ScrollUpCheckMiddle
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
	sta	Cursor
	lda	temp
	lsr	a
	lsr	a
	lsr	a
	sta	Cursor+1
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
	bra	__ScrollUpDone

__ScrollUpCheckMiddle:
	lda	speedCounter
	sta	cursorYCounter
	lda	speedScroll
	sta	cursorYUp
	stz	cursorYDown

__ScrollUpDone:
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
