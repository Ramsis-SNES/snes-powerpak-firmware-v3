;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2016 by ManuLöwe (http://manuloewe.de/)
;
;	*** MAIN CODE SECTION: THEME FILE HANDLER ***
;
;==========================================================================================



.ACCU 8
.INDEX 16

; ************************* Init theme browser *************************

; File extensions to look for, mapped to search variables:
;
;           |     | +1  | +2  | +3  | +4  | +5  | +6  | +7  | +8  | +9  | +10 |
; ------------------------------------------------------------------------------
; extMatch1 |  T  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch2 |  H  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------
; extMatch3 |  M  |     |     |     |     |     |     |     |     |     |     |
; ------------------------------------------------------------------------------



InitTHMBrowser:
	jsr	SpriteMessageLoading

	FindFile "THEMES.   "

	lda	#$01				; number of file types to look for (1, THM only)
	sta	extNum
	stz	extNum+1

	lda	#'T'
	sta	extMatch1

	lda	#'H'
	sta	extMatch2

	lda	#'M'
	sta	extMatch3

	lda	#2					; set subdirectory counter accordingly
	sta	DP_SubDirCounter
	stz	DP_SubDirCounter+1

	jsr	FileBrowser

	lda	DP_SelectionFlags			; check if file was selected
	and	#%00000001
	bne	ThemeFileSelected			; yes, process file

	jsr	PrintClearScreen			; no, clear screen

	lda	#cursorXsettings			; put cursor back on 3rd menu line
	sta	cursorX

	lda	#cursorYsetmenu3
	sta	cursorY

	jmp	__ReturnFromMenuSection		; return to settings menu



; -------------------------- process selected file
ThemeFileSelected:				; THM file selected --> load new theme, and return to intro
	lda	#$0F

-	wai					; screen fade-out loop

	dec	a					; 15 / 3 = 5 frames
	dec	a
	dec	a
	sta	$2100
	bne	-

	lda	#$80				; enter forced blank
	sta	$2100

	stz	DP_HDMAchannels			; turn off HDMA to safely update tables, mess around with CGRAM,
						; and use DMAs of any transfer length (not possible with HDMA active on
	wai					; rev1 CPU consoles)

	Accu16

	lda	tempEntry.tempCluster		; copy file cluster
	sta	DP_ThemeFileClusterLo

	lda	tempEntry.tempCluster+2
	sta	DP_ThemeFileClusterHi

	Accu8

	jsr	LoadTheme
	jsr	PrintClearScreen
	jmp	GotoIntroScreen



LoadTheme:					; expects that we're in forced blank & HDMA is off!
	Accu16

	lda	DP_ThemeFileClusterLo		; load cluster of selected theme file
	sta	sourceCluster

	lda	DP_ThemeFileClusterHi
	sta	sourceCluster+2

	Accu8

	lda	#$00				; reset SDRAM address
	sta	DMAWRITEBANK
	sta	DMAWRITEHI
	sta	DMAWRITELO

	stz	sectorCounter
	stz	bankCounter

;	lda	#kDestSDRAM				; never mind, this is done in CardReadFile
;	sta	destType

	jsr	CardReadFile			; load selected file to SDRAM

	sei					; disable interrupts (as VRAM addresses are changed during NMI)
	stz	REG_NMITIMEN

	lda	#$00				; reset SDRAM address once again
	sta	DMAWRITEBANK
	sta	DMAWRITEHI
	sta	DMAWRITELO



; -------------------------- process theme file data 01: "expand" BG font for hi-res use into VRAM
	lda	#$80				; VRAM address increment mode: increment address by one word after accessing the high byte ($2119)
	sta	$2115

	ldx	#ADDR_VRAM_BG1_TILES		; set VRAM address for BG1 font tiles
	stx	$2116

	ldx	#0

__BuildFontFromThemeBG1:
	ldy	#0

-	lda	DMAREADDATA				; first, copy font tile (font tiles sit on the "left")
	sta	$2118
	lda	DMAREADDATA
	sta	$2119
	inx
	inx
	iny
	cpy	#8					; 16 bytes (8 double bytes) per tile
	bne	-

	ldy	#0

-	stz	$2118				; next, add 3 blank tiles (1 blank tile because Mode 5 forces 16×8 tiles
	stz	$2119
	iny					; and 2 blank tiles because BG1 is 4bpp)
	cpy	#24					; 16 bytes (8 double bytes) per tile
	bne	-

	cpx	#2048				; 2 KiB font done?
	bne	__BuildFontFromThemeBG1

	lda	#$00				; reset SDRAM address once again (the same font goes to both BG1 and BG2)
	sta	DMAWRITEBANK
	sta	DMAWRITEHI
	sta	DMAWRITELO

	ldx	#ADDR_VRAM_BG2_TILES		; set VRAM address for BG2 font tiles
	stx	$2116

	ldx	#0

__BuildFontFromThemeBG2:
	ldy	#0

-	stz	$2118				; first, add 1 blank tile (Mode 5 forces 16×8 tiles,
	stz	$2119
	iny					; no more blank tiles because BG2 is 2bpp)
	cpy	#8					; 16 bytes (8 double bytes) per tile
	bne	-

	ldy	#0

-	lda	DMAREADDATA				; next, copy 8×8 font tile (font tiles sit on the "right")
	sta	$2118
	lda	DMAREADDATA
	sta	$2119
	inx
	inx
	iny
	cpy	#8					; 16 bytes (8 double bytes) per tile
	bne	-

	cpx	#2048				; 2 KiB font done?
	bne	__BuildFontFromThemeBG2



; -------------------------- process theme file data 02-04: sprite-based font, main GFX, and cursor/button sprites (14 KiB total) --> VRAM
;	lda	#$80				; never mind, this was done before
;	sta	$2115

	ldx	#ADDR_VRAM_SPR_TILES		; set VRAM address for sprite tiles
	stx	$2116

	ldx	#0

-	lda	DMAREADDATA				; low byte of GFX data
	sta	$2118

	lda	DMAREADDATA				; high byte of GFX data
	sta	$2119

	inx
	cpx	#7168				; 14 KiB (sic, because of low/high byte write) done?
	bne	-



; -------------------------- process theme file data 05-08: palettes --> CGRAM
	stz	$2121				; reset CGRAM address

	ldx	#0

-	lda	DMAREADDATA
	sta	$2122

	inx
	cpx	#8					; 4 colors = 8 bytes done?
	bne	-

	lda	#ADDR_CGRAM_MAIN_GFX		; set CGRAM address to main GFX palette
	sta	$2121

	ldx	#0

-	lda	DMAREADDATA
	sta	$2122

	inx
	cpx	#64					; 32 colors = 64 bytes done?
	bne	-

	lda	#ADDR_CGRAM_FONT_SPR		; set CGRAM address for sprite-based font palettes
	sta	$2121

	ldx	#0

-	lda	DMAREADDATA
	sta	$2122

	inx
	cpx	#160				; 80 colors = 160 bytes done?
	bne	-



; -------------------------- process theme file data 09: BG color gradient --> WRAM (theme buffer)
	ldx	#(HDMAtable.BG & $FFFF)		; set WRAM address = HDMA backdrop color gradient buffer, get lower word
	stx	$2181
	stz	$2183

	ldx	#0					; rebuild table

-	lda	#1					; scanline no.
	sta	$2180

	stz	$2180				; 1st word: CGRAM address ($00)
	stz	$2180

	lda	DMAREADDATA				; 2nd word: color
	sta	$2180
	lda	DMAREADDATA
	sta	$2180

	inx
	cpx	#224				; 224 HDMA table entries done?
	bne	-

	stz	$2180				; end of HDMA table



; -------------------------- process theme file data 10: sprite-based font width table --> WRAM (theme buffer)
	ldx	#(SpriteFWT & $FFFF)		; set WRAM address = font width table buffer
	stx	$2181
	stz	$2183

	ldx	#0

-	lda	DMAREADDATA				; copy table to WRAM buffer
	sta	$2180

	inx
	cpx	#128				; 128 table entries done?
	bne	-



; -------------------------- process theme file data 11: color math fill color for SPC player "window"
	lda	DMAREADDATA
	sta	HDMAtable.ColorMath+4		; location of color to be added within color math HDMA table

	lda	DMAREADDATA
	sta	HDMAtable.ColorMath+5

	lda	#$81				; re-enable interrupts
	sta	REG_NMITIMEN

	cli
	rts



; ******************************** EOF *********************************
