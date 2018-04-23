;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** VIDEO SETUP ***
;
;==========================================================================================



; ***************************** Set up GFX *****************************

GFXsetup:
	Accu8
	Index16



; -------------------------- HDMA tables --> WRAM
	ldx	#(HDMAtable.BG & $FFFF)					; set WRAM address = HDMA backdrop color gradient buffer, get lower word
	stx	$2181
	stz	$2183
	ldx	#0
	lda	#1							; build placeholder table with an all-black background
-	sta	$2180							; scanline no.
	stz	$2180							; 1st word: CGRAM address ($00)
	stz	$2180
	stz	$2180							; 2nd word: color (black)
	stz	$2180
	inx
	cpx	#224							; 224 HDMA table entries done?
	bne	-

	stz	$2180							; end of HDMA table
	ldx	#0
-	lda.l	HDMA_Window, x						; copy HDMA windowing table to buffer
	sta	HDMAtable.Window, x
	inx
	cpx	#_sizeof_HDMA_Window					; 13 bytes
	bne	-

	ldx	#0
-	lda.l	HDMA_Scroll, x						; copy HDMA horizontal scroll offset table to buffer
	sta	HDMAtable.ScrollBG1, x
	sta	HDMAtable.ScrollBG2, x
	inx
	cpx	#_sizeof_HDMA_Scroll					; 21 bytes
	bne	-

	ldx	#0
-	lda.l	HDMA_ColMath, x						; copy HDMA color math table to buffer
	sta	HDMAtable.ColorMath, x
	inx
	cpx	#_sizeof_HDMA_ColMath					; 10 bytes
	bne	-



; -------------------------- palettes --> CGRAM
	stz	$2121							; reset CGRAM address
	ldx	#0
-	lda.l	BG_Palette, x
	sta	$2122
	inx
	cpx	#8							; 4 colors = 8 bytes done?
	bne	-

	lda	#ADDR_CGRAM_MAIN_GFX					; set CGRAM address for sprite palettes (main GFX palette = $80)
	sta	$2121

	DMA_CH0 $02, :Sprite_Palettes, Sprite_Palettes, $22, 256



; -------------------------- "expand" font for hi-res use into VRAM
	lda	#$80							; VRAM address increment mode: increment address by one word
	sta	$2115							; after accessing the high byte ($2119)
	ldx	#ADDR_VRAM_BG1_TILES					; set VRAM address for BG1 font tiles
	stx	$2116

	Accu16

	ldx	#$0000

__BuildFontBG1:
	ldy	#$0000
-	lda.l	Font, x							; first, copy font tile (font tiles sit on the "left")
	sta	$2118
	inx
	inx
	iny
	cpy	#$0008							; 16 bytes (8 double bytes) per tile
	bne	-

	ldy	#$0000
-	stz	$2118							; next, add 3 blank tiles (1 blank tile because Mode 5 forces 16×8 tiles
	iny								; and 2 blank tiles because BG1 is 4bpp)
	cpy	#$0018							; 16 bytes (8 double bytes) per tile
	bne	-

	cpx	#$0800							; 2 KiB font done?
	bne	__BuildFontBG1

	ldx	#ADDR_VRAM_BG2_TILES					; set VRAM address for BG2 font tiles
	stx	$2116
	ldx	#$0000

__BuildFontBG2:
	ldy	#$0000
-	stz	$2118							; first, add 1 blank tile (Mode 5 forces 16×8 tiles,
	iny								; no more blank tiles because BG2 is 2bpp)
	cpy	#$0008							; 16 bytes (8 double bytes) per tile
	bne	-

	ldy	#$0000
-	lda.l	Font, x							; next, copy 8×8 font tile (font tiles sit on the "right")
	sta	$2118
	inx
	inx
	iny
	cpy	#$0008							; 16 bytes (8 double bytes) per tile
	bne	-

	cpx	#$0800							; 2 KiB font done?
	bne	__BuildFontBG2

	Accu8



; -------------------------- sprites --> VRAM
	ldx	#ADDR_VRAM_SPR_TILES					; set VRAM address for sprite tiles
	stx	$2116

	DMA_CH0 $01, :SpriteTiles, SpriteTiles, $18, $4000



; -------------------------- font width table --> WRAM
	ldx	#(SpriteFWT & $FFFF)					; set WRAM address = sprite font width table buffer
	stx	$2181
	stz	$2183

	DMA_CH0 $00, :Sprite_FWT, Sprite_FWT, <REG_WMDATA, _sizeof_Sprite_FWT



; -------------------------- prepare tilemaps
	ldx	#ADDR_VRAM_BG1_TILEMAP					; set VRAM address to BG1 tilemap
	stx	$2116
	lda	#%00100000						; set the priority bit of all tilemap entries
	ldx	#$0800							; set BG1's tilemap size (64×32 = 2048 tiles)
-	sta	$2119							; set priority bit
	dex
	bne	-

	ldx	#ADDR_VRAM_BG2_TILEMAP					; set VRAM address to BG2 tilemap
	stx	$2116
	ldx	#$0800							; set BG2's tilemap size (64×32 = 2048 tiles)
-	sta	$2119							; set priority bit
	dex
	bne	-



; -------------------------- set up the screen
GFXsetup2:
	lda	#%00000011						; 8×8 (small) / 16×16 (large) sprites, character data at $6000
	sta	$2101
	lda	#$05							; set BG mode 5 for horizontal high resolution :-)
	sta	$2105
;	lda	#$08							; never mind (unless a BGMODE change would occur mid-frame)
;	sta	$2133
	lda	#%00000001						; BG1 tilemap VRAM address ($0000) & tilemap size (64×32 tiles)
	sta	$2107
	lda	#%00001001						; BG2 tilemap VRAM address ($0800) & tilemap size (64×32 tiles)
	sta	$2108
	lda	#%01000010						; set BG1's Character VRAM offset to $2000
	sta	$210B							; and BG2's Character VRAM offset to $4000
	lda	#%00010011						; turn on BG1 + BG2 + sprites
	sta	$212C							; on mainscreen
	sta	$212D							; and subscreen
	lda	#%00100010						; enable window 1 on BG1 & BG2
	sta	$2123							; (necessary to cut off scrolling "artifact" lines in the filebrowser)
	stz	$2126							; set window 1 left position (0)
	lda	#$FF							; set window 1 right position (255), window fills the whole screen
	sta	$2127
	lda	#%00000011						; enable window masking (i.e., disable the content) on BG1 & BG2
	sta	$212E							; on mainscreen
	sta	$212F							; and subscreen (all window content is re-enabled via HDMA)
	stz	$2130							; enable color math
	lda	#%00100000						; color math (mainscreen backdrop) for questions/SPC player "window"
	sta	$2131



; -------------------------- HDMA parameters

; -------------------------- channels 0, 1: reserved for general purpose DMA!

; -------------------------- channel 2



; -------------------------- channel 3: color math
	ldx	#(HDMAtable.ColorMath & $FFFF)
	stx	$4332
	lda	#$7E							; table in WRAM expected
	sta	$4334
	lda	#$32							; PPU register $2132 (color math subscreen backdrop color)
	sta	$4331
	lda	#$02							; transfer mode (2 bytes --> $2132)
	sta	$4330



; -------------------------- channel 4: background color gradient
	ldx	#(HDMAtable.BG & $FFFF)
	stx	$4342
	lda	#$7E							; table in WRAM expected
	sta	$4344
	lda	#$21							; PPU register $2121 (color index)
	sta	$4341
	lda	#$03							; transfer mode (4 bytes --> $2121, $2121, $2122, $2122)
	sta	$4340



; -------------------------- channel 5: main/subscreen window
	ldx	#(HDMAtable.Window & $FFFF)
	stx	$4352
	lda	#$7E
	sta	$4354
	lda	#$2E							; PPU reg. $212E (enable/disable mainscreen BG window area)
	sta	$4351
	lda	#$01							; transfer mode (2 bytes --> $212E, $212F)
	sta	$4350



; -------------------------- channel 6: BG1 horizontal scroll offset
	ldx	#(HDMAtable.ScrollBG1 & $FFFF)
	stx	$4362
	lda	#$7E
	sta	$4364
	lda	#$0D							; PPU reg. $210D (BG1HOFS)
	sta	$4361
	lda	#$03							; transfer mode (4 bytes --> $210D, $210D, $210E, $210E)
	sta	$4360



; -------------------------- channel 7: BG2 horizontal scroll offset
	ldx	#(HDMAtable.ScrollBG2 & $FFFF)
	stx	$4372
	lda	#$7E
	sta	$4374
	lda	#$0F							; PPU reg. $210F (BG2HOFS)
	sta	$4371
	lda	#$03							; transfer mode (4 bytes --> $210F, $210F, $2110, $2110)
	sta	$4370
	rts



; ******************************** EOF *********************************
