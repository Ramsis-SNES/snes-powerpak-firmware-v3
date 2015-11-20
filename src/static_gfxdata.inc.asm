;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** GRAPHICS DATA ***
;
;==========================================================================================



; *************************** Local defines ****************************

.DEFINE BG_FONT_2BPP		".\\gfx-rom\\font-bg.pic"		; 2 KiB
.DEFINE SPRITE_FONT_4BPP	".\\gfx-rom\\font-spr.pic"		; 4 KiB

.DEFINE CURSOR_BUTTONS		".\\gfx-rom\\cursor_buttons.pic"	; 2 KiB
.DEFINE PALETTE_CURSOR_BUTTONS	".\\gfx-rom\\cursor_buttons.pal"

.DEFINE POWERPAK_SMALL		".\\gfx-rom\\powerpak_small.pic"	; 2 KiB
.DEFINE PALETTE_POWERPAK	".\\gfx-rom\\powerpak_small.pal"	; 16 colors = 32 bytes each

.DEFINE MAIN_GFX		".\\gfx-rom\\powerpak_128x128.pic"	; 8 KiB
.DEFINE PALETTE_MAIN_GFX	".\\gfx-rom\\powerpak_128x128.pal"



; ************************ Font/BG palette data ************************

; There are 32 BG palettes (4 colors = 8 bytes each). Only the first is
; used at all (for both BG1 and BG2).

BG_Palette:
	.DW $0000				; main backdrop (black)
	.DW $0C63				; font drop shadow (dark grey)
	.DW $0000				; unused color
	.DW $7FFF				; font (white)



; ************************ Sprite palette data *************************

; There are 8 sprite palettes (16 colors = 32 bytes each).

Sprite_Palettes:



; -------------------------- Palettes 0-2: graphics
	.INCBIN PALETTE_MAIN_GFX		; main graphics
	.INCBIN PALETTE_CURSOR_BUTTONS		; arrow-style cursor, SNES joypad buttons
	.INCBIN PALETTE_POWERPAK		; small PowerPak logo



; -------------------------- Palette 3: white font
	.DW $0000				; unused color
	.DW $0C63				; font drop shadow (dark grey)
	.DW $0000				; unused color
	.DW $7FFF				; font (white)

.REPEAT 12					; 12 unused colors
	.DW $FFFF
.ENDR



; -------------------------- Palette 4: red font
	.DW $0000				; unused color
	.DW $0C63				; font drop shadow (dark grey)
	.DW $0000				; unused color
	.DW $0C7F				; font (red)

.REPEAT 12					; 12 unused colors
	.DW $FFFF
.ENDR



; -------------------------- Palette 5: green font
	.DW $0000				; unused color
	.DW $0C63				; font drop shadow (dark grey)
	.DW $0000				; unused color
	.DW $0FE3				; font (green)

.REPEAT 12					; 12 unused colors
	.DW $FFFF
.ENDR



; -------------------------- Palette 6: blue font
	.DW $0000				; unused color
	.DW $0C63				; font drop shadow (dark grey)
	.DW $0000				; unused color
	.DW $7CE7				; font (blue)

.REPEAT 12					; 12 unused colors
	.DW $FFFF
.ENDR



; -------------------------- Palette 7: yellow font
	.DW $0000				; unused color
	.DW $0C63				; font drop shadow (dark grey)
	.DW $0000				; unused color
	.DW $0FFF				; font (yellow)

.REPEAT 12					; 12 unused colors
	.DW $FFFF
.ENDR



; ************************ Font character data *************************

Font:
	.INCBIN BG_FONT_2BPP			; font for both BG layers, to be "expanded" into VRAM



; *********************** Sprite character data ************************

; 16 KiB bytes total. All data is transferred to VRAM using a single DMA
; of $4000 bytes. The seemingly odd splitting allows efficient filling
; of the sprite buffer.

SpriteTiles:
	.INCBIN SPRITE_FONT_4BPP		; 4bpp sprite font (4 KiB)
	.INCBIN MAIN_GFX			; 8 KiB
	.INCBIN CURSOR_BUTTONS			; 2 KiB

	.INCBIN POWERPAK_SMALL	READ 256	; small PowerPak logo (2 KiB)
	.INCBIN POWERPAK_SMALL	SKIP 512	READ 256
	.INCBIN POWERPAK_SMALL	SKIP 256	READ 256
	.INCBIN POWERPAK_SMALL	SKIP 768	READ 256
	.INCBIN POWERPAK_SMALL	SKIP 1024	READ 256
	.INCBIN POWERPAK_SMALL	SKIP 1536	READ 256
	.INCBIN POWERPAK_SMALL	SKIP 1280	READ 256
	.INCBIN POWERPAK_SMALL	SKIP 1792	READ 256



; ******************************** EOF *********************************
