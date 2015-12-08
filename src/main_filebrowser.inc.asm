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



.ACCU 8
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
	stz DP_SelectionFlags			; clear all selection-related flags

	lda #%00000011				; use SDRAM buffer, skip hidden files
	sta CLDConfigFlags

	jsr CardLoadDir				; load content of directory selected via sourceCluster (32-bit)

	rep #A_8BIT				; A = 16 bit

	lda filesInDir				; check if dir contains relevant files
	beq __FileBrowserDirEmpty

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

	jmp __FileBrowserEnd

__FileBrowserContinue:
	jsr DirPrintDir

	stz Joy1New				; reset input buttons
	stz Joy1New+1
	stz Joy1Press
	stz Joy1Press+1



__FileBrowserLoop:
	wai



.IFDEF SHOWDEBUGMSGS
	SetCursorPos 22, 24
	PrintHexNum selectedEntry+1
	PrintString "-"
	PrintHexNum selectedEntry
	stz BGPrintMon

	SetCursorPos 23, 24
	PrintHexNum filesInDir+1
	PrintString "-"
	PrintHexNum filesInDir
	stz BGPrintMon
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

__FileBrowserAorStartPressed:
	lda #%00000011				; use SDRAM buffer, skip hidden files in next dir
	sta CLDConfigFlags

	jsr DirGetEntry				; get selected entry

	lda tempEntry.tempFlags			; check for "dir" flag
	and #$01
	bne +

	jmp __FileBrowserFileSelected

+	jsr NextDir

++



; -------------------------- check for B button = go up one directory / return
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

	sep #A_8BIT				; A = 8 bit

	jmp __FileBrowserEnd			; ... if so, return

+

.ACCU 16

	lda #$0001				; otherwise, load entry $0001, which is always "/.." (except for when in root dir)
	sta selectedEntry

	sep #A_8BIT				; A = 8 bit

	lda #%00000011				; use SDRAM buffer, skip hidden files in next dir
	sta CLDConfigFlags

	jsr DirGetEntry
	jsr NextDir

++



; -------------------------- check for Start button = select file / load dir
	lda Joy1New+1
	and #%00010000
	beq +

	jmp __FileBrowserAorStartPressed

+	jmp __FileBrowserLoop			; end of loop



__FileBrowserFileSelected:
	lda #%00000001				; set "file selected" flag
	sta DP_SelectionFlags



__FileBrowserEnd:

rts



; -------------------------- print directory content
DirPrintDir:
	stz selectedEntry			; reset entry index
	stz selectedEntry+1

	jsr PrintPage				; loop through entries 0 to #maxFiles or 0 to filesInDir

	lda #$0D				; horizontal cursor position (in 1-pixel steps)
	sta cursorX

	stz selectedEntry			; reset entry index
	stz selectedEntry+1
rts



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



; *********************** Load another directory ***********************

NextDir:
	rep #A_8BIT				; A = 16 bit

	lda tempEntry.tempCluster
	sta sourceCluster
	bne __NotRootDir			; check if cluster = root dir

	lda tempEntry.tempCluster+2
	bne __NextDirDone

	lda rootDirCluster			; if yes, load root dir
	sta sourceCluster

	lda rootDirCluster+2
	bra __NextDirDone

__NotRootDir:
	lda tempEntry.tempCluster+2

__NextDirDone:
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	jsr SpriteMessageLoading
	jsr CardLoadDir
	jsr DirPrintDir				; this includes PrintClearScreen / SetCursorPos 0, 0
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
	bne -

__PrintPageLoopDone:
	sep #A_8BIT				; A = 8 bit

	lda #cursorYmin				; put cursor at the top
	sta cursorY

	lda #insertStandardTop
	sta insertTop

	lda #insertStandardBottom
	sta insertBottom

	plp					; restore processor status
rts



; ******************************** EOF *********************************
