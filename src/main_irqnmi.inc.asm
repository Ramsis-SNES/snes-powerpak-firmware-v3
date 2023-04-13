;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** VBLANK NMI HANDLER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;	- Neviksti (GetInput subroutine)
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
	pei	(temp+6)						; push temp variables on the stack (used in scrolling routines)
	pei	(temp+4)
	pei	(temp+2)
	pei	(temp)

	Accu8



; -------------------------- do scrolling
	lda	cursorYCounter						; check cursor counter, no scroll if counter=0
	beq	@CursorCheckDone
	dec	cursorYCounter
	lda	cursorY							; cursorY = cursorY - cursorYUp + cursorYDown
	sec
	sbc	cursorYUp
	clc
	adc	cursorYDown
	sta	cursorY

@CursorCheckDone:
	lda	scrollYCounter						; check scroll counter, no scroll if counter=0
	beq	@DoYScrollDone
	dec	scrollYCounter
	lda	scrollY							; scrollY = scrollY - scrollYUp + scrollYDown
	sec
	sbc	scrollYUp
	clc
	adc	scrollYDown
	sta	scrollY

@DoYScrollDone:



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
	stz	REG_OAMADDL						; reset OAM address
	stz	REG_OAMADDH

	; DMA parameters:
	; Mode: $00, CPU -> PPU, auto increment, write 1 byte
	; source bank: $00 (lower 8K of WRAM)
	; source offset: SpriteBuf1
	; B bus register: $2104 (OAM data write)
	; number of bytes to transfer: 512 + 32 (OAM size)

	DMA_CH0 $00, SpriteBuf1, <REG_OAMDATA, 544



; -------------------------- refresh BG1
	stz	REG_VMAIN						; VRAM address increment mode: increment address by one word after accessing the low byte ($2118)
	ldx	#ADDR_VRAM_BG1_TILEMAP					; set VRAM address to BG1 tile map
	stx	REG_VMADDL

	; DMA parameters:
	; Mode: $00, CPU -> PPU, auto increment, write 1 byte
	; source bank: $7E (WRAM)
	; source offset: TextBuffer.BG1 (get lower 16 bit)
	; B bus register: $2118 (VRAM low byte)
	; number of bytes to transfer: 2048 (tile map size)

	DMA_CH0 $00, TextBuffer.BG1, <REG_VMDATAL, 2048



; -------------------------- refresh BG2
	ldx	#ADDR_VRAM_BG2_TILEMAP					; set VRAM address to BG2 tile map
	stx	REG_VMADDL

	; DMA parameters:
	; Mode: $00, CPU -> PPU, auto increment, write 1 byte
	; source bank: $7E (WRAM)
	; source offset: TextBuffer.BG2 (get lower 16 bit)
	; B bus register: $2118 (VRAM low byte)
	; number of bytes to transfer: 2048 (tile map size)

	DMA_CH0 $00, TextBuffer.BG2, <REG_VMDATAL, 2048



; -------------------------- misc. tasks
	jsr	GetInput

	lda	scrollY
	sta	REG_BG1VOFS						; BG1 vertical scroll
	stz	REG_BG1VOFS
	sta	REG_BG2VOFS						; BG2 vertical scroll
	stz	REG_BG2VOFS
	lda	DP_HDMAchannels						; initiate HDMA transfers
	and	#%11111100						; make sure channels 0, 1 (reserved for normal DMA) aren't used
	sta	REG_HDMAEN
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



; **************************** Subroutines *****************************

.ACCU 8

GetInput:
	lda	#$01

@W1:	bit	REG_HVBJOY
	bne	@W1							; wait till automatic JoyPort read is complete

	AccuIndex16

; ********** get Joypads 1, 2

	lda	Joy1
	sta	Joy1Old
	lda	REG_JOY1L						; get JoyPad1
	tax
	eor	Joy1							; A = A xor JoyState = (changes in joy state)
	stx	Joy1							; update JoyState
	ora	Joy1Press						; A = (joy changes) or (buttons pressed)
	and	Joy1							; A = ((joy changes) or (buttons pressed)) and (current joy state)
	sta	Joy1Press						; store A = (buttons pressed since last clearing reg) and (button is still down)
	lda	REG_JOY2L						; get JoyPad2
	tax
	eor	Joy2							; A = A xor JoyState = (changes in joy state)
	stx	Joy2							; update JoyState
	ora	Joy2Press						; A = (joy changes) or (buttons pressed)
	and	Joy2							; A = ((joy changes) or (buttons pressed)) and (current joy state)
	sta	Joy2Press						; store A = (buttons pressed since last clearing reg) and (button is still down)
	lda	Joy1Old
	eor	#$FFFF
	and	Joy1
	sta	Joy1New

; ********** make sure Joypads 1, 2 are valid

	AccuIndex8

	lda	REG_JOYA
	eor	#$01
	and	#$01							; A = -bit0 of JOYA
	ora	Joy1
	sta	Joy1							; joy state = (joy state) or A.... so bit0 of Joy1State = 0 only if it is a valid joypad
	lda	REG_JOYB
	eor	#$01
	and	#$01							; A = -bit0 of JOYB
	ora	Joy2
	sta	Joy2							; joy state = (joy state) or A.... so bit0 of Joy1State = 0 only if it is a valid joypad

; ********** change all invalid joypads to have a state of no button presses

	AccuIndex16

	ldx	#$0001
	lda	#$000F
	bit	Joy1							; A = joy state, if any of the bottom 4 bits are on... either nothing is plugged
	beq	@joy2							; into the joy port, or it is not a joypad
	stx	Joy1							; if it is not a valid joypad put $0001 into the 2 joy state variables
	stz	Joy1Press

@joy2:
	bit	Joy2							; A = joy state, if any of the bottom 4 bits are on... either nothing is plugged
	beq	@done							; into the joy port, or it is not a joypad
	stx	Joy2							; if it is not a valid joypad put $0001 into the 2 joy state variables
	stz	Joy2Press

@done:
	Accu8

	rts



; **************************** IRQ routines ****************************

ErrorHandlerBRK:
	AccuIndex16

	pha
	phx
	phy

	Accu8

	lda	#$80							; enter forced blank
	sta	REG_INIDISP
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	stz	REG_HDMAEN						; disable HDMA
	stz	DP_HDMAchannels
	stz	REG_CGADD						; reset CGRAM address
	stz	REG_CGDATA						; set mainscreen bg color: blue
	lda	#$70
	sta	REG_CGDATA
	jsr	PrintClearScreen
	jsr	HideButtonSprites
	jsr	HideLogoSprites

	PrintSpriteText	4, 4, "An error occurred!", 3
	SetTextPos	4, 2
	PrintString	"Error type: BRK"

	bra	ErrorHandlerCOP@PrintDebugInfo				; rest is the same as in COP error handling



ErrorHandlerCOP:
	AccuIndex16

	pha
	phx
	phy

	Accu8

	lda	#$80							; enter forced blank
	sta	REG_INIDISP
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	stz	REG_HDMAEN						; disable HDMA
	stz	DP_HDMAchannels
	stz	REG_CGADD						; reset CGRAM address
	lda	#$1C							; set mainscreen bg color: red
	sta	REG_CGDATA
	stz	REG_CGDATA
	jsr	PrintClearScreen
	jsr	HideButtonSprites
	jsr	HideLogoSprites

	PrintSpriteText	4, 4, "An error occurred!", 3
	SetTextPos	4, 2
	PrintString	"Error type: COP"

@PrintDebugInfo:
	SetTextPos	5, 2
	PrintString	"Error addr: $"

	lda	10, s
	sta	temp+2							; put address in temp+2/temp+1/temp

	PrintHexNum	temp+2

	lda	9, s
	sta	temp+1

	PrintHexNum	temp+1

	lda	8, s
	dec	a							; make up for automatic program counter increment
	dec	a
	sta	temp

	PrintHexNum	temp

	inc	temp							; advance low byte to address of BRK/COP signature byte
	lda	[temp]							; load signature byte from [temp]
	sta	temp+4

	SetTextPos	7, 2
	PrintString	"BRK/COP signature byte: $"
	PrintHexNum	temp+4
	SetTextPos	9, 2
	PrintString	"Status reg: $"

	lda	7, s
	sta	temp

	PrintHexNum	temp
	SetTextPos	11, 2
	PrintString	"Accumulator: $"

	lda	6, s
	sta	temp

	PrintHexNum	temp

	lda	5, s
	sta	temp

	PrintHexNum	temp
	SetTextPos	12, 2
	PrintString	"X index reg: $"

	lda	4, s
	sta	temp

	PrintHexNum	temp

	lda	3, s
	sta	temp

	PrintHexNum	temp
	SetTextPos	13, 2
	PrintString	"Y index reg: $"

	lda	2, s
	sta	temp

	PrintHexNum	temp

	lda	1, s
	sta	temp

	PrintHexNum	temp

	lda	#%00100000						; activate HDMA channel 5 (windowing)
	sta	DP_HDMAchannels
	lda	REG_RDNMI						; clear NMI flag
	jmp	Forever@SkipHDMA					; go to trap loop instead of RTI (omitting HDMA stuff)



; ******************************** EOF *********************************
