;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2016 by ManuLöwe (http://manuloewe.de/)
;
;	*** PRINT HANDLER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;	- Neviksti (subroutines ??), (c) 2002
;
;==========================================================================================



; ********************* String processing function *********************

;PrintF -- Print a formatted, NUL-terminated string to Stdout
;In:   X -- points to format string
;      Y -- points to parameter buffer
;Out: none
;Modifies: none
;Notes:
;     Supported Format characters:
;       %s -- sub-string (reads 16-bit pointer from Y data)
;       %d -- 16-bit Integer (reads 16-bit data from Y data)
;       %b -- 8-bit Integer (reads 8-bit data from Y data)
;       %x -- 8-bit hex Integer (reads 8-bit data from Y data)
;       %% -- normal %
;       \n -- Newline
;       \t -- Tab
;       \\ -- normal slash
;     String pointers all refer to current Data Bank (DB)

PrintF:
	plx								; pull return address (-1) from stack, which is actually the string address (-1)
	inx								; make X = start of string

PrintFStart:
	php								; preserve processor status

	Accu8
	Index16

PrintFLoop:
	lda	$0000,X							; read next format string character
	beq	PrintFDone						; check for NUL terminator
	INX								; increment input pointer
	cmp	#'%'
	beq	PrintFFormat						; handle format character
	cmp	#'\'
	beq	PrintFControl						; handle control character

NormalPrint:
	jsr	FillTextBuffer						; print the character on BG1/2
	bra	PrintFLoop

PrintFDone:
	plp								; restore processor status
	phx								; push return address (-1) onto stack (X now points to NUL terminator)
	rts



PrintFControl:
	lda	$0000,X							; read control character
	beq	PrintFDone						; check for NUL terminator
	INX								; increment input pointer
	cmp	#'n'
_cn:	bne	_ct

	AccuIndex16

	lda	Cursor							; get current position
	CLC
	adc	#$0020							; move to the next line
	and	#$FFE0
	ora	#minPrintX						; add horizontal indention
	sta	Cursor							; save new position

	Accu8

	stz	BGPrintMon						; reset BG monitor value
	bra	PrintFLoop
_ct:	cmp	#'t'
	bne	_defaultC

	AccuIndex16

	lda	Cursor							; get current position
	CLC
;	adc	#$0008							; move to the next tab
;	and	#$FFF8
	adc	#$0004							; smaller tab size (4 tiles = 8 hi-res characters)
	and	#$fffc
;	adc	#$0002							; use this instead for even smaller tabs
;	and	#$fffe
	sta	Cursor							; save new position

	Accu8

	stz	BGPrintMon						; reset BG monitor value
	bra	PrintFLoop
_defaultC:
	lda	#'\'							; normal backslash
	bra	NormalPrint

PrintFFormat:
	lda	$0000,X							; read format character
	beq	PrintFDone						; check for NUL terminator
	INX								; increment input pointer
_sf:	cmp	#'s'
	bne	_df
	PHX								; preserve current format string pointer
	ldx	0,Y							; load sub-string pointer
	INY
	INY
	jsr	PrintSubstring						; print sub-string
	PLX
	bra	PrintFLoop
_df:	cmp	#'d'
	bne	_bf
	jsr	PrintInt16						; print 16-bit integer
	bra	PrintFLoop
_bf:	cmp	#'b'
	bne	_xf
	jsr	PrintInt8						; print 8-bit integer
	bra	PrintFLoop
_xf:	cmp	#'x'
	bne	_defaultF
	jsr	PrintHex8						; print 8-bit hex integer
	bra	PrintFLoop
_defaultF:
	lda	#'%'
	bra	NormalPrint



PrintSubstring:
	lda	$0000,X							; read next format string character
	beq	__PrintSubstringDone					; check for NUL terminator
	INX								; increment input pointer

	jsr	FillTextBuffer						; print the character on BG1/2
	bra	PrintSubstring

__PrintSubstringDone:
	rts



; ************************** Fill text buffer **************************

; This alternately writes doubled values of ASCII characters to the
; BG1/BG2 text buffer while keeping track of which BG to use next via
; the BGPrintMon variable (start = $00 = BG1, $01 = BG2).

; The ASCII values need to be doubled because both fonts have empty 8x8
; tiles before or after each character. By not advancing the text cursor
; position when using BG1, all of this makes it possible to work around
; Mode 5's 16×8 tile size limitation, with the main drawback that the
; text engine uses up both available BG layers.

; In: A -- ASCII code to print
; Out: none
; Modifies: P



FillTextBuffer:								; expectations: A = 8 bit, X/Y = 16 bit
	pha
	lda	BGPrintMon
	bne	__FillTextBufferBG2					; if BG monitor value is not zero, use BG2

__FillTextBufferBG1:
	inc	BGPrintMon						; otherwise, change value and use BG1

	pla
	phx

	ldx	Cursor

	asl	a							; character code * 2 so it matches hi-res font tile location
	sta	TextBuffer.BG1, x					; write it to the BG1 text buffer

	bra	__FillTextBufferDone					; ... and done

__FillTextBufferBG2:
	stz	BGPrintMon						; reset BG monitor value

	pla
	phx

	ldx	Cursor

	asl	a							; character code * 2
	sta	TextBuffer.BG2, x					; write it to the BG2 text buffer
	inx								; ... and advance text cursor position
	stx	Cursor

__FillTextBufferDone:
	plx
	rts



; *********************** Sprite-based printing ************************

; Added for v3.00 by ManuLöwe.

; A very basic sprite-based font renderer that allows us to print
; messages in window-masked areas (e.g., above/below a file listing).
; Caveat #1: Max. length of message(s) is 32 characters at a time.
; Caveat #2: No control characters, but I added a VWF mechanism to
; compensate. My very first one, actually. And it works! :D

PrintSpriteText:
	plx								; pull return address (-1) from stack, which is actually the string address (-1)
	inx								; make X = start of string

	php								; preserve processor status

	Accu8
	Index16

	ldy	DP_SprTextMon						; start where there is some unused sprite text buffer

__PrintSpriteTextLoop:
	lda	$0000,X							; read next string character
	beq	__PrintSpriteTextDone					; check for NUL terminator
	INX								; increment input pointer

	phx								; preserve input pointer
	pha								; preserve ASCII value

	Accu16

	and	#$00FF							; mask off whatever is stored in B
	tax

	Accu8

	lda	Cursor
	sta	SpriteBuf1.Text, y					; X position

	clc
	adc.l	SpriteFWT, x						; advance cursor position as per font width table entry
	sta	Cursor

	iny

	lda	Cursor+1
	sta	SpriteBuf1.Text, y					; Y position

	iny

	pla								; restore ASCII value
	plx								; restore input pointer

;	clc
;	adc	#$40							; tile num offset (relative to ASCII char value)
	sta	SpriteBuf1.Text, y					; tile num = ASCII value

	iny

	lda	DP_SprTextPalette
	asl	a							; shift palette num to bit 1-3
;	ora	#$01							; add upper 1 bit to tile num
	sta	SpriteBuf1.Text, y					; tile attributes

	iny
	cpy	#$0080							; if sprite buffer is full, reset
	bcc	+

	ldy	#$0000
+	sty	DP_SprTextMon						; keep track of sprite text buffer filling level

	bra	__PrintSpriteTextLoop

__PrintSpriteTextDone:
	plp								; restore processor status
	phx								; push return address onto stack (X now points to end of string)
	rts



; ******************** Number processing functions *********************

;PrintInt16 -- Read a 16-bit value pointed to by Y and print it to stdout
;In:  Y -- Points to integer in current data bank
;Out: Y=Y+2
;Modifies: P
;Notes: Uses Print to output ASCII to stdout

PrintInt16:								; assumes 8b mem, 16b index
	lda	#$00
	PHA								; push $00
	lda	$0000,Y
	sta	$4204							; DIVC.l
	lda	$0001,Y
	sta	$4205							; DIVC.h  ... DIVC = [Y]
	INY
	INY

DivLoop:
	lda	#$0A	
	sta	$4206							; DIVB = 10 --- division starts here (need to wait 16 cycles)
	NOP								; 2 cycles
	NOP								; 2 cycles
	NOP								; 2 cycles
	PHA								; 3 cycles
	PLA								; 4 cycles
	lda	#'0'							; 2 cycles
	CLC								; 2 cycles
	adc	$4216							; A = '0' + DIVC % DIVB
	PHA								; push character
	lda	$4214							; Result.l -> DIVC.l
	sta	$4204
	beq	_Low_0
	lda	$4215							; Result.h -> DIVC.h
	sta	$4205
	bra	DivLoop

_Low_0:
	lda	$4215							; Result.h -> DIVC.h
	sta	$4205
	beq	IntPrintLoop						; if ((Result.l==$00) and (Result.h==$00)) then we're done, so print
	bra	DivLoop

IntPrintLoop:								; until we get to the end of the string...
	PLA								; keep pulling characters and printing them
	beq	_EndOfInt
	jsr	FillTextBuffer						; write them to the text buffer
	bra	IntPrintLoop

_EndOfInt:
	rts



;PrintInt8 -- Read an 8-bit value pointed to by Y and print it to stdout
;In:  Y -- Points to integer in current data bank
;Out: Y=Y+1
;Modifies: P
;Notes: Uses Print to output ASCII to stdout

PrintInt8:								; assumes 8b mem, 16b index
	lda	$0000,Y
	INY

PrintInt8_noload:
	sta	$4204
	lda	#$00
	sta	$4205
	PHA
	bra	DivLoop

PrintInt16_noload:							; assumes 8b mem, 16b index
	lda	#$00
	PHA								; push $00
	stx	$4204							; DIVC = X
	jsr	DivLoop



;PrintHex8 -- Read an 8-bit value pointed to by Y and print it in hex to stdout
;In:  Y -- Points to integer in current data bank
;Out: Y=Y+1
;Modifies: P
;Notes: Uses Print to output ASCII to stdout

PrintHex8:								; assumes 8b mem, 16b index
	lda	$0000,Y
	iny

PrintHex8_noload:
	pha
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	jsr	PrintHexNibble
	pla
	and	#$0F
	jsr	PrintHexNibble
	rts	

PrintHexNibble:								; assumes 8b mem, 16b index
	cmp	#$0A
	bcs	_nletter
	clc
	adc	#'0'
	jsr	FillTextBuffer						; write it to the text buffer
	rts

_nletter: 	
	clc
	adc	#'A'-10		
	jsr	FillTextBuffer						; write it to the text buffer
	rts



; ************************* Clearing functions *************************

PrintClearLine:
	pha								; A = number of line to clear
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	sta	Cursor

	pla
	lsr	a
	lsr	a
	lsr	a
	sta	Cursor+1

	ldx	Cursor
	ldy	#$0000
	lda	#$40							; space (hi-res tile number)

-	sta	TextBuffer.BG1, x					; clear BG1 text buffer
	sta	TextBuffer.BG2, x					; clear BG2 text buffer
	inx
	iny
	cpy	#$0020							; $20 chars = one "line"
	bne	-

	rts



PrintClearScreen:
	Accu16

	lda	#$4040							; overwrite 2 tiles at once ($40 = space)
	ldx	#$0000

-	sta	TextBuffer.BG1, x
	sta	TextBuffer.BG2, x
	inx
	inx
	cpx	#$0400							; 1024 bytes (lower 32×32 tilemaps only)
	bne	-

	Accu8

	stz	cursorYCounter						; reset scrolling parameters
	stz	cursorYUp
	stz	cursorYDown

	stz	scrollY
	stz	scrollYCounter
	stz	scrollYUp
	stz	scrollYDown

ClearSpriteText:
	Accu16

	lda	#$F0F0
	ldy	#$0000

-	sta	SpriteBuf1.Text, y					; Y, X
	iny
	iny
	iny
	iny
	cpy	#$0080							; 128 / 4 = 32 tiles
	bne	-

	stz	DP_SprTextMon						; reset filling level

	Accu8

	rts



; ******************************** EOF *********************************
