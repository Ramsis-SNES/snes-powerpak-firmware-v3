;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** VIDEO SETUP ***
;
;==========================================================================================



; ***************************** Set up GFX *****************************

GFXsetup:
	Accu8
	Index16



; -------------------------- HDMA tables --> WRAM
	ldx	#loword(HDMAtable.BG)					; set WRAM address = HDMA backdrop color gradient buffer
	stx	REG_WMADDL
	stz	REG_WMADDH
	ldx	#0
	lda	#1							; build placeholder table with an all-black background
-	sta	REG_WMDATA						; scanline no.
	stz	REG_WMDATA						; 1st word: CGRAM address ($00)
	stz	REG_WMDATA
	stz	REG_WMDATA						; 2nd word: color (black)
	stz	REG_WMDATA
	inx
	cpx	#224							; 224 HDMA table entries done?
	bne	-

	stz	REG_WMDATA						; end of HDMA table
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
	stz	REG_CGADD						; reset CGRAM address
	ldx	#0
-	lda.l	BG_Palette, x
	sta	REG_CGDATA
	inx
	cpx	#8							; 4 colors = 8 bytes done?
	bne	-

	lda	#ADDR_CGRAM_MAIN_GFX					; set CGRAM address for sprite palettes (main GFX palette = $80)
	sta	REG_CGADD

	DMA_CH0 $02, Sprite_Palettes, <REG_CGDATA, 256



; -------------------------- "expand" font for hi-res use into VRAM
	lda	#$80							; VRAM address increment mode: increment address by one word
	sta	REG_VMAIN						; after accessing the high byte ($2119)
	ldx	#ADDR_VRAM_BG1_TILES					; set VRAM address for BG1 font tiles
	stx	REG_VMADDL

	Accu16

	ldx	#$0000

@BuildFontBG1:
	ldy	#$0000
-	lda.l	Font, x							; first, copy font tile (font tiles sit on the "left")
	sta	REG_VMDATAL
	inx
	inx
	iny
	cpy	#$0008							; 16 bytes (8 double bytes) per tile
	bne	-

	ldy	#$0000
-	stz	REG_VMDATAL						; next, add 3 blank tiles (1 blank tile because Mode 5 forces 16×8 tiles
	iny								; and 2 blank tiles because BG1 is 4bpp)
	cpy	#$0018							; 16 bytes (8 double bytes) per tile
	bne	-

	cpx	#$0800							; 2 KiB font done?
	bne	@BuildFontBG1

	ldx	#ADDR_VRAM_BG2_TILES					; set VRAM address for BG2 font tiles
	stx	REG_VMADDL
	ldx	#$0000

@BuildFontBG2:
	ldy	#$0000
-	stz	REG_VMDATAL						; first, add 1 blank tile (Mode 5 forces 16×8 tiles,
	iny								; no more blank tiles because BG2 is 2bpp)
	cpy	#$0008							; 16 bytes (8 double bytes) per tile
	bne	-

	ldy	#$0000
-	lda.l	Font, x							; next, copy 8×8 font tile (font tiles sit on the "right")
	sta	REG_VMDATAL
	inx
	inx
	iny
	cpy	#$0008							; 16 bytes (8 double bytes) per tile
	bne	-

	cpx	#$0800							; 2 KiB font done?
	bne	@BuildFontBG2

	Accu8



; -------------------------- sprites --> VRAM
	ldx	#ADDR_VRAM_SPR_TILES					; set VRAM address for sprite tiles
	stx	REG_VMADDL

	DMA_CH0 $01, SpriteTiles, <REG_VMDATAL, $4000



; -------------------------- font width table --> WRAM
	ldx	#loword(SpriteFWT)					; set WRAM address = sprite font width table buffer
	stx	REG_WMADDL
	stz	REG_WMADDH

	DMA_CH0 $00, Sprite_FWT, <REG_WMDATA, _sizeof_Sprite_FWT



; -------------------------- prepare tilemaps
	ldx	#ADDR_VRAM_BG1_TILEMAP					; set VRAM address to BG1 tilemap
	stx	REG_VMADDL
	lda	#%00100000						; set the priority bit of all tilemap entries
	ldx	#$0800							; set BG1's tilemap size (64×32 = 2048 tiles)
-	sta	REG_VMDATAH						; set priority bit
	dex
	bne	-

	ldx	#ADDR_VRAM_BG2_TILEMAP					; set VRAM address to BG2 tilemap
	stx	REG_VMADDL
	ldx	#$0800							; set BG2's tilemap size (64×32 = 2048 tiles)
-	sta	REG_VMDATAH						; set priority bit
	dex
	bne	-



; -------------------------- set up screen registers
@Warmboot:
	lda	#%00000011						; 8×8 (small) / 16×16 (large) sprites, character data at $6000
	sta	REG_OBSEL
	lda	#$05							; set BG mode 5 for horizontal high resolution :-)
	sta	REG_BGMODE
;	lda	#$08							; never mind (unless a BGMODE change would occur mid-frame)
;	sta	REG_SETINI
	lda	#%00000001						; BG1 tilemap VRAM address ($0000) & tilemap size (64×32 tiles)
	sta	REG_BG1SC
	lda	#%00001001						; BG2 tilemap VRAM address ($0800) & tilemap size (64×32 tiles)
	sta	REG_BG2SC
	lda	#%01000010						; set BG1's Character VRAM offset to $2000
	sta	REG_BG12NBA						; and BG2's Character VRAM offset to $4000
	lda	#%00010011						; turn on BG1 + BG2 + sprites
	sta	REG_TM							; on mainscreen
	sta	REG_TS							; and subscreen
	lda	#%00100010						; enable window 1 on BG1 & BG2
	sta	REG_W12SEL						; (necessary to cut off scrolling "artifact" lines in the filebrowser)
	stz	REG_WH0							; set window 1 left position (0)
	lda	#$FF							; set window 1 right position (255), window fills the whole screen
	sta	REG_WH1
	lda	#%00000011						; enable window masking (i.e., disable the content) on BG1 & BG2
	sta	REG_TMW							; on mainscreen
	sta	REG_TSW							; and subscreen (all window content is re-enabled via HDMA)
	stz	REG_CGWSEL						; enable color math
	lda	#%00100000						; color math (mainscreen backdrop) for questions/SPC player "window"
	sta	REG_CGADSUB



; -------------------------- HDMA parameters

; -------------------------- channels 0, 1: reserved for general purpose DMA!

; -------------------------- channel 2



; -------------------------- channel 3: color math
	ldx	#loword(HDMAtable.ColorMath)
	stx	$4332
	lda	#$7E							; table in WRAM expected
	sta	$4334
	lda	#$32							; PPU register $2132 (color math subscreen backdrop color)
	sta	$4331
	lda	#$02							; transfer mode (2 bytes --> $2132)
	sta	$4330



; -------------------------- channel 4: background color gradient
	ldx	#loword(HDMAtable.BG)
	stx	$4342
	lda	#$7E							; table in WRAM expected
	sta	$4344
	lda	#$21							; PPU register $2121 (color index)
	sta	$4341
	lda	#$03							; transfer mode (4 bytes --> $2121, $2121, $2122, $2122)
	sta	$4340



; -------------------------- channel 5: main/subscreen window
	ldx	#loword(HDMAtable.Window)
	stx	$4352
	lda	#$7E
	sta	$4354
	lda	#$2E							; PPU reg. $212E (enable/disable mainscreen BG window area)
	sta	$4351
	lda	#$01							; transfer mode (2 bytes --> $212E, $212F)
	sta	$4350



; -------------------------- channel 6: BG1 horizontal scroll offset
	ldx	#loword(HDMAtable.ScrollBG1)
	stx	$4362
	lda	#$7E
	sta	$4364
	lda	#$0D							; PPU reg. $210D (BG1HOFS)
	sta	$4361
	lda	#$03							; transfer mode (4 bytes --> $210D, $210D, $210E, $210E)
	sta	$4360



; -------------------------- channel 7: BG2 horizontal scroll offset
	ldx	#loword(HDMAtable.ScrollBG2)
	stx	$4372
	lda	#$7E
	sta	$4374
	lda	#$0F							; PPU reg. $210F (BG2HOFS)
	sta	$4371
	lda	#$03							; transfer mode (4 bytes --> $210F, $210F, $2110, $2110)
	sta	$4370
	rts



; ******************************** EOF *********************************
