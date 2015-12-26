;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** SNES INITIALIZATION ***
;
;==========================================================================================



; ********************** Warm boot initialization **********************

; Added for v3.00 by ManuLöwe

.ACCU 8
.INDEX 16

WarmBootInit:
	phk					; set Data Bank = Program Bank
	plb

	rep #A_8BIT				; A = 16 bit

	lda #$0000				; set Direct Page = $0000
	tcd

	sep #A_8BIT				; A = 8 bit

	lda #$80				; enter forced blank
	sta $2100

	stz $420B				; disable DMA
	stz $420C				; disable HDMA

	stz DP_ColdBootCheck1			; clear warm boot constants
	stz DP_ColdBootCheck2
	stz DP_ColdBootCheck3
	stz VAR_ColdBootCheck4

	lda #$00
	sta.l VAR_ColdBootCheck5
	sta.l VAR_ColdBootCheck6
	sta.l VAR_ColdBootCheck7

	cli					; enable interrupts

	jsl apu_ram_init

	phk					; set data bank = program bank (needed as apu_ram_init sits in ROM bank 2)
	plb

	jsr SpriteInit				; reinitialize OAM
	jsr __WarmBootGFXsetup			; reinitialize GFX registers
	jsr JoyInit				; reinitialize joypads, enable NMI
rts



; ********************** Cold boot initialization **********************

InitSNES:
	phk					; set Data Bank = Program Bank
	plb

	rep #A_8BIT				; A = 16 bit

	lda #$0000				; set Direct Page = $0000
	tcd

	lda 1, s				; preserve return address (using a DMA register that won't get overwritten when WRAM is cleared)
	sta $4372

	sep #A_8BIT				; A = 8 bit



; -------------------------- initialize registers
	lda #$8F				; INIDISP (Display Control 1): forced blank
	sta $2100

	stz $2101				; regs $2101-$210C: set sprite, character, tile sizes to lowest, and set addresses to $0000
	stz $2102
	stz $2103

	; reg $2104: OAM data write

	stz $2105
	stz $2106
	stz $2107
	stz $2108
	stz $2109
	stz $210a
	stz $210b
	stz $210c
	stz $210d				; regs $210D-$2114: set all BG scroll values to $0000
	stz $210d
	stz $210e
	stz $210e
	stz $210f
	stz $210f
	stz $2110
	stz $2110
	stz $2111
	stz $2111
	stz $2112
	stz $2112
	stz $2113               
	stz $2113               
	stz $2114
	stz $2114

	lda #$80				; VRAM address increment mode: increment address by one word
	sta $2115				; after accessing the high byte ($2119)

	stz $2116				; regs $2116-$2117: VRAM address
	stz $2117

	; regs $2118-2119: VRAM data write

	stz $211a
	stz $211b				; regs $211B-$2120: Mode7 matrix values

	lda #$01
	sta $211b

	stz $211c
	stz $211c
	stz $211d
	stz $211d
	stz $211e       

	lda #$01
	sta $211e

	stz $211f
	stz $211f
	stz $2120
	stz $2120
	stz $2121

	; reg $2122: CGRAM data write

	stz $2123				; regs $2123-$2133: turn off windows, main screens, sub screens, color addition,
	stz $2124				; fixed color = $00, no super-impose (external synchronization), no interlace, normal resolution
	stz $2125
	stz $2126
	stz $2127
	stz $2128
	stz $2129
	stz $212a
	stz $212b
	stz $212c
	stz $212d
	stz $212e
	stz $212f

	lda #$30
	sta $2130

	stz $2131

	lda #$E0
	sta $2132

	stz $2133

	; regs $2134-$213F: PPU read registers, no initialization needed
	; regs $2140-$2143: APU communication regs, no initialization required

	; reg $2180: WRAM data read/write

	stz $2181				; regs $2181-$2183: WRAM address
	stz $2182
	stz $2183

	; regs $4016-$4017: serial JoyPad read registers, no need to initialize

	stz REG_NMITIMEN			; reg $4200: disable timers, NMI, and auto-joyread

	lda #$FF
	sta $4201				; reg $4201: programmable I/O write port, initalize to allow reading at in-port

	stz $4202				; regs $4202-$4203: multiplication registers
	stz $4203
	stz $4204				; regs $4204-$4206: division registers
	stz $4205
	stz $4206
	stz $4207				; regs $4207-$4208: Horizontal-IRQ timer setting
	stz $4208
	stz $4209				; regs $4209-$420A: Vertical-IRQ timer setting
	stz $420a
	stz $420b				; reg $420B: turn off all general DMA channels
	stz $420c				; reg $420C: turn off all HDMA channels
	stz $420d				; reg $420D: ROM access time to slow (2.68Mhz)

;	lda #$01				; reg $420D: set Memory-2 area to 3.58 MHz (FastROM)
;	sta $420D

	; regs $420E-$420F: unused registers
	; reg $4210: RDNMI (R)
	; reg $4211: IRQ status, no need to initialize
	; reg $4212: H/V blank and JoyRead status, no need to initialize
	; reg $4213: programmable I/O inport, no need to initialize
	; regs $4214-$4215: divide results, no need to initialize
	; regs $4216-$4217: multiplication or remainder results, no need to initialize
	; regs $4218-$421f: JoyPad read registers, no need to initialize

	; regs $4300-$437F: DMA/HDMA parameters, unused registers



; -------------------------- clear all directly accessible RAM areas (with parameters/addresses set/reset above)
	DMA_CH0 $09, :CONST_Zeroes, CONST_Zeroes, $18, 0	; VRAM (length $0000 = 65536 bytes)
	DMA_CH0 $08, :CONST_Zeroes, CONST_Zeroes, $22, 512	; CGRAM (512 bytes)
	DMA_CH0 $08, :CONST_Zeroes, CONST_Zeroes, $04, 512+32	; OAM (low+high OAM tables = 512+32 bytes)
	DMA_CH0 $08, :CONST_Zeroes, CONST_Zeroes, $80, 0	; WRAM (length $0000 = 65536 bytes = lower 64K of WRAM)

	lda #%00000001				; WRAM address in $2181-$2183 has reached $10000 now,
	sta $420B				; so re-initiate DMA transfer for the upper 64K of WRAM

	cli					; enable interrupts

	rep #A_8BIT				; A = 16 bit

	lda $4372				; restore return address
	sta 1, s

	sep #A_8BIT				; A = 8 bit
rts



; ******************************** EOF *********************************
