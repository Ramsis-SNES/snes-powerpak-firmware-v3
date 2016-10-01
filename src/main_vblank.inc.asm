;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2016 by ManuLöwe (http://manuloewe.de/)
;
;	*** VBLANK NMI HANDLER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



; **************************** NMI routine *****************************

VBlank:
	AccuIndex16

	pha								; preserve 16 bit registers
	phx
	phy
	phk								; set Data Bank = Program Bank
	plb
	lda	temp+6							; push temp variables on the stack (used in scrolling routines)
	pha
	lda	temp+4
	pha
	lda	temp+2
	pha
	lda	temp
	pha

	Accu8



; -------------------------- do scrolling
	lda	cursorYCounter						; check cursor counter, no scroll if counter=0
	beq	__CursorCheckDone
	dec	cursorYCounter
	lda	cursorY							; cursorY = cursorY - cursorYUp + cursorYDown
	sec
	sbc	cursorYUp
	clc
	adc	cursorYDown
	sta	cursorY

__CursorCheckDone:
	lda	scrollYCounter						; check scroll counter, no scroll if counter=0
	beq	__DoYScrollDone
	dec	scrollYCounter
	lda	scrollY							; scrollY = scrollY - scrollYUp + scrollYDown
	sec
	sbc	scrollYUp
	clc
	adc	scrollYDown
	sta	scrollY

__DoYScrollDone:



; -------------------------- move cursor
	lda	cursorX
	sta	SpriteBuf1.Cursor
	lda	cursorY
	sec
	sbc	#$10
	; clc
	; adc	#$08
	sta	SpriteBuf1.Cursor+1



; -------------------------- refresh sprites
	stz	$2102							; reset OAM address
	stz	$2103

	; DMA parameters:
	; Mode: $00, CPU -> PPU, auto increment, write 1 byte
	; source bank: $00 (lower 8K of WRAM)
	; source offset: SpriteBuf1
	; B bus register: $2104 (OAM data write)
	; number of bytes to transfer: 512 + 32 (OAM size)

	DMA_CH0 $00, $00, SpriteBuf1, $04, 544



; -------------------------- refresh BG1
	lda	#$00							; VRAM address increment mode: increment address by one word
	sta	$2115							; after accessing the low byte ($2118)
	ldx	#ADDR_VRAM_BG1_TILEMAP					; set VRAM address to BG1 tile map
	stx	$2116

	; DMA parameters:
	; Mode: $00, CPU -> PPU, auto increment, write 1 byte
	; source bank: $7E (WRAM)
	; source offset: TextBuffer.BG1 (get lower 16 bit)
	; B bus register: $2118 (VRAM low byte)
	; number of bytes to transfer: 2048 (tile map size)

	DMA_CH0 $00, $7E, (TextBuffer.BG1 & $FFFF), $18, 2048



; -------------------------- refresh BG2
	lda	#$00							; VRAM address increment mode: increment address by one word
	sta	$2115							; after accessing the low byte ($2118)
	ldx	#ADDR_VRAM_BG2_TILEMAP					; set VRAM address to BG2 tile map
	stx	$2116

	; DMA parameters:
	; Mode: $00, CPU -> PPU, auto increment, write 1 byte
	; source bank: $7E (WRAM)
	; source offset: TextBuffer.BG2 (get lower 16 bit)
	; B bus register: $2118 (VRAM low byte)
	; number of bytes to transfer: 2048 (tile map size)

	DMA_CH0 $00, $7E, (TextBuffer.BG2 & $FFFF), $18, 2048



; -------------------------- misc. tasks
	jsr	GetInput
	lda	scrollY
	sta	$210E							; BG1 vertical scroll
	stz	$210E
	sta	$2110							; BG2 vertical scroll
	stz	$2110
	lda	DP_HDMAchannels						; initiate HDMA transfers
	and	#%11111100						; make sure channels 0, 1 (reserved for normal DMA) aren't used
	sta	$420C
	lda	REG_RDNMI						; clear NMI flag (just to be sure)

	AccuIndex16

	pla								; restore temp variables
	sta	temp
	pla
	sta	temp+2
	pla
	sta	temp+4
	pla
	sta	temp+6
	ply								; restore 16 bit registers
	plx
	pla
rti



; ******************************** EOF *********************************
