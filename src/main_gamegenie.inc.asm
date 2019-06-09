;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** GAME GENIE CODE ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.INDEX 16

; ********************* Init GG code list browser **********************

; File extensions to look for, mapped to search variables:
;
;           |     | +1  | +2  | +3  | +4  | +5  | +6  | +7  | +8  | +9  | +10 |
; ------------------------------------------------------------------------------
; extMatch1 |  T  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch2 |  X  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch3 |  T  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------



InitTXTBrowser:
	Accu16

	lda	rootDirCluster						; start in root directory
	sta	sourceCluster
	lda	rootDirCluster+2
	sta	sourceCluster+2
	stz	DP_SubDirCounter					; reset subdirectory counter

	Accu8

	lda	#$01							; number of file types to look for (1, TXT only)
	sta	extNum
	stz	extNum+1
	lda	#'T'
	sta	extMatch1
	sta	extMatch3
	lda	#'X'
	sta	extMatch2
	jsr	FileBrowser
	lda	DP_SelectionFlags					; check if file was selected
	and	#%00000001
;	bne	GGCodeListSelected					; yes, process file
	beq	__GGBrowserEnd						; no, jump out



; -------------------------- TXT file selected
GGCodeListSelected:
	jsr	GameGenieClearAll					; clear out all previously entered codes

	Accu16

	lda	tempEntry.Cluster					; copy TXT file cluster to source cluster
	sta	sourceCluster
	lda	tempEntry.Cluster+2
	sta	sourceCluster+2

	Accu8

	ldx	#sectorBuffer1						; put into sector RAM
	stx	destLo
	stz	destBank
	stz	sectorCounter
	stz	bankCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector
	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector						; sector -> WRAM
	ldx	#$0000
	ldy	#$0000

ReadLoop:								; read GG codes from text file
	lda	sectorBuffer1, y
	cmp	#$20							; space - read to end of line, then next code
	beq	ReadLine
	cmp	#$0D							; CR
	beq	NextCode
	cmp	#$0A							; LF
	beq	NextCode
	cmp	#$1A							; EOF
	beq	ReadLoopDone
	cmp	#$30
	bcc	NextChar						; under 0
	cmp	#$3A
	bcc	SaveCharNumJump						; between 0 and 9
	cmp	#$41
	bcc	NextChar						; under A
	cmp	#$47
	bcc	SaveCharAlphaJump					; between A and F
	bra	NextChar

SaveCharAlphaJump:
	jsr	SaveCharAlpha
	bra	NextGGChar

SaveCharNumJump:
	jsr	SaveCharNum
	bra	NextGGChar

ReadLine:
	;PrintString "R"

	lda	sectorBuffer1, y
	cmp	#$0D
	beq	NextCode
	cmp	#$0A
	beq	NextCode
	iny
	cpy	#$0100							; CHANGEME --> read 256 bytes per line only ??
;	beq	ReadLoopDone
;	bra	ReadLine
	bne	ReadLine

__GGBrowserEnd:
	rts



NextCode:
;  PrintString "N"

	stx	temp

 ; PrintHexNum temp

	lda	temp
	and	#%00000111
	beq	NextChar						; already at the beginning of a code, skip
	lda	temp
	and	#%11111000						; go to beginning of current code
	clc
	adc	#%00001000						; go to beginning of next code
	sta	temp
	ldx	temp
	lda	temp
	cmp	#$28
	beq	ReadLoopDone
	bra	NextChar

NextGGChar:
	inx								; next GG char
	cpx	#$0028							; 40 GG chars = 5 codes × 8 chars
	beq	ReadLoopDone

NextChar:
	iny
	cpy	#$0100							; CHANGEME --> why read 256 bytes only ??
	bne	ReadLoop

ReadLoopDone:
	rts								; return to game options



SaveCharAlpha:
	lda	sectorBuffer1, y					; put character into codes
	sec
	sbc	#$41							; subtract 'A'
	clc
	adc	#$0A							; add 0-9
	sta	GameGenie.Codes, x
	sta	temp

;  PrintString " A"
;  PrintHexNum temp

	rts



SaveCharNum:
	lda	sectorBuffer1, y					; put character into codes
	sec
	sbc	#$30							; subtract '0'
	sta	GameGenie.Codes, x
	sta	temp

;  PrintString " C"
;  PrintHexNum temp

	rts



; ************************** GG code handler ***************************

GameGenieClearCode:							; clears out one GG code at a time, expects code no. set to Y
	ldx	#$0000							; (#$0000 = code 1, #$0008 = code 2, ... #$0020 = code 5)
	lda	#$10							; $10 = underscore on code display
-	sta	GameGenie.Codes, y
	iny
	inx
	cpx	#$0008
	bne	-

	rts



GameGenieClearAll:							; clears out all GG codes at once
	Accu16

	ldy	#$0000
	lda	#$1010							; $10 = underscore on GG code display
-	sta	GameGenie.Codes, y
	iny
	iny
	cpy	#$0028							; 5 * 8 = 40 characters
	bne	-

	Accu8

	rts



GameGeniePrint:								; code to print already set to Y
	phy
	jsr	CLD_ClearEntryName					; clear out tempEntry
	ply
	stz	GameGenie.CharOffset+1
	ldx	#$0000
-	lda	GameGenie.Codes, y
	sta	GameGenie.CharOffset
	iny								; advance code character offset
	phx
	ldx	GameGenie.CharOffset
	lda.l	GameGenieCharDB, x					; look up ASCII equivalent for code char
	plx
	sta	tempEntry, x
	inx
	lda	#' '							; put 3 spaces after each char
	sta	tempEntry, x
	inx
	sta	tempEntry, x
	inx
	sta	tempEntry, x
	inx
	cpx	#$0020							; (1 char + 3 spaces) × 8 = 32 chars to print
	bne	-

	stz	tempEntry, x						; NUL-terminator
	ldy	#PTR_tempEntry

	PrintString "%s"

	rts



GameGenieDecode:							; code to decode set to Y
	phy
	stz	GameGenie.CharOffset+1
	ldx	#$0000
-	lda	GameGenie.Codes, y
	sta	GameGenie.CharOffset
	iny								; advance code character offset
	phx
	ldx	GameGenie.CharOffset
	lda.l	GGCharConvertedToHexDB, x				; look up real hex equivalent for GG hex character
	plx
	sta	GameGenie.RealHex, x
	inx
	cpx	#$0008							; 8 characters per code
	bne	-

	ply
	phy
	ldx	#$0000
	ldy	#$0000
-	lda	GameGenie.RealHex, x
	asl	a
	asl	a
	asl	a
	asl	a
	ora	GameGenie.RealHex+1, x
	sta	GameGenie.Scratchpad, y					; get code as DDAA-AAAA in byte format into Scratchpad+0/+1/+2/+3
	inx
	inx
	iny
	cpx	#$0008							; 8 chars
	bne	-

	ply
	lda	GameGenie.Scratchpad
	sta	GameGenie.Decoded, y					; DATA done

; ijklqrst opabcduv wxefghmn --> Genie ADDR (i = bit 23 ... n = bit 0)
; abcdefgh ijklmnop qrstuvwx --> SNES ADDR (a = bit 23 ... x = bit 0)

	Accu16

	lda	GameGenie.Scratchpad+2					; wxefghmn opabcduv
	pha
	asl	a							; xefghmno pabcduv0, w = carry bit
	rol	GameGenie.Scratchpad+2					; xefghmno pabcduvw
	asl	a							; efghmnop abcduv00, x = carry bit
	rol	GameGenie.Scratchpad+2					; efghmnop abcduvwx
	pla								; wxefghmn opabcduv

	Accu8

	xba								; wxefghmn
	lsr	a
	lsr	a							; 00wxefgh
	and	#$0F							; 0000efgh
	sta	temp
	lda	GameGenie.Scratchpad+1					; ijklqrst
	and	#$F0							; ijkl0000
	sta	temp+1

	Accu16

	lda	GameGenie.Scratchpad+2					; efghmnop abcduvwx
	and	#$0FF0							; 0000mnop abcd0000
	ora	temp							; ijklmnop abcdefgh
	sta	GameGenie.Decoded+1, y
	
	Accu8

	lda	GameGenie.Scratchpad+1					; ijklqrst
	asl	a
	asl	a
	asl	a
	asl	a
	sta	temp							; qrst0000
	lda	GameGenie.Scratchpad+2					; abcduvwx
	and	#$0F							; 0000uvwx
	ora	temp							; qrstuvwx
	sta	GameGenie.Decoded+3, y

	PrintString "$"

	lda	GameGenie.Decoded+1, y
	sta	temp

	PrintHexNum temp

	lda	GameGenie.Decoded+2, y
	sta	temp

	PrintHexNum temp

	lda	GameGenie.Decoded+3, y
	sta	temp

	PrintHexNum temp
	PrintString " = $"

	lda	GameGenie.Decoded, y
	sta	temp

	PrintHexNum temp

	rts



GameGenieNextChar:
	ldx	GameGenie.CharOffset
	lda	GameGenie.Codes, x
	inc	a
	sta	GameGenie.Codes, x
	cmp	#$11
	bne	+
	stz	GameGenie.Codes, x
+	jsr	GameGeniePrint
	rts



GameGeniePrevChar:
	ldx	GameGenie.CharOffset
	lda	GameGenie.Codes, x
	dec	a
	sta	GameGenie.Codes, x
	cmp	#$FF
	bne	+
	lda	#$10
	sta	GameGenie.Codes, x
+	jsr	GameGeniePrint
	rts



GameGenieWriteCode:
	PrintString "GG-> "

	jsr	GameGenieDecode
	lda	GameGenie.Codes, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+1, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+2, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+3, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+4, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+5, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+6, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	lda	GameGenie.Codes+7, y
	cmp	#16
	beq	GameGenieWriteCodeSkip
	bra	GameGenieWriteCodeGood

GameGenieWriteCodeSkip:
	PrintString " code unused"

	jmp	GameGenieWriteCodeDone

GameGenieWriteCodeGood:
	lda	GameGenie.Decoded, y					; data
	sta	ggcode
	lda	GameGenie.Decoded+1, y					; bank
	sta	ggcode+1
	lda	GameGenie.Decoded+2, y					; high
	sta	ggcode+2
	lda	GameGenie.Decoded+3, y					; low
	sta	ggcode+3
	lda	#$00
	sta	CONFIGWRITESRAMSIZE
	lda	ggcode+1						; GG addr = bbhhll
	and	#$F0
	lsr	a
	lsr	a							; bank index = bb >> 3  Fx->1F
	lsr	a
	sta	sourceLo

	PrintString " b="
	PrintHexNum sourceLo

	stz	sourceHi
	ldx	sourceLo
	lda	gameBanks, x
	sta	errorCode
	inx								; THIS IS WRONG?  SHOULD BE +$10?
	lda	gameBanks, x
	sta	errorCode+1
	lda	errorCode
	sta	CONFIGWRITEBANK+$1E0					; put indexed bank into F0low reg

	PrintString " blo="
	PrintHexNum errorCode
;	DelayFor 172							; for debugging

	lda	errorCode+1
	sta	CONFIGWRITEBANK+$1F0					; put indexed bank into F0hi reg

	PrintString " bhi="
	PrintHexNum errorCode+1
;	DelayFor 172							; for debugging

	lda	ggcode+3
	sta	destLo
	lda	ggcode+2
	sta	destHi
	lda	ggcode+1
	and	#$0F
	sta	errorCode

	PrintHexNum errorCode
	PrintHexNum destHi
	PrintHexNum destLo

	ldx	destLo
	lda	errorCode
	cmp	#$00
	beq	GGF0
	cmp	#$01
	beq	GGF1
	cmp	#$02
	beq	GGF2
	cmp	#$03
	beq	GGF3
	cmp	#$04
	beq	GGF4
	cmp	#$05
	beq	GGF5
	cmp	#$06
	beq	GGF6
	cmp	#$07
	beq	GGF7
	bra	GGFjump

GGF0:
	lda	ggcode							; write GG data to F0hhll
	sta	$F00000, x
	jmp	GGCheck

GGF1:
	lda	ggcode							; write GG data to F0hhll
	sta	$F10000, x
	jmp	GGCheck

GGF2:
	lda	ggcode							; write GG data to F0hhll
	sta	$F20000, x
	jmp	GGCheck

GGF3:
	lda	ggcode							; write GG data to F0hhll
	sta	$F30000, x
	bra	GGCheck

GGF4:
	lda	ggcode							; write GG data to F0hhll
	sta	$F40000, x
	bra	GGCheck

GGF5:
	lda	ggcode							; write GG data to F0hhll
	sta	$F50000, x
	bra	GGCheck

GGF6:
	lda	ggcode							; write GG data to F0hhll
	sta	$F60000, x
	bra	GGCheck

GGF7:
	lda	ggcode							; write GG data to F0hhll
	sta	$F70000, x
	bra	GGCheck

GGFjump:
	cmp	#$08
	beq	GGF8
	cmp	#$09
	beq	GGF9
	cmp	#$0A
	beq	GGFA
	cmp	#$0B
	beq	GGFB
	cmp	#$0C
	beq	GGFC
	cmp	#$0D
	beq	GGFD
	cmp	#$0E
	beq	GGFE
	cmp	#$0F
	beq	GGFF

GGF8:
	lda	ggcode							; write GG data to F0hhll
	sta	$F80000, x
	bra	GGCheck

GGF9:
	lda	ggcode							; write GG data to F0hhll
	sta	$F90000, x
	bra	GGCheck

GGFA:
	lda	ggcode							; write GG data to F0hhll
	sta	$FA0000, x
	bra	GGCheck

GGFB:
	lda	ggcode							; write GG data to F0hhll
	sta	$FB0000, x
	bra	GGCheck

GGFC:
	lda	ggcode							; write GG data to F0hhll
	sta	$FC0000, x
	bra	GGCheck

GGFD:
	lda	ggcode							; write GG data to F0hhll
	sta	$FD0000, x
	bra	GGCheck

GGFE:
	lda	ggcode							; write GG data to F0hhll
	sta	$FE0000, x
	bra	GGCheck

GGFF:
	lda	ggcode							; write GG data to F0hhll
	sta	$FF0000, x
;	bra	GGCheck

GGCheck:
	lda	$F00000, x
	sta	errorCode
	stx	sourceLo
	lda	sramSizeByte
	sta	CONFIGWRITESRAMSIZE
	lda	gameBanks+$1E
	sta	CONFIGWRITEBANK+$1E0					; put bank back
	lda	gameBanks+$1F
	sta	CONFIGWRITEBANK+$1F0					; put bank back

GameGenieWriteCodeDone:
	rts



; ******************* GG character conversion chart ********************

GameGenieCharDB:
	.DB '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', '_'

GGCharConvertedToHexDB:
	.DB $04, $06, $0D, $0E, $02, $07, $08, $03, $0B, $05, $0C, $09, $0A, $00, $0F, $01, $00



; ******************************** EOF *********************************
