;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
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
	rep #A_8BIT				; A = 16 bit

	lda DP_SubDirCounter			; check how much subdir data needs to be pushed onto stack
	beq +					; don't push anyhing if counter = 0

	pea (cursorYmin << 8) + cursorXfilebrowser	; push initial cursor position onto stack
	pea $0000				; push initial selectedEntry (always zero)
	pei (rootDirCluster+2)			; push source cluster of root directory
	pei (rootDirCluster)

	lda DP_SubDirCounter
	cmp #$0001
	beq +					; if counter = 1, don't push any more data

	pea (cursorYmin << 8) + cursorXfilebrowser	; cursor position
	pea $0000				; selectedEntry
	pei (baseDirCluster+2)			; source cluster of "POWERPAK" directory
	pei (baseDirCluster)

+	lda sourceCluster			; back up starting cluster of current dir
	sta DP_sourceCluster_BAK

	lda sourceCluster+2
	sta DP_sourceCluster_BAK+2

	sep #A_8BIT				; A = 8 bit

	stz DP_SelectionFlags			; clear all selection-related flags

	lda #%00000011				; use SDRAM buffer, skip hidden files
	sta CLDConfigFlags

	jsr CardLoadDir				; load content of directory selected via sourceCluster (32-bit)

	rep #A_8BIT				; A = 16 bit

	lda filesInDir				; check if dir contains relevant files
	beq __FileBrowserDirEmpty

	lda #(cursorYmin << 8) + cursorXfilebrowser
	sta cursorX				; yes, put cursor at the top

	sep #A_8BIT				; A = 8 bit

	jmp __FileBrowserContinue

__FileBrowserDirEmpty:				; e.g. the edge case when no files/folders are in the root dir, and /POWERPAK is hidden
	sep #A_8BIT				; A = 8 bit

	jsr ClearSpriteText
	jsr SpriteMessageError

	SetCursorPos 21, 1
	PrintString "No relevant files/folders found!\n"
	PrintString "  Press any button to return."

	WaitForUserInput

	jmp __FileBrowserDone

__FileBrowserContinue:
	stz selectedEntry			; reset entry index
	stz selectedEntry+1

	jsr PrintPage				; loop through entries 0 to #maxFiles or 0 to filesInDir

	rep #A_8BIT				; A = 16 bit

	stz selectedEntry			; reset entry index
	stz Joy1New				; reset input buttons
	stz Joy1Press

	sep #A_8BIT				; A = 8 bit



__FileBrowserLoop:
	wai



.IFDEF SHOWDEBUGMSGS
;	SetCursorPos 22, 24
;	PrintHexNum selectedEntry+1
;	PrintString "-"
;	PrintHexNum selectedEntry
;	stz BGPrintMon

;	SetCursorPos 23, 24
;	PrintHexNum filesInDir+1
;	PrintString "-"
;	PrintHexNum filesInDir
;	stz BGPrintMon

	SetCursorPos 0, 22

	tsx
	stx temp

	PrintHexNum temp+1			; print stack pointer (initial value: $1FFF)
	PrintHexNum temp

	SetCursorPos 1, 23
	PrintHexNum DP_SubDirCounter
.ENDIF



; -------------------------- check for d-pad held up, scroll up after a short delay
	lda Joy1Press+1
	and #%00001000
	beq __FileBrowserUpCheckDone

__UpPressed:
	lda cursorYCounter
	bne __FileBrowserUpCheckDone
	lda scrollYCounter
	bne __FileBrowserUpCheckDone

	lda #$08
	sta speedScroll
	lda #$01
	sta speedCounter

	jsr ScrollUp

	lda Joy1Old+1
	and #%00001000
	bne __UpHeld

	ldx #14					; 14 frames

__UpLongDelay:
	wai

	lda Joy1+1
	and #%00001000
	beq __FileBrowserUpCheckDone
	dex
	bne __UpLongDelay

	bra __UpPressed

__UpHeld:
	ldx #2					; 2 frames

__UpShortDelay:
	wai

	lda Joy1+1
	and #%00001000
	beq __FileBrowserUpCheckDone
	dex
	bne __UpShortDelay

	bra __UpPressed

__FileBrowserUpCheckDone:



; -------------------------- check for d-pad held down, scroll down after a short delay
	lda Joy1Press+1
	and #%00000100
	beq __FileBrowserDownCheckDone

__DownPressed:
	lda cursorYCounter
	bne __FileBrowserDownCheckDone
	lda scrollYCounter
	bne __FileBrowserDownCheckDone

	lda #$08
	sta speedScroll
	lda #$01
	sta speedCounter

	jsr ScrollDown

	lda Joy1Old+1
	and #%00000100
	bne __DownHeld

	ldx #14					; 14 frames

__DownLongDelay:
	wai

	lda Joy1+1
	and #%00000100
	beq __FileBrowserDownCheckDone
	dex
	bne __DownLongDelay

	bra __DownPressed

__DownHeld:
	ldx #2					; 2 frames

__DownShortDelay:
	wai

	lda Joy1+1
	and #%00000100
	beq __FileBrowserDownCheckDone
	dex
	bne __DownShortDelay

	bra __DownPressed

__FileBrowserDownCheckDone:



; -------------------------- check for d-pad pressed left, scroll up very fast
	lda Joy1Press+1
	and #%00000010
	beq +

	lda cursorYCounter
	bne +
	lda scrollYCounter
	bne +

	lda #$08
;	lda #$04
	sta speedScroll

	lda #$01
;	lda #$02
	sta speedCounter

	jsr ScrollUp

+



; -------------------------- check for d-pad pressed right, scroll down very fast
	lda Joy1Press+1
	and #%00000001
	beq +

	lda cursorYCounter
	bne +
	lda scrollYCounter
	bne +

	lda #$08
;	lda #$04
	sta speedScroll

	lda #$01
;	lda #$02
	sta speedCounter

	jsr ScrollDown

+

/* ############## disabled broken p-b-p navigation

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

############## disabled broken p-b-p navigation */

; -------------------------- check for A button = select file / load dir
	lda Joy1New
	and #%10000000
	beq ++

__FileBrowserAorStartPressed:
	lda #%00000011				; use SDRAM buffer, skip hidden files in next dir
	sta CLDConfigFlags

	jsr DirGetEntry				; get selected entry

	lda tempEntry.tempFlags			; check for "dir" flag
	and #$01
	bne +

	jmp __FileBrowserFileSelected

+	rep #A_8BIT				; A = 16 bit

	lda DP_SubDirCounter			; check if in root dir ...
	beq __FileBrowserSkipEntryHandler

__FileBrowserEntryHandler:
	lda selectedEntry
	beq +					; ... no, don't push anything if selectedEntry = 0 (always /. when not in root dir)

	cmp #$0001				; special case: selectedEntry = 1 (always /.. when not in root dir)
	beq __FileBrowserDirLevelUp

__FileBrowserSkipEntryHandler:
	pei (cursorX)				; push current cursor position
	pei (selectedEntry)			; push selectedEntry
	pei (DP_sourceCluster_BAK+2)		; push source cluster of current directory
	pei (DP_sourceCluster_BAK)

	inc DP_SubDirCounter			; increment subdirectory counter

+	lda tempEntry.tempCluster		; copy cluster of new directory, and save backup copy
	sta sourceCluster
	sta DP_sourceCluster_BAK

	lda tempEntry.tempCluster+2
	sta sourceCluster+2
	sta DP_sourceCluster_BAK+2

	sep #A_8BIT				; A = 8 bit

	jsr SpriteMessageLoading
	jsr CardLoadDir

	lda #cursorXfilebrowser			; put cursor at the top
	sta cursorX

	lda #cursorYmin
	sta cursorY

	jmp __FileBrowserContinue

++



; -------------------------- check for B button = go up one directory / return
	lda Joy1New+1
	and #%10000000
	beq +

	rep #A_8BIT				; A = 16 bit

	lda DP_SubDirCounter			; check if in root dir ...
	bne __FileBrowserDirLevelUp

	sep #A_8BIT				; A = 8 bit

	jmp __FileBrowserDone			; ... if so, return

__FileBrowserDirLevelUp:

.ACCU 16

	pla					; load previous dir, save copy of starting cluster
	sta sourceCluster
	sta DP_sourceCluster_BAK

	pla
	sta sourceCluster+2
	sta DP_sourceCluster_BAK+2

	sep #A_8BIT				; A = 8 bit

	lda #%00000011				; use SDRAM buffer, skip hidden files
	sta CLDConfigFlags

	jsr SpriteMessageLoading
	jsr CardLoadDir

	rep #A_8BIT				; A = 16 bit

	dec DP_SubDirCounter			; decrement subdirectory counter

	lda #(cursorYmin << 8) + cursorXfilebrowser
	sta cursorX				; put cursor at the top

	pla					; selectedEntry // FIXME, do something wih these
	pla					; cursorXY

	sep #A_8BIT				; A = 8 bit

	jmp __FileBrowserContinue

+



; -------------------------- check for Start button = select file / load dir
	lda Joy1New+1
	and #%00010000
	beq +

	jmp __FileBrowserAorStartPressed

+	jmp __FileBrowserLoop			; end of loop



; -------------------------- file selected, check for SPC file
__FileBrowserFileSelected:
	rep #A_8BIT				; A = 16 bit

	lda tempEntry.tempCluster		; copy file cluster to source cluster
	sta sourceCluster

	lda tempEntry.tempCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	lda #<sectorBuffer1
	sta destLo
	lda #>sectorBuffer1
	sta destHi				; put first sector into sector RAM
	stz destBank

	stz sectorCounter
	stz bankCounter

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

	lda #kDestWRAM
	sta destType

	jsr CardReadSector			; sector -> WRAM

	ldy #$0000
	
	lda sectorBuffer1, y			; check for ASCII string "SNES-SPC700"
	cmp #'S'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'N'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'E'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'S'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'-'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'S'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'P'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'C'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'7'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'0'
	bne +

	iny

	lda sectorBuffer1, y
	cmp #'0'
	bne +

	jmp GotoSPCplayer			; SPC file detected, load player (from a user perspective, we aren't leaving the file browser anyway)

+	lda #%00000001				; file is not SPC, set "file selected" flag
	sta DP_SelectionFlags

__FileBrowserDone:
	rep #A_8BIT				; A = 16 bit

	lda DP_SubDirCounter
	beq +					; don't pull anything if in root dir

	tax

-	pla					; clean up the stack
	pla
	pla
	pla

	dex					; bytes to pull = DP_SubDirCounter * 8
	bne -

+	sep #A_8BIT				; A = 8 bit
rts



; ********************** Print directory content ***********************

DirPrintEntry:
	lda #%00000001				; use SDRAM buffer
	sta CLDConfigFlags

	jsr DirGetEntry

	stz tempEntry+56			; NUL-terminate entry string after 56 characters

	ldy #PTR_tempEntry

	lda tempEntry.tempFlags			; if "dir" flag is set, then print a slash in front of entry name
	and #%00000001
	beq __PrintFileOnly

	PrintString " /%s\n"
	bra __DirPrintEntryDone

__PrintFileOnly:
	PrintString "  %s\n"

__DirPrintEntryDone:

	stz CLDConfigFlags			; reset CLDConfigFlags
rts



; ********************** Page-by-page navigation ***********************

PageDown:
	rep #A_8BIT				; A = 16 bit

	lda filesInDir				; if filesInDir <= maxFiles (i.e., there's only one "page"),
	cmp #maxFiles+1
	bcc __PgDnDone				; then do nothing at all

	sec
	sbc #maxFiles
	sta temp+2				; save filesInDir - maxFiles to temp var
	cmp selectedEntry			; check if selectedEntry is within the last "page"
	bcc __PgDnNextPage			; if so, show "last" page

	jsr SyncPage				; otherwise, make selectedEntry = entry no. of file at top of screen

.ACCU 16

	lda selectedEntry
	clc
	adc #maxFiles				; add maxFiles for "next page"
	bcs __PgDnOverflow			; carry set means new selectedEntry > $FFFF

	cmp temp+2				; check if new selectedEntry > filesInDir - maxFiles
	bcc __PgDnNextPage

__PgDnOverflow:
	lda temp+2				; overflow, set selectedEntry = filesInDir - maxFiles ("last" page)

__PgDnNextPage:
	sta selectedEntry

	pha					; push selectedEntry (16 bit) onto stack

	jsr PrintPage				; new parameters set, print next page

.ACCU 16

	pla					; pull selectedEntry (16 bit) from stack
	sta selectedEntry

__PgDnDone:

	sep #A_8BIT				; A = 8 bit
rts



PageUp:
	rep #A_8BIT				; A = 16 bit

	lda filesInDir				; if filesInDir <= maxFiles (i.e., there's only one "page"),
	cmp #maxFiles+1
	bcc __PgUpDone				; then do nothing at all

	jsr SyncPage				; make selectedEntry = entry no. of file at top of screen

.ACCU 16

	lda selectedEntry
	sec
	sbc #maxFiles				; subtract maxFiles for "previous page"
	bcs __PgUpNextPage			; carry set means no borrow required, continue

__PgUpUnderflow:				; carry clear --> underflow, selectedEntry < $0000
	lda #$0000				; set selectedEntry = $0000 for "first" page

__PgUpNextPage:
	sta selectedEntry

	pha					; push selectedEntry (16 bit) onto stack

	jsr PrintPage				; new parameters set, print previous page

.ACCU 16

	pla					; pull selectedEntry (16 bit) from stack
	sta selectedEntry

__PgUpDone:

	sep #A_8BIT				; A = 8 bit
rts



SyncPage:
	php

	sep #A_8BIT				; A = 8 bit

	lda cursorY
	sec
	sbc #cursorYmin				; subtract indention
	lsr a
	lsr a					; divide by 8 to get the difference between selectedEntry
	lsr a					; and entry no. of the file at the top of the screen
	sta temp

	stz temp+1

	rep #A_8BIT				; A = 16 bit

	lda selectedEntry
	sec					; subtract difference so that selectedEntry now corresponds
	sbc temp				; to the file at the top of the screen
	bcs +					; carry set means no borrow, continue
	lda #$0000				; carry clear --> underflow, selectedEntry < $0000, reset selectedEntry

+	sta selectedEntry

	plp					; restore processor status
rts



PrintPage:
	php

	sep #A_8BIT				; A = 8 bit

	stz temp				; reset file counter

	jsr PrintClearScreen

	SetCursorPos 0, 0

-	inc temp				; increment file counter

	jsr DirPrintEntry

	rep #A_8BIT				; A = 16 bit

	inc selectedEntry			; increment entry index

	lda selectedEntry
	cmp filesInDir				; check if last file reached, jump out
	beq __PrintPageLoopDone

	sep #A_8BIT				; A = 8 bit

	lda temp				; check if printY max reached, jump out
	cmp #maxFiles
	bcc -

__PrintPageLoopDone:
	sep #A_8BIT				; A = 8 bit

	lda #insertStandardTop			; standard values for scrolling
	sta insertTop

	lda #insertStandardBottom
	sta insertBottom

	plp					; restore processor status
rts



; ******************************** EOF *********************************
