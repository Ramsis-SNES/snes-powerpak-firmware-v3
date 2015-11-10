;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** MAIN CODE SECTION: ROM BROWSER & LOADER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



; ************************ ROM/SPC filebrowser *************************

; File extensions to look for, mapped to search variables:
;
;           |     | +1  | +2  | +3  | +4  | +5  | +6  | +7  | +8  | +9  | +10 |
; ------------------------------------------------------------------------------
; extMatch1 |  S  |  S  |  S  |  G  |  S  |  B  |  F  |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch2 |  M  |  W  |  F  |  D  |  P  |  I  |  I  |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch3 |  C  |  C  |  C  |  3  |  C  |  N  |  G  |     |     |     |     |
; ------------------------------------------------------------------------------
;
; When adding one or more extensions, don't forget to increase the value
; of variable "extNum" a few lines below!



GotoROMBrowser:
	lda #$07				; number of file types to look for (7, see table above)
	sta extNum
	stz extNum+1

	lda #'S'				; using the least possible amount of lda/sta commands
	sta extMatch1
	sta extMatch1+1
	sta extMatch1+2
	sta extMatch1+4

	lda #'M'
	sta extMatch2

	lda #'W'
	sta extMatch2+1

	lda #'F'
	sta extMatch1+6
	sta extMatch2+2

	lda #'P'
	sta extMatch2+4

	lda #'C'
	sta extMatch3
	sta extMatch3+1
	sta extMatch3+2
	sta extMatch3+4

	lda #'G'
	sta extMatch1+3
	sta extMatch3+6

	lda #'D'
	sta extMatch2+3

	lda #'3'
	sta extMatch3+3

	lda #'B'
	sta extMatch1+5

	lda #'I'
	sta extMatch2+5
	sta extMatch2+6

	lda #'N'
	sta extMatch3+5

	jsr InitFileBrowser

	stz Joy1New				; reset input buttons
	stz Joy1New+1
	stz Joy1Press
	stz Joy1Press+1



ROMBrowserLoop:
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

	jmp SelectionMade

+	jsr NextDir

++



; -------------------------- check for B button = go up one directory / return to intro
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

	jsr PrintClearScreen			; ... if so, back to intro screen
	jmp GotoIntroScreen

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



; -------------------------- check for Start button = load last game info
	lda Joy1New+1
	and #%00010000
	beq +

	jsr SpriteMessageLoading
	jsr LoadLastGame

	jmp GotoGameOptions

+

	jmp ROMBrowserLoop			; end of loop



SelectionMade:
;	jsr SpriteMessageLoading		; don't show loading message here, check for ROM or SPC first instead

	rep #A_8BIT				; A = 16 bit

	lda sourceCluster			; backup current dir cluster (only relevant for SPC files)
	sta DP_sourceCluster_BAK

	lda sourceCluster+2
	sta DP_sourceCluster_BAK+2

	ldy #$0000

-	lda tempEntry, y			; copy game name
	sta gameName, y
	iny
	iny
	cpy #$0080				; 128 bytes
	bne -

	lda gameName.gCluster			; copy game cluster to source cluster
	sta sourceCluster

	lda gameName.gCluster+2
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
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'N'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'E'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'S'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'-'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'S'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'P'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'C'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'7'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'0'
	bne __FileIsNotSPC

	iny

	lda sectorBuffer1, y
	cmp #'0'
	bne __FileIsNotSPC

	jmp GotoSPCplayer			; SPC file detected, load player



; -------------------------- ROM file selected, attempt SRM auto-matching
__FileIsNotSPC:
	jsr SpriteMessageLoading

	FindFile "SAVES.   "			; "SAVES" directory

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

	lda #$01				; number of file types to look for (1, SRM only)
	sta extNum
	stz extNum+1

	lda #'S'
	sta extMatch1

	lda #'R'
	sta extMatch2

	lda #'M'
	sta extMatch3

	lda #%00000001				; use SDRAM buffer, don't skip hidden files
	sta CLDConfigFlags

	jsr CardLoadDir				; load save dir (.SRM files)

	ldy #$0000

__GetROMExtPosition:				; check where ROM extension starts
	lda gameName, y
	cmp #'.'
	bne __IncPosition

	lda gameName+1, y
	cmp #'s'
	beq __ROMExtStartsWithS			; found .s (for .sfc, .smc, .swc ROMs)
	cmp #'S'
	beq __ROMExtStartsWithS			; found .S

	cmp #'g'
	beq __ROMExtStartsWithG			; found .g (for .gd3 ROMs)
	cmp #'G'
	beq __ROMExtStartsWithG			; found .G

	cmp #'f'
	beq __ROMExtStartsWithF			; found .f (for .fig ROMs)
	cmp #'F'
	beq __ROMExtStartsWithF			; found .F

	cmp #'b'
	beq __ROMExtStartsWithB			; found .b (for .bin ROMs)
	cmp #'B'
	beq __ROMExtStartsWithB			; found .B



__IncPosition:					; go to the next character
	iny
	cpy #$007A				; 122 chars
	bne __GetROMExtPosition
	bra __NoROMExtFound



__ROMExtStartsWithS:
	iny					; skip the "f"/"m"/"w", only check for "c"
	iny
	lda gameName+1, y
	cmp #'c'
	beq __ROMExtSuccess
	cmp #'C'
	beq __ROMExtSuccess
	bra __GetROMExtPosition



__ROMExtStartsWithG:
	iny					; skip the "d", only check for "3"
	iny
	lda gameName+1, y
	cmp #'3'
	beq __ROMExtSuccess
	bra __GetROMExtPosition



__ROMExtStartsWithF:
	iny					; skip the "i", only check for "g"
	iny
	lda gameName+1, y
	cmp #'g'
	beq __ROMExtSuccess
	cmp #'G'
	beq __ROMExtSuccess
	bra __GetROMExtPosition



__ROMExtStartsWithB:
	iny					; skip the "i", only check for "n"
	iny
	lda gameName+1, y
	cmp #'n'
	beq __ROMExtSuccess
	cmp #'N'
	beq __ROMExtSuccess
	bra __GetROMExtPosition



__NoROMExtFound:
	jmp GotoGameOptions			; if no ROM extension is found at all, we can't go on searching



__ROMExtSuccess:
	iny					; to get rid of the "+1"

	sty temp				; save Y value

	jsr DirFindEntryLong			; start searching, back here means matching save file found

	ldy temp

__CopySaveName:
	lda tempEntry, y			; copy <SaveNameWeJustFound.srm>
	sta saveName, y
	dey
	bpl __CopySaveName

	rep #A_8BIT				; A = 16 bit

	lda tempEntry.tempCluster		; copy save cluster
	sta saveName.sCluster

	lda tempEntry.tempCluster+2
	sta saveName.sCluster+2

	sep #A_8BIT				; A = 8 bit

	jmp GotoGameOptions



; ************************** DirFindEntryLong **************************

DirFindEntryLong:
	rep #A_8BIT				; A = 16 bit

	stz selectedEntry			; reset selectedEntry

	lda filesInDir				; only do the search if directory isn't empty
	beq __DirFindEntryLongFailed



__DirFindEntryLongLoop:
	sep #A_8BIT

	lda #%00000001				; use SDRAM buffer (h flag not relevant in this case)
	sta CLDConfigFlags

	jsr DirGetEntry				; put entry into tempEntry

	ldy temp				; load index position of last extension character

	lda tempEntry, y			; check if entry matches, working backwards for efficiency :-)
	cmp #'m'
	beq +
	cmp #'M'
	bne __IncrementEntryIdx

+	dey
	lda tempEntry, y
	cmp #'r'
	beq +
	cmp #'R'
	bne __IncrementEntryIdx

+	dey
	lda tempEntry, y
	cmp #'s'
	beq _f
	cmp #'S'
	bne __IncrementEntryIdx

__	dey
	lda tempEntry, y
	cmp gameName, y
	bne __IncrementEntryIdx
	cpy #$0000
	bne _b
rts						; all chars match



__IncrementEntryIdx:
	rep #A_8BIT

	inc selectedEntry			; increment entry index

	lda selectedEntry			; check for max. no. of files
	cmp filesInDir
	bne __DirFindEntryLongLoop



__DirFindEntryLongFailed:
	pla					; clean up the stack as there's no rts from "jsr DirFindEntryLong" if no entry was found

	sep #A_8BIT

	jmp GotoGameOptions



; ******************************** EOF *********************************
