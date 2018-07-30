;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: INIT ROM BROWSER & LOADER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.INDEX 16

; ************************ Init ROM/SPC browser ************************

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



InitROMBrowser:
	Accu16

	lda	rootDirCluster						; start in root directory
	sta	sourceCluster
	lda	rootDirCluster+2
	sta	sourceCluster+2
	stz	DP_SubDirCounter					; reset subdirectory counter

	Accu8

	lda	#$07							; number of file types to look for (7, see table above)
	sta	extNum
	stz	extNum+1
	lda	#'S'							; using the least possible amount of lda/sta commands
	sta	extMatch1
	sta	extMatch1+1
	sta	extMatch1+2
	sta	extMatch1+4
	lda	#'M'
	sta	extMatch2
	lda	#'W'
	sta	extMatch2+1
	lda	#'F'
	sta	extMatch1+6
	sta	extMatch2+2
	lda	#'P'
	sta	extMatch2+4
	lda	#'C'
	sta	extMatch3
	sta	extMatch3+1
	sta	extMatch3+2
	sta	extMatch3+4
	lda	#'G'
	sta	extMatch1+3
	sta	extMatch3+6
	lda	#'D'
	sta	extMatch2+3
	lda	#'3'
	sta	extMatch3+3
	lda	#'B'
	sta	extMatch1+5
	lda	#'I'
	sta	extMatch2+5
	sta	extMatch2+6
	lda	#'N'
	sta	extMatch3+5
	jsr	FileBrowser
	lda	DP_SelectionFlags					; check if selection was made
	and	#%00000001
	bne	@ROMselected						; yes, process file
	jsr	PrintClearScreen					; no, go back to intro screen
	jmp	GotoIntroScreen



; -------------------------- process selected ROM file
@ROMselected:
	Accu16

	ldy	#$0000
-	lda	tempEntry, y						; copy game name
	sta	gameName, y
	iny
	iny
	cpy	#$0080							; 128 bytes
	bne	-

	Accu8



; -------------------------- attempt SRM auto-matching
	jsr	SpriteMessageLoading

	FindFile "SAVES.   "						; "SAVES" directory

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

	lda	#$01							; number of file types to look for (1, SRM only)
	sta	extNum
	stz	extNum+1
	lda	#'S'
	sta	extMatch1
	lda	#'R'
	sta	extMatch2
	lda	#'M'
	sta	extMatch3
	lda	#%00000001						; use SDRAM buffer, don't skip hidden files
	sta	CLDConfigFlags
	jsr	CardLoadDir						; load save dir (.SRM files)
	ldy	#$0000

@GetROMExtPosition:							; check where ROM extension starts
	lda	gameName, y
	cmp	#'.'
	bne	@IncPosition
	lda	gameName+1, y
	cmp	#'s'
	beq	@ROMExtStartsWithS					; found .s (for .sfc, .smc, .swc ROMs)
	cmp	#'S'
	beq	@ROMExtStartsWithS					; found .S
	cmp	#'g'
	beq	@ROMExtStartsWithG					; found .g (for .gd3 ROMs)
	cmp	#'G'
	beq	@ROMExtStartsWithG					; found .G
	cmp	#'f'
	beq	@ROMExtStartsWithF					; found .f (for .fig ROMs)
	cmp	#'F'
	beq	@ROMExtStartsWithF					; found .F
	cmp	#'b'
	beq	@ROMExtStartsWithB					; found .b (for .bin ROMs)
	cmp	#'B'
	beq	@ROMExtStartsWithB					; found .B

@IncPosition:								; go to the next character
	iny
	cpy	#$007A							; 122 chars
	bne	@GetROMExtPosition
	bra	@NoROMExtFound

@ROMExtStartsWithS:
	iny								; skip the "f"/"m"/"w", only check for "c"
	iny
	lda	gameName+1, y
	cmp	#'c'
	beq	@ROMExtSuccess
	cmp	#'C'
	beq	@ROMExtSuccess
	bra	@GetROMExtPosition

@ROMExtStartsWithG:
	iny								; skip the "d", only check for "3"
	iny
	lda	gameName+1, y
	cmp	#'3'
	beq	@ROMExtSuccess
	bra	@GetROMExtPosition

@ROMExtStartsWithF:
	iny								; skip the "i", only check for "g"
	iny
	lda	gameName+1, y
	cmp	#'g'
	beq	@ROMExtSuccess
	cmp	#'G'
	beq	@ROMExtSuccess
	bra	@GetROMExtPosition

@ROMExtStartsWithB:
	iny								; skip the "i", only check for "n"
	iny
	lda	gameName+1, y
	cmp	#'n'
	beq	@ROMExtSuccess
	cmp	#'N'
	beq	@ROMExtSuccess
	bra	@GetROMExtPosition

@NoROMExtFound:
	jmp	GotoGameOptions						; if no ROM extension is found at all, we can't go on searching

@ROMExtSuccess:
	iny								; to get rid of the "+1"
	sty	temp							; save Y value
	jsr	DirFindEntryLong					; start searching, back here means matching save file found
	ldy	temp

@CopySaveName:
	lda	tempEntry, y						; copy <SaveNameWeJustFound.srm>
	sta	saveName, y
	dey
	bpl	@CopySaveName

	Accu16

	lda	tempEntry.Cluster					; copy save cluster
	sta	saveName.Cluster
	lda	tempEntry.Cluster+2
	sta	saveName.Cluster+2

	Accu8

	jmp	GotoGameOptions



; ************************** DirFindEntryLong **************************

DirFindEntryLong:
	Accu16

	stz	selectedEntry						; reset selectedEntry
	lda	filesInDir						; only do the search if directory isn't empty
	beq	@Failed

@Loop:
	Accu8

	lda	#%00000001						; use SDRAM buffer (h flag not relevant in this case)
	sta	CLDConfigFlags
	jsr	DirGetEntry						; put entry into tempEntry
	ldy	temp							; load index position of last extension character
	lda	tempEntry, y						; check if entry matches, working backwards for efficiency :-)
	cmp	#'m'
	beq	+
	cmp	#'M'
	bne	@IncEntryIndex
+	dey
	lda	tempEntry, y
	cmp	#'r'
	beq	+
	cmp	#'R'
	bne	@IncEntryIndex
+	dey
	lda	tempEntry, y
	cmp	#'s'
	beq	_f
	cmp	#'S'
	bne	@IncEntryIndex
__	dey
	lda	tempEntry, y
	cmp	gameName, y
	bne	@IncEntryIndex
	cpy	#$0000
	bne	_b
	rts								; all chars match

@IncEntryIndex:
	Accu16

	inc	selectedEntry						; increment entry index
	lda	selectedEntry						; check for max. no. of files
	cmp	filesInDir
	bne	@Loop

@Failed:
	pla								; clean up the stack as there's no rts from "jsr DirFindEntryLong" if no entry was found

	Accu8

	jmp	GotoGameOptions



; ******************************** EOF *********************************
