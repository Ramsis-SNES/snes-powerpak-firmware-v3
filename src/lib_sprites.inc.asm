;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2016 by ManuLöwe (http://manuloewe.de/)
;
;	*** SPRITE INITIALIZATION ***
;
;==========================================================================================



;------------------------------------------------------------------------
;-  Written by: Neviksti
;-     If you use my code, please share your creations with me
;-     as I am always curious :)
;------------------------------------------------------------------------



;.DEFINE sx		0
;.DEFINE sy		1
;.DEFINE sframe 		2
;.DEFINE spriority	3



SpriteInit:
	php	

	AccuIndex16

	ldx #$0000

__Init_OAM_lo:
	lda #$F0F0
	sta SpriteBuf1, x			; initialize all sprites to be off the screen

	inx
	inx

	lda #$0000
	sta SpriteBuf1, x

	inx
	inx
	cpx #$0200
	bne __Init_OAM_lo

	Accu8

	lda #%10101010				; large sprites for everything except the sprite font

	ldx #$0000

__Init_OAM_hi1:
	sta SpriteBuf2, x
	inx
	cpx #$0018				; see .STRUCT oam_high
	bne __Init_OAM_hi1

	lda #%00000000				; small sprites

__Init_OAM_hi2:
	sta SpriteBuf2, x
	inx
	cpx #$0020
	bne __Init_OAM_hi2

	;set the sprite to the highest priority
	;lda #$30
	;lda #%00110000
	;sta SpriteBuf1+spriority

	;lda #$00
	;sta SpriteBuf1+sframe

	lda #$80				; tile num for cursor, next is palette
	sta SpriteBuf1.Cursor+2

	lda #$03				; vhoopppc Vert Horiz priOrity Palette Charmsb
	sta SpriteBuf1.Cursor+3

	HideCursorSprite

	plp
rts



; ************************* Clearing functions *************************

; Added for v3.00 by ManuLöwe.

.ACCU 8
.INDEX 16

HideButtonSprites:				; this moves SNES joypad button sprites off the screen
	lda #$F0
	ldx #$0000

__Write2SpriteBufButtons:
	sta SpriteBuf1.Buttons, x		; X
	inx
	sta SpriteBuf1.Buttons, x		; Y
	inx
	inx					; skip tile num & tile properties
	inx
	cpx #$0030				; 48 bytes
	bne __Write2SpriteBufButtons
rts



HideLogoSprites:				; this moves main graphics sprites off the screen
	lda #%01010101
	ldx #$0000

__Write2SpriteBufMainGFX:
	sta SpriteBuf2.MainGFX, x
	inx
	cpx #$0010
	bne __Write2SpriteBufMainGFX
rts



; ******************************** EOF *********************************
