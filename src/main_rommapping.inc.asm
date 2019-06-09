;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: ROM MAPPING ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.ACCU 8
.INDEX 16

StartGame:
	jsr	SpriteInit						; purge OAM
	jsr	PrintClearScreen

;	SetTextPos 27, 1
;	PrintString "FPGA STATUS = "

;	lda	CONFIGREADSTATUS
;	sta	errorCode

;	PrintHexNum errorCode

	ldx	#$0000							; clear gameBanks variable in case it was written to before (i.e. by a failed ROM loading attempt)
-	stz	gameBanks, x
	inx
	cpx	#$0020
	bne	-

	lda	#$DC							; $40FFDC = location of ExHiROM checksum complement
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$40
	sta	DMAWRITEBANK
	stz	DMAREADDATA						; zero out checksum & complement in case an ExHiROM game was played before
	stz	DMAREADDATA
	stz	DMAREADDATA
	stz	DMAREADDATA



; -------------------------- ROM loading
	SetTextPos 1, 0

	lda	gameName.Flags						; load copier header/ROM mapping flags
	and	#%10000011						; mask off unused bits just in case
	sta	fixheader
	bpl	+							; acknowledge "copier header present" flag

	PrintString "Copier header detected\n"
+ 	PrintString "Loading game ..."

	wai
	lda	#$00							; read file to beginning of SDRAM
	sta	DMAWRITELO
	sta	DMAWRITEHI
	sta	DMAWRITEBANK
	jsr	CardReadGameFill

	ldy	#gameSize						; print ROM sectors in decimal ### FIXME add FAT32 excess cluster mask

	PrintString "\nLoaded %d sectors = "

	lda	gameSize+1
	sta	gameROMMbits
	ldy	#gameROMMbits

	PrintString "%b Mbit"

FixMbits:
	lda	gameROMMbits
	cmp	#9
	beq	@Fix9or10Mbits
	cmp	#10
	bne	@FixMbitsDone

@Fix9or10Mbits:								; ROM size fix, change 9 or 10 Mbits to 12 Mbits
	lda	#12
	sta	gameROMMbits

@FixMbitsDone:



; -------------------------- SRAM loading
LoadSave:
	PrintString "\nChecking savegame ... "
	Accu16

	lda	saveName.Cluster
	bne	@LoadSaveStart
	lda	saveName.Cluster+2
	bne	@LoadSaveStart

	Accu8
	PrintString "no SRAM file found."

	jmp	@LoadSaveDone

.ACCU 16

@LoadSaveStart:
	lda	saveName.Cluster
	sta	sourceCluster
	lda	saveName.Cluster+2
	sta	sourceCluster+2

	Accu8

	lda	#$F8							; load SRAM to SDRAM location $F80000
	sta	DMAWRITEBANK
	lda	#$00
	sta	DMAWRITELO
	sta	DMAWRITEHI
	stz	sectorCounter
	stz	bankCounter
	lda	#kSDRAM
	sta	DP_DataDestination
	jsr	CardReadFile

	ldy	#gameSize						; print SRAM sectors in decimal

	PrintString "present, loaded %d sectors = "

	lsr	gameSize+1						; KiB = sectors / 2
	ror	gameSize
	ldy	#gameSize

	PrintString "%b KB"

@LoadSaveDone:



; -------------------------- determine ROM type
	lda	fixheader

	Accu16

	and	#$0003							; only keep the 2 lowest bits (ROM mapping flags)
	asl	a
	tax

	Accu8

	jmp	(PTR_CheckInternalHeader, x)

PTR_CheckInternalHeader:
	.DW CheckInternalHeader						; if no ROM mapping flags are set at all, continue normally
	.DW CheckInternalHeader@ForceLoROM				; bit 0 set --> force LoROM
	.DW CheckInternalHeader@ForceHiROM				; bit 1 set --> force HiROM
	.DW CheckInternalHeader@ForceExHiROM				; both bits set --> force ExHiROM



CheckInternalHeader:

@ExHiROM:
	lda	#$DC							; $40FFDC = location of checksum complement
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$40
	sta	DMAWRITEBANK
	lda	DMAREADDATA						; read  checksum complement
	sta	temp
	lda	DMAREADDATA
	sta	temp+1
	lda	DMAREADDATA						; read  checksum
	sta	temp+2
	lda	DMAREADDATA
	sta	temp+3

	Accu16

	lda	temp+2							; check if checksum & complement match
	eor	#$FFFF
	cmp	temp
	bne	@NotExHiROM

	Accu8

@IsExHiROM:
	lda	#$C0							; ROM is ExHiROM, copy internal header (all known games with a matching checksum & complement at $40FFDC are ExHiROM, so no header sanity checks needed at this point)
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$40
	sta	DMAWRITEBANK
	jsr	CopyROMInfo

	PrintString "\n$40FFC0 header valid"

	bra	+

@ForceExHiROM:
	lda	#$C0							; ROM is treated as ExHiROM, copy internal header
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$40
	sta	DMAWRITEBANK
	jsr	CopyROMInfo

	PrintString "\n$40FFC0 header forced"

+	lda	#%00000011						; set ExHiROM mapping flags
	tsb	fixheader
	lda	gameROMMapper
	and	#$F0							; discard mapping bits
	ora	#$05							; set ExHiROM mapping (lower nibble = 5)
	sta	gameROMMapper
	jmp	InternalHeaderDone

@NotExHiROM:
	Accu8
	PrintString "\n$40FFC0 header invalid, checking $FFC0 instead ..."

@HiROM:
	lda	#$DC							; $00FFDC = location of checksum complement
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	lda	DMAREADDATA						; read  checksum complement
	sta	temp
	lda	DMAREADDATA
	sta	temp+1
	lda	DMAREADDATA						; read  checksum
	sta	temp+2
	lda	DMAREADDATA
	sta	temp+3

	Accu16

	lda	temp+2							; check if checksum & complement match
	eor	#$FFFF
	cmp	temp
	beq	@IsHiROM

	Accu8

	jmp	@NotHiROM

@IsHiROM:
	Accu8

	lda	#$C0							; ROM seems to be HiROM, copy internal header
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	jsr	CopyROMInfo

	PrintString "\n$FFC0 header found, checking sanity ..."		; this is necessary as some LoROM games (notably Return of Double Dragon aka Super Double Dragon) have two internal headers (at both $FFC0 and $7FC0)

	lda	gameROMMapper
	and	#$0F							; mask off upper nibble (ROM speed)
	cmp	#$01
	bne	@NotHiROM

	lda	gameROMType
	cmp	#$06							; ROM type must be <= 5
	bcs	@NotHiROM

;	lda	#$40
;	cmp	gameROMMbits						; ROM size <= 64Mbits // whoa, what? HiROM games are 32 Mbit max. ??
;	bcc	@NotHiROM

	lda	#$08
	cmp	saveSize						; SRAM size <= 8d
	bcc	@NotHiROM

	lda	gameResetVector+1
	cmp	#$80							; reset vector goes to >= 8000
	bcs	@ValidHiROM
	bra	@NotHiROM

@ForceHiROM:
	lda	#$C0							; ROM is treated as HiROM, copy internal header
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	jsr	CopyROMInfo

	PrintString "\n$FFC0 header forced"

	bra	+

@ValidHiROM:
	PrintString "\n$FFC0 header valid"

+	lda	#%00000010						; make sure HiROM mapping flag is set
	tsb	fixheader
	lda	gameROMMapper
	and	#$F0							; discard mapping bits
	ora	#$01							; set HiROM mapping (lower nibble = 1)
	sta	gameROMMapper
	jmp	InternalHeaderDone

@NotHiROM:
	PrintString "\n$FFC0 header invalid, checking $7FC0 instead ..."

@LoROM:
	lda	#$DC							; $007FDC = location of checksum complement
	sta	DMAWRITELO
	lda	#$7F
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	lda	DMAREADDATA						; read  checksum complement
	sta	temp
	lda	DMAREADDATA
	sta	temp+1
	lda	DMAREADDATA						; read  checksum
	sta	temp+2
	lda	DMAREADDATA
	sta	temp+3

	Accu16

	lda	temp+2							; check if checksum & complement match
	eor	#$FFFF
	cmp	temp
	beq	@IsLoROM
	jmp	@NotLoROM

@IsLoROM:
	Accu8

	lda	#$C0							; ROM is LoROM, copy internal header
	sta	DMAWRITELO
	lda	#$7F
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	jsr	CopyROMInfo

	PrintString "\n$7FC0 header found, checking sanity ..."		; for good measure

	lda	gameROMMbits
	cmp	#$60							; check for 96 Mbit ROM first
	beq	@96MbitLoROM

	lda	gameROMMapper
	and	#$0F							; mask off upper nibble (ROM speed)
	beq	+							; lower nibble must be zero for LoROM
	jmp	@NotLoROM

+	lda	gameROMType
	cmp	#$06							; ROM type must be <= 5
	bcs	@NotLoROM

	lda	#$20
	cmp	gameROMMbits						; ROM size <= 32Mbits
	bcc	@NotLoROM

	lda	#$08
	cmp	saveSize						; SRAM size <= 8d
	bcc	@NotLoROM

	lda	gameResetVector+1
	cmp	#$80							; reset vector goes to >= 8000
	bcs	@ValidLoROM
	bra	@NotLoROM

@ForceLoROM:
	lda	#$C0							; ROM is treated as LoROM, copy internal header
	sta	DMAWRITELO
	lda	#$7F
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	jsr	CopyROMInfo

	PrintString "\n$7FC0 header forced"

	bra	+

@ValidLoROM:
	PrintString "\n$7FC0 header valid"

+	lda	#%00000001						; make sure LoROM mapping flag is set
	tsb	fixheader
	lda	gameROMMapper
	and	#$F0							; discard mapping bits
	sta	gameROMMapper						; set LoROM mapping (lower nibble = 0)
	jmp	InternalHeaderDone

@96MbitLoROM:
	PrintString "\n96 Mbit ROM"

	jmp	InternalHeaderDone

@NotLoROM:
	Accu8
	PrintString "\n$7FC0 header invalid!\n\nPress any button ..."
	WaitForUserInput



NoInternalHeader:
	jsr	PrintClearScreen

	DrawFrame 0, 11, 31, 9

	lda	#92							; patch HDMA table in WRAM with scanline values matching the questions "window" border
	sta	HDMAtable.ColorMath+0
	lda	#70
	sta	HDMAtable.ColorMath+3
	lda	#%00001000						; enable color math channel
	tsb	DP_HDMAchannels

	SetTextPos 11, 0
	PrintString "No internal header found, please select ROM mapping\nmanually:"
	SetTextPos 14, 1
	PrintString "LoROM/ExLoROM\n  HiROM\n  ExHiROM"

	lda	#cursorXmapping						; put cursor on first selection line
	sta	cursorX
	lda	#cursorYmappingLo
	sta	cursorY



MappingLoop:
	wai



; -------------------------- check for d-pad up, move cursor
	lda	Joy1New+1
	and	#%00001000
	beq	@DpadUpDone
	lda	cursorY
	sec
	sbc	#SelLineHeight
	cmp	#cursorYmappingLo-SelLineHeight
	bne	+
	lda	#cursorYmappingExHi
+	sta	cursorY

@DpadUpDone:



; -------------------------- check for d-pad down, move cursor
	lda	Joy1New+1
	and	#%00000100
	beq	@DpadDownDone
	lda	cursorY
	clc
	adc	#SelLineHeight
	cmp	#cursorYmappingExHi+SelLineHeight
	bne	+
	lda	#cursorYmappingLo
+	sta	cursorY

@DpadDownDone:



; -------------------------- check for A button = make a selection
	lda	Joy1New
	bpl	MappingLoop



MappingSelectionMade:
	lda	cursorY							; save cursorY before hiding cursor
	sta	DP_cursorY_BAK

	HideCursorSprite

	lda	#%00001000						; disable color math channel
	trb	DP_HDMAchannels
	jsr	PrintClearScreen

	SetTextPos 1, 0

	lda	DP_cursorY_BAK						; (cursorY / 8) - 16 = mapping flags (%01, %10, or %11)
	lsr	a
	lsr	a
	lsr	a
	sec
	sbc	#16
	sta	temp
	lda	fixheader
	and	#%11111100						; fixheader mapping flags shouldn't be set at this point, mask them off anyway to be safe
	ora	temp							; set mapping flags according to user selection
	sta	fixheader
	and	#%00000011						; mask off everything except mapping bits, and use value as jump index
	asl	a							; value × 2 due to word entries in table

	Accu16

	and	#$00FF							; remove garbage in high byte
	tax								; save as index for upcoming indirect jump instruction

	Accu8

	jmp	(PTR_CheckInternalHeader, x)



InternalHeaderDone:
	ldy	#PTR_tempEntry						; game title in tempEntry

	PrintString ", game title: %s"



; -------------------------- check for battery-backed SRAM support
	PrintString "\nSavegame"

	lda	gameROMType
	and	#$0F							; mask off upper nibble (coprocessor type)
	cmp	#$02
	beq	@ROMHasSRAM
	cmp	#$05
	beq	@ROMHasSRAM

	PrintString " not"

	lda	#$00
	bra	@SRAMCheckDone

@ROMHasSRAM:
	lda	#$01

@SRAMCheckDone:
	sta	useBattery



; -------------------------- allocate/print SRAM size accordingly
	Accu16

	lda	saveSize
	and	#$00FF							; remove garbage bits in Accu B
	tay								; use as index

	Accu8

	lda	SRAMSizes, y
	sta	sramSizeByte
	sta	CONFIGWRITESRAMSIZE

	Accu16

	tya
	asl	a							; value × 2 as SRAMText contains word entries
	tay
	lda	SRAMText, y
	sta	sourceLo

	Accu8

	ldy	#sourceLo

	PrintString " supported, %s KB SRAM added"



; -------------------------- set ROM/SRAM banking
	stz	bankOffset
	stz	bankOffset+1
	lda	gameROMMbits
	cmp	#$60							; check for 96 Mbit
	bne	+
	jmp	ExHiROMBanking

+	lda	gameROMMapper						; check for LoROM
	and	#$0F							; mask off upper nibble (SlowROM/FastROM)
	beq	LoROMBanking						; 0 = LoROM
	cmp	#$01							; check for HiROM
	bne	+
	jmp	HiROMBanking

+	cmp	#$02							; check for ExLoROM // CHECKME, does this even work at all?
	bne	+
	jmp	ExLoROMBanking

+	cmp	#$05							; check for ExHiROM
	bne	+
	jmp	ExHiROMBanking

+	PrintString "\nROM mapping $"
	PrintHexNum gameROMMapper
	PrintString " unsupported!"

	jmp	FatalError



LoROMBanking:
	PrintString "\nLoROM "
	PrintNum gameROMMbits
	PrintString " Mbit"

	lda	gameROMMbits
	lsr	a
	lsr	a
	sta	bankCounter
	dec	bankCounter
                     ;        76543210
                     ;  76543 210
	lda	bankCounter						; multiply by 32 for bytes in map
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	sta	sourceLo
	lda	bankCounter
	lsr	a
	lsr	a
	lsr	a
	sta	sourceHi

	Accu16

	lda	#LoRom4Mbit
	clc
	adc	sourceLo
	sta	destLo

	Accu8

	jsr	CopyBanks

@LoROMSRAM:
	lda	saveSize
	beq	@LoROMBankingDone

	PrintString "\nSRAM in 7x/Fx"

	lda	#$7F
	sta	CONFIGWRITEBANK+$0E0					; 70l // add sram into banks
	sta	gameBanks+$0E
	sta	CONFIGWRITEBANK+$1E0					; F0l
	sta	gameBanks+$1E

@LoROMBankingDone:

	lda	#$00
	sta	CONFIGWRITESRAMLO					; no SRAM in $6000-$7fff
	sta	CONFIGWRITESRAMHI
	jmp	SetROMBankingDone



ExLoROMBanking:
	PrintString "\nExLoROM "

	lda	gameROMMbits
	cmp	#$30
	bne	+

	PrintString "48Mbit"

	ldx	#ExLoRom48Mbit
	stx	destLo
	jsr	CopyBanks
	jmp	LoROMBanking@LoROMSRAM

+	cmp	#$40
	bne	+

	PrintString "64Mbit"

	ldx	#ExLoRom64Mbit
	stx	destLo
	jsr	CopyBanks
	jmp	LoROMBanking@LoROMSRAM

+	PrintString "Unsupported ExLoROM size!"

	jmp	FatalError



HiROMBanking:
	PrintString "\nHiROM "
	PrintNum gameROMMbits
	PrintString " Mbit"

	lda	gameROMMbits
	lsr	a
	lsr	a
	sta	bankCounter
	dec	bankCounter
                     ;        76543210
                     ;  76543 210
	lda	bankCounter						; multiply by 32 for bytes in map
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	sta	sourceLo
	lda	bankCounter
	lsr	a
	lsr	a
	lsr	a
	sta	sourceHi

	Accu16

	lda	#HiRom4Mbit
	clc
	adc	sourceLo
	sta	destLo

	Accu8

	jsr	CopyBanks

	lda	saveSize
	beq	@HiROMNoSRAM

	PrintString "\nSRAM in 20-3F/A0-BF:$6000-7FFF"

	lda	#$0C
	sta	CONFIGWRITESRAMLO					; SRAM in $6000-$7fff = 0C 0C
	sta	CONFIGWRITESRAMHI

;;;;;;FIXME lda something here?
	lda	gameROMMbits						; not sure what this is all about as the only non-special chip 48 Mbit game (ToP) is ExHiROM, not HiROM
	cmp	#$30
	bne	@HiROMBankingDone

@HiROM48SRAM:
	PrintString "\nSRAM in $80-BF:$6000-7FFF"

	lda	#$00
	sta	CONFIGWRITESRAMLO					; SRAM in $6000-$7fff = 00 0F
	lda	#$0F
	sta	CONFIGWRITESRAMHI
	bra	@HiROMBankingDone

@HiROMNoSRAM:
	PrintString "\nNo HiROM SRAM"

	lda	#$00
	sta	CONFIGWRITESRAMLO					; no SRAM
	sta	CONFIGWRITESRAMHI

@HiROMBankingDone:
	jmp	SetROMBankingDone



ExHiROMBanking:
	PrintString "\nExHiROM "

	lda	#$00
	sta	CONFIGWRITESRAMLO					; no SRAM
	sta	CONFIGWRITESRAMHI
	lda	gameROMMbits
	cmp	#$30
	bne	+

	PrintString "48Mbit"

	ldx	#ExHiRom48Mbit
	stx	destLo
	bra	@ExHiROMSRAM

+	cmp	#$40
	bne	+

	PrintString "64Mbit"

	ldx	#ExHiRom64Mbit
	stx	destLo
	bra	@ExHiROMSRAM

+	cmp	#$60
	bne	+

	PrintString "96Mbit"

	ldx	#ExHiRom96Mbit
	stx	destLo
	bra	@ExHiROMSRAM

+	PrintNum gameROMMbits
	PrintString "Mbit unsupported"

@ExHiROMSRAM:
	lda	saveSize
	beq	@ExHiROMBankingDone

	PrintString "\nSRAM in 20-3F/A0-BF:$6000-7FFF"

	lda	#$0C
	sta	CONFIGWRITESRAMLO					; SRAM in $6000-$7fff = 0C 0C
	sta	CONFIGWRITESRAMHI

@ExHiROMBankingDone:
	jsr	CopyBanks

SetROMBankingDone:



; -------------------------- DSP chip mapping
ROMDSPCheck:
	lda	gameROMType
	cmp	#$03
	beq	@ROMHasDSP
	cmp	#$04
	beq	@ROMHasDSP
	cmp	#$05
	beq	@ROMHasDSP
	jmp	@ROMDSPCheckDone

@ROMHasDSP:

;DSPCheck:
	lda	#$04							; turn on HiROM chip
	sta	CONFIGWRITEDSP						; HiROM $00:6000 = DR, $00:7000 = SR
	lda	$007000
	and	#%10000000
	bne	@DSPGood

@DSPBad:
	lda	#$00
	sta	CONFIGWRITEDSP						; turn off DSP

	PrintString "\n\nDSP1 chip required"

	jmp	FatalError

@DSPGood:
	lda	#$00
	sta	CONFIGWRITEDSP						; turn off DSP
	lda	gameROMMapper
	and	#$0F							; mask off upper nibble (SlowROM/FastROM)
	cmp	#$01
	beq	@HiROMDSP						; HiROM
	lda	gameROMMbits						; LoROM 16MB
	cmp	#$09
	bcs	@LoROM16DSP
	bra	@LoROM8DSP

@HiROMDSP:
	PrintString "\nHiROM DSP1"					; $00-1f:6000-7fff
	lda	#$04
	sta	CONFIGWRITEDSP
	bra	@ROMDSPCheckDone

@LoROM8DSP:
	PrintString "\nLoROM DSP1 4-8Mb"				; $20-3f:8000-ffff

	lda	#$01
	sta	CONFIGWRITEDSP
	lda	#$00
	sta	CONFIGWRITEBANK+$050					; 20
	sta	gameBanks+$05
	sta	CONFIGWRITEBANK+$150					; A0
	sta	gameBanks+$15
	sta	CONFIGWRITEBANK+$070					; 30
	sta	gameBanks+$07
	sta	CONFIGWRITEBANK+$170					; B0
	sta	gameBanks+$17
	bra	@ROMDSPCheckDone

@LoROM16DSP:
	PrintString "\nLoROM DSP1 16Mb"					; $60-6f:0000-7fff

	lda	#$02
	sta	CONFIGWRITEDSP
	lda	#$00
	sta	CONFIGWRITEBANK+$0C0					; 60
	sta	gameBanks+$0C
	sta	CONFIGWRITEBANK+$1C0					; E0
	sta	gameBanks+$1C

@ROMDSPCheckDone:
	jsr	PrintBanks						; skip to avoid user confusion due to possible screen overflow



; -------------------------- GameGenie codes
LoadGameGenie:
;	lda	#$60
;	sta	CONFIGWRITEBANK+$3F0
;	lda	#$60
;	sta	CONFIGWRITEBANK+$3E0
;	lda	$F08000
;	sta	errorCode

;	PrintHexNum errorCode

;	lda	#$55
;	sta	$F08000
;	lda	$F08000
;	sta	errorCode

;	PrintHexNum errorCode

	PrintString "\n"

	ldy	#$0000
	jsr	GameGenieWriteCode

	PrintString "\n"

	ldy	#$0008
	jsr	GameGenieWriteCode

	PrintString "\n"

	ldy	#$0010
	jsr	GameGenieWriteCode

	PrintString "\n"

	ldy	#$0018
	jsr	GameGenieWriteCode

	PrintString "\n"

	ldy	#$0020
	jsr	GameGenieWriteCode



; -------------------------- boot game
BootGame:
	lda	Joy1Press+1
	and	#%00100000						; if user holds Select, log screen and wait
	beq	@BootGameNow
	jsr	LogScreenMessage

;	SetTextPos 27, 1
;	PrintString "FPGA STATUS = "

;	lda	CONFIGREADSTATUS
;	sta	errorCode

;	PrintHexNum errorCode

	WaitForUserInput

@BootGameNow:
	lda	fixheader						; save flags along with game name etc. so the PowerPak "remembers" the correct mapping
	and	#%10000011
	tsb	gameName.Flags
	jsr	SaveLastGame

	lda	#$80							; enter forced blank, this should help suppress annoying effects
	sta	REG_INIDISP
	sei								; disable NMI & IRQ so we can reset DMA registers before the game starts
	stz	REG_NMITIMEN
	stz	REG_MDMAEN						; turn off DMA & HDMA
	stz	REG_HDMAEN
	lda	#$FF							; fill DMA registers with initial values, this fixes Nightmare Busters (Beta ROM) crash upon boot
	ldx	#$0000
-	sta	$4300, x
	sta	$4310, x
	sta	$4320, x
	sta	$4330, x
	sta	$4340, x
	sta	$4350, x
	sta	$4360, x
	sta	$4370, x
	inx
	cpx	#$000B							; regs $43x0 through $43xA initialized?
	bne	-

	bit	DP_UserSettings
	bvc	+							; check for randomize SNES RAM flag
	jsr	RandomizeCGRAM
	jsr	RandomizeOAM
	jsr	RandomizeVRAM
	jsr	RandomizeWRAM

+	lda	useBattery
	asl	a
	and	#%00000010
	ora	#%10000000
	sta	CONFIGWRITESTATUS					; reset PowerPak, start game



; **************************** Subroutines *****************************

CopyBanks:
	ldy	#$0000
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$010
	sta	gameBanks+$01
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$030
	sta	gameBanks+$03
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$050
	sta	gameBanks+$05
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$070
	sta	gameBanks+$07
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$090
	sta	gameBanks+$09
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$0B0
	sta	gameBanks+$0B
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$0D0
	sta	gameBanks+$0D
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$0F0
	sta	gameBanks+$0F
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$110
	sta	gameBanks+$11
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$130
	sta	gameBanks+$13
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$150
	sta	gameBanks+$15
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$170
	sta	gameBanks+$17
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$190
	sta	gameBanks+$19
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$1B0
	sta	gameBanks+$1B
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$1D0
	sta	gameBanks+$1D
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$1F0
	sta	gameBanks+$1F
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$000
	sta	gameBanks+$00
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$020
	sta	gameBanks+$02
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$040
	sta	gameBanks+$04
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$060
	sta	gameBanks+$06
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$080
	sta	gameBanks+$08
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$0A0
	sta	gameBanks+$0A
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$0C0
	sta	gameBanks+$0C
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$0E0
	sta	gameBanks+$0E
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$100
	sta	gameBanks+$10
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$120
	sta	gameBanks+$12
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$140
	sta	gameBanks+$14
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$160
	sta	gameBanks+$16
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$180
	sta	gameBanks+$18
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$1A0
	sta	gameBanks+$1A
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$1C0
	sta	gameBanks+$1C
	iny
	lda	[destLo], y
	sta	CONFIGWRITEBANK+$1E0
	sta	gameBanks+$1E
	rts



/* NEW COPYBANKS

CopyBanks:
	ldx	#$0001
	ldy	#$0000

@CopyOddBanks:
	lda	[destLo], y
	iny
	sta	gameBanks, x

	Accu16

	phx								; preserve X index
	txa
	asl	a							; shift left by 4 bits
	asl	a
	asl	a
	asl	a
	tax

	Accu8

	sta	CONFIGWRITEBANK, x
	plx								; restore index
	inx
	inx
	cpx	#$001F+2
	bne	@CopyOddBanks

	ldx	#$0000

@CopyEvenBanks:
	lda	[destLo], y
	iny
	sta	gameBanks, x

	Accu16

	phx								; preserve X index
	txa
	asl	a							; shift left by 4 bits
	asl	a
	asl	a
	asl	a
	tax

	Accu8

	sta	CONFIGWRITEBANK, x
	plx								; restore index
	inx
	inx
	cpx	#$001E+2
	bne	@CopyEvenBanks

	rts

*/



CopyROMInfo:
	ldx	#$0000
-	lda	DMAREADDATA						; start at C0 (game title)
	bpl	+							; if character exceeds standard ASCII (>= $80),
	lda	#'?'							; replace character with question mark
+	sta	tempEntry, x
	inx
	cpx	#$0015							; 21 bytes
	bne	-

	stz	tempEntry, x						; NUL-terminate game title
	lda	DMAREADDATA						; D5
;	ora	gameROMMapper						; acknowledge possibly forced ROM mapping
	sta	gameROMMapper

	PrintString "\nMode $"
	PrintHexNum gameROMMapper

	lda	DMAREADDATA						; D6
	sta	gameROMType

	PrintString ", Type $"
	PrintHexNum gameROMType

	lda	DMAREADDATA						; D7
;	sta	gameROMSize						; ROM size is taken from file size!
	sta	errorCode

	PrintString ", Size $"
	PrintHexNum errorCode

	lda	DMAREADDATA						; D8
	sta	saveSize

	PrintString ", SRAM $"
	PrintHexNum saveSize

	lda	#$FC
	sta	DMAWRITELO
	lda	DMAREADDATA						; FC
	sta	gameResetVector
	lda	DMAREADDATA						; FD
	sta	gameResetVector+1

	PrintString ", Reset $"
	PrintHexNum gameResetVector+1
	PrintHexNum gameResetVector

	rts



FatalError:
	jsr	LogScreenMessage

	PrintString "\n\nPress any button to return to the titlescreen."
	WaitForUserInput

	jsr	PrintClearScreen
	jmp	GotoIntroScreen						; return to titlescreen



LogScreenMessage:
	jsr	LogScreen

	PrintString "\nScreen saved to POWERPAK/ERROR.LOG"

	rts



PrintBanks:
	PrintString "\n0 1 2 3 4 5 6 7 8 9 A B C D E F\tBanks2\t    Banks3\n"

	ldx	#$0001
	ldy	#$0010

@PrintBanks1:
	lda	gameBanks, x
	sta	errorCode

	PrintHexNum errorCode

	inx
	inx
	dey
	bne	@PrintBanks1

	PrintString "\t"

	ldx	#$0008
	ldy	#$0004

@PrintBanks2:
	lda	gameBanks, x
	sta	errorCode

	PrintHexNum errorCode

	inx
	inx
	dey
	bne	@PrintBanks2

	PrintString "    "

	ldx	#$0018
	ldy	#$0004

@PrintBanks3:
	lda	gameBanks, x
	sta	errorCode

	PrintHexNum errorCode

	inx
	inx
	dey
	bne	@PrintBanks3
	rts



PickRandomNrSeed:
	jsr	CreateRandomNr

	lda	RandomNumbers+42					; set random address in SDRAM bank 0
	sta	DMAWRITELO
	lda	RandomNumbers+99
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK
	lda	DMAREADDATA						; read SDRAM value into Accu for use as initial seed for random number generator
	rts



RandomizeCGRAM:
	stz	REG_CGADD						; reset CGRAM address
	lda	#4							; 4 iterations
	sta	temp
-	jsr	PickRandomNrSeed
	jsr	CreateRandomNr

	DMA_CH0 $02, $00, RandomNumbers, <REG_CGDATA, 128

	dec	temp							; 4 × 128 = 512 bytes done?
	bne	-

	rts



RandomizeOAM:
	ldx	#$0000							; reset OAM address
	stx	REG_OAMADDL
	lda	#4							; 4 iterations
	sta	temp
-	jsr	PickRandomNrSeed
	jsr	CreateRandomNr

	DMA_CH0 $02, $00, RandomNumbers, <REG_OAMDATA, 128

	dec	temp							; 4 × 128 = lower 512 bytes done?
	bne	-

	jsr	PickRandomNrSeed
	jsr	CreateRandomNr

	ldx	#0
-	lda	RandomNumbers, x					; randomize upper OAM (not using DMA due to just 32 bytes of data)
	sta	REG_OAMDATA
	inx
	cpx	#32
	bne	-

	rts



RandomizeVRAM:
	lda	#$80							; VRAM address increment mode: increment address by one word after accessing the high byte ($2119)
	sta	REG_VMAIN
	ldx	#$0000							; reset VRAM address
	stx	REG_VMADDL
	ldx	#512							; 512 iterations
	stx	temp
-	jsr	PickRandomNrSeed
	jsr	CreateRandomNr

	DMA_CH0 $01, $00, RandomNumbers, <REG_VMDATAL, 128

	ldx	temp							; 512 × 128 = 65536 bytes done?
	dex
	stx	temp
	bne	-

	rts



RandomizeWRAM:
	ldx	#$0100							; reset WRAM address
	stx	REG_WMADDL
	stz	REG_WMADDH
	lda	#60							; 60 iterations (we skip the first 256 bytes, 128 bytes of random numbers, and 128 bytes of stack area)
	sta	temp

@RandomizeLower8K:
	jsr	PickRandomNrSeed
	jsr	CreateRandomNr

	ldx	#0
-	lda	RandomNumbers, x
	sta	REG_WMDATA
	inx
	cpx	#128
	bne	-

	lda	temp
	dec	a
	cmp	#38							; 22 iterations done (i.e., [WMADDL] has reached #RandomNumbers+2)?
	bne	+
	ldx	#RandomNumbers+130					; yes, set WRAM address beyond random number array
	stx	REG_WMADDL
	stz	REG_WMADDH
+	sta	temp
	cmp	#0
	bne	@RandomizeLower8K					; when temp hits 0, [WMADDL] is pointing to $1F80

	ldx	#$2000							; leave 128 bytes alone for stack integrity, set WRAM address beyond initial stack pointer
	stx	REG_WMADDL
	stz	REG_WMADDH
	ldx	#960							; 960 iterations for rest of WRAM
	stx	temp

@Randomize120K:
	jsr	PickRandomNrSeed
	jsr	CreateRandomNr

	ldx	#0
-	lda	RandomNumbers, x
	sta	REG_WMDATA
	inx
	cpx	#128
	bne	-

	ldx	temp
	dex
	stx	temp
	bne	@Randomize120K

	rts



; ************************** Banking Database **************************

;	     00   10   20   30   40   50   60   70   80   90   A0   B0   C0   D0   E0   F0
LoRom4Mbit:
	.DB $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.DB $00, $00, $00, $00, $20, $20, $20, $20, $00, $00, $00, $00, $20, $20, $20, $20

LoRom8Mbit:
	.DB $20, $21, $20, $21, $20, $21, $20, $21, $20, $21, $20, $21, $20, $21, $20, $21
	.DB $00, $00, $00, $00, $20, $21, $20, $21, $00, $00, $00, $00, $20, $21, $20, $21

LoRom12Mbit:								; UNTESTED
	.DB $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $20, $21, $22, $23

LoRom16Mbit:
	.DB $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $20, $21, $22, $23

LoRom20Mbit:								; UNTESTED
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

LoRom24Mbit:
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

LoRom28Mbit:								; UNTESTED
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

LoRom32Mbit:
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

ExLoRom48Mbit:								; UNTESTED
	.DB $28, $29, $2A, $2B, $20, $21, $22, $23, $28, $29, $2A, $2B, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $24, $25, $26, $27

ExLoRom64Mbit:								; UNTESTED
	.DB $28, $29, $2A, $2B, $20, $21, $22, $23, $2C, $2D, $2E, $2F, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $24, $25, $26, $27



;	     00   10   20   30   40   50   60   70   80   90   A0   B0   C0   D0   E0   F0
HiRom4Mbit:
	.DB $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1
	.DB $00, $00, $00, $00, $A0, $A0, $A0, $A0, $00, $00, $00, $00, $A0, $A0, $A0, $A0

HiRom8Mbit:
	.DB $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1
	.DB $00, $00, $00, $00, $A0, $A0, $A0, $A0, $00, $00, $00, $00, $A0, $A0, $A0, $A0

HiRom12Mbit:								; UNTESTED
	.DB $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3
	.DB $00, $00, $00, $00, $A0, $A2, $A0, $A2, $00, $00, $00, $00, $A0, $A2, $A0, $A2

HiRom16Mbit:
	.DB $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3
	.DB $00, $00, $00, $00, $A0, $A2, $A0, $A2, $00, $00, $00, $00, $A0, $A2, $A0, $A2

HiRom20Mbit:								; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom24Mbit:
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom28Mbit:								; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom32Mbit:
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom36Mbit:								; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom40Mbit:								; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom44Mbit:								; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom48Mbit:
	.DB $A1, $A3, $A5, $A7, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

ExHiRom48Mbit:
	.DB $A9, $AB, $A9, $AB, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

ExHiRom64Mbit:
	.DB $A9, $AB, $AD, $AF, $A9, $AB, $AD, $AF, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $AC, $AE, $00, $00, $00, $00, $A0, $A2, $A4, $A6

ExHiRom96Mbit:
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F
	.DB $00, $00, $00, $00, $30, $31, $32, $33, $00, $00, $00, $00, $34, $35, $36, $37

SRAMSizes:
	.DB %11111111, %11111111, %11111110, %11111100, %11111000, %11110000, %11100000, %11000000, %10000000, %00000000
;	       0          2          4          8        16          32           64       128        256         512

SRAMText:
	.DW SRAM0Kb, SRAM16Kb, SRAM32Kb, SRAM64Kb, SRAM128Kb, SRAM256Kb, SRAM512Kb, SRAM1024Kb

SRAM0Kb:
	.DB "0", 0

SRAM16Kb:
	.DB "2", 0

SRAM32Kb:
	.DB "4", 0

SRAM64Kb:
	.DB "8", 0

SRAM128Kb:
	.DB "16", 0

SRAM256Kb:
	.DB "32", 0

SRAM512Kb:
	.DB "64", 0

SRAM1024Kb:
	.DB "128", 0



; ******************************** EOF *********************************
