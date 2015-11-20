;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** MAIN CODE SECTION: ROM MAPPING ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.ACCU 8
.INDEX 16

StartGame:
	jsr SpriteInit				; purge OAM
	jsr PrintClearScreen

 	SetCursorPos 1, 0

;SetCursorPos 27, 1
;PrintString "FPGA STATUS = "
;lda CONFIGREADSTATUS
;sta errorCode
;PrintHexNum errorCode

	ldx #$0000

ClearBanks:
	stz gameBanks, x
	inx
	cpx #$0020
	bne ClearBanks

	stz headerType
	stz fixheader

	rep #A_8BIT				; A = 16 bit

	lda gameName.gCluster
	sta sourceCluster

	lda gameName.gCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	lda #<sectorBuffer1
	sta destLo
	lda #>sectorBuffer1
	sta destHi				; put into sector RAM
	stz destBank

	stz sectorCounter
	stz bankCounter

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

	lda #kDestWRAM
	sta destType

	jsr CardReadSector			; sector -> WRAM
	jsr CopierHeaderCheck			; check for copier header



; -------------------------- ROM loading
	PrintString "Loading game ..."

	wai

	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI
	sta DMAWRITEBANK			; read file to beginning of SDRAM

	jsr CardReadGameFill

	lda headerType
	bne __CopyROM2SDRAMDone			; if already found header, don't check game size

	lda gameSize
	beq __CopyROM2SDRAMDone

	PrintString "\nUnknown header or file size, but I'll try again ..."

	wai

	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI
	sta DMAWRITEBANK			; read file to beginning of SDRAM

	lda #$FF				; force header skipping even when no known header found
	sta headerType

	jsr CardReadGameFill			; copy again, forcing header skip

__CopyROM2SDRAMDone:

	wai

	ldy #gameSize				; print ROM sectors in decimal ### FIXME add FAT32 excess cluster mask
	PrintString "\nLoaded %d sectors = "

	lda gameSize+1
	sta gameROMMbits

	PrintNum gameROMMbits
	PrintString " Mbit"

FixMbits:
	lda gameROMMbits
	cmp #9
	beq Fix9or10Mbits

	cmp #10
	bne FixMbitsDone

Fix9or10Mbits:					; ROM size fix, change 9 or 10 Mbits to 12 Mbits
	lda #12
	sta gameROMMbits

FixMbitsDone:



; -------------------------- SRAM loading
LoadSave:
	PrintString "\nChecking savegame ... "

	rep #A_8BIT				; A = 16 bit

	lda saveName.sCluster
	bne LoadSaveStart

	lda saveName.sCluster+2
	bne LoadSaveStart

	sep #A_8BIT				; A = 8 bit

	PrintString "no SRAM file found."

	jmp LoadSaveDone

LoadSaveStart:

.ACCU 16

	lda saveName.sCluster
	sta sourceCluster

	lda saveName.sCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	lda #$F8				; load SRAM to SDRAM location $F80000
	sta DMAWRITEBANK
	lda #$00
	sta DMAWRITELO
	sta DMAWRITEHI

	stz sectorCounter
	stz bankCounter

	lda #kDestSDRAM
	sta destType

	jsr CardReadFile

	ldy #gameSize				; print SRAM sectors in decimal
	PrintString "present, loaded %d sectors = "

	lsr gameSize

	PrintNum gameSize
	PrintString " KB"

LoadSaveDone:



; -------------------------- ROM ID checks
CheckInternalHeaderExHi:
	lda #$C0
	sta DMAWRITELO
	lda #$FF
	sta DMAWRITEHI
	lda #$40
	sta DMAWRITEBANK			; check for internal header  40FFC0

	jsr CopyROMInfo

;PrintString "/nmapper="
;PrintHexNum gameROMMapper

	lda gameROMMapper

; cmp #$35
; beq CheckInternalHeaderExHiType

	cmp #$25
	beq CheckInternalHeaderExHiType
	bra NotInternalHeaderExHi

CheckInternalHeaderExHiType:

; PrintString "/nMAP good "

	lda gameROMType
	cmp #$06				; ROM type must be <= 5
	bcs NotInternalHeaderExHi

;PrintString "/nROM good "

	lda #$60
	cmp gameROMMbits			; ROM size <= 96Mbits
	bcc NotInternalHeaderExHi

;PrintString "SIZE good "

	lda #$08
	cmp saveSize				; SRAM size <= 8d
	bcc NotInternalHeaderExHi

;PrintString "RAM good "

	lda gameResetVector+1
	cmp #$80				; reset vector goes to >= 8000
	bcc NotInternalHeaderExHi

;PrintString "RESET good "

	jmp InternalHeaderIsExHi

NotInternalHeaderExHi:
	PrintString "\nNo $40FFC0 header"



CheckInternalHeaderHi:
	lda #$C0
	sta DMAWRITELO
	lda #$FF
	sta DMAWRITEHI
	lda #$00
	sta DMAWRITEBANK			; check for internal header $FFC0

	jsr CopyROMInfo

	lda fixheader
	beq CheckInternalHeaderHiMapper		; don't fix the header

	lda #$21
	sta gameROMMapper			; assume HiROM

CheckInternalHeaderHiMapper:
	lda gameROMMapper

;cmp #$20
;beq CheckInternalHeaderHiType

	cmp #$21
	beq CheckInternalHeaderHiType

;cmp #$22
;beq CheckInternalHeaderHiType

	cmp #$25
	bne NotInternalHeaderHi



CheckInternalHeaderHiType:
	lda gameROMType
	cmp #$06				; ROM type must be <= 5
	bcs NotInternalHeaderHi

	lda #$40
	cmp gameROMMbits			; ROM size <= 64Mbits
	bcc NotInternalHeaderHi

	lda #$08
	cmp saveSize				; SRAM size <= 8d
	bcc NotInternalHeaderHi

	lda gameResetVector+1
	cmp #$80				; reset vector goes to >= 8000
	bcc NotInternalHeaderHi

	jmp InternalHeaderIsHi

NotInternalHeaderHi:
	PrintString "\nNo $FFC0 header"



CheckInternalHeaderLo:
	lda #$C0
	sta DMAWRITELO
	lda #$7F
	sta DMAWRITEHI
	lda #$00
	sta DMAWRITEBANK			; check for internal header $7FC0

	jsr CopyROMInfo

	lda fixheader
	beq CheckInternalHeaderLoMapper		; don't fix the header

	lda #$20
	sta gameROMMapper			; assume LoROM

CheckInternalHeaderLoMapper:
	lda gameROMMbits
	cmp #$60
	beq InternalHeaderIs96

	lda gameROMMapper
	cmp #$20
	beq CheckInternalHeaderLoType

;cmp #$21
;beq CheckInternalHeaderLoType

	cmp #$22
	beq CheckInternalHeaderLoType

;cmp #$25
;beq CheckInternalHeaderLoType

	bra NotInternalHeaderLo

CheckInternalHeaderLoType:
	lda gameROMType
	cmp #$06				; ROM type must be <= 5
	bcs NotInternalHeaderLo

	lda #$20
	cmp gameROMMbits			; ROM size <= 32Mbits
	bcc NotInternalHeaderLo

	lda #$08
	cmp saveSize				; SRAM size <= 8d
	bcc NotInternalHeaderLo

	lda gameResetVector+1
	cmp #$80				; reset vector goes to >= 8000
	bcc NotInternalHeaderLo

	bra InternalHeaderIsLo

NotInternalHeaderLo:
	PrintString "\nNo $7FC0 header"
	jmp NoInternalHeader

InternalHeaderIs96:
	PrintString "\n96Mbit ROM"
	bra InternalHeaderDone

InternalHeaderIsExHi:
	PrintString "\nHeader at $40FFC0"
	bra InternalHeaderDone

InternalHeaderIsLo:
	PrintString "\nHeader at $7FC0"
	bra InternalHeaderDone

InternalHeaderIsHi:
	PrintString "\nHeader at $FFC0"
;	bra InternalHeaderDone

InternalHeaderDone:
	ldy #PTR_tempEntry			; game title in tempEntry

	PrintString ", game title: %s"



; -------------------------- SRAM mapping
ROMBattCheck:
	lda gameROMType
	cmp #$02
	beq ROMHasBatt
	cmp #$05
	beq ROMHasBatt

	PrintString "\nSavegame not"
	stz useBattery				; no battery when no SRAM

	bra ROMBattCheckDone

ROMHasBatt:
	lda #$01
	sta useBattery

	PrintString "\nSavegame"

ROMBattCheckDone:

SetSRAMSize:
	lda saveSize
	sta destLo
	stz destHi

	ldy destLo

	lda SRAMSizes, y
	sta sramSizeByte
	sta CONFIGWRITESRAMSIZE

PrintSRAMSize:
	lda SRAMTextLo, y
	sta sourceLo
	lda SRAMTextHi, y
	sta sourceHi

	ldy #sourceLo

	PrintString " supported, %s KB SRAM added"

PrintSRAMSizeDone:



; -------------------------- ROM banking
SetROMBanking:
	stz bankOffset
	stz bankOffset+1



Check96Banking:
	lda gameROMMbits
	cmp #$60
	bne Check96BankingDone
	jmp ExHiROMBanking

Check96BankingDone:



CheckLoROMBanking:
	lda gameROMMapper
	cmp #$20
	bne CheckLoROMBankingDone
	bra LoROMBanking

CheckLoROMBankingDone:



CheckHiROMBanking:
	lda gameROMMapper
	cmp #$21
	bne CheckHiROMBankingDone
	jmp HiROMBanking

CheckHiROMBankingDone:



CheckExLoROMBanking:
	lda gameROMMapper
	cmp #$22
	bne CheckExLoROMBankingDone
	jmp ExLoROMBanking

CheckExLoROMBankingDone:



CheckExHiROMBanking:
	lda gameROMMapper
	cmp #$25
	bne CheckExHiROMBankingDone
	jmp ExHiROMBanking

CheckExHiROMBankingDone:

;  PrintString "\nMapper "
;  PrintHexNum gameROMMapper
;  PrintString " unsupported"
;  jmp FatalError



LoROMBanking:
	PrintString "\nLoROM "
	PrintNum gameROMMbits
	PrintString " Mbit"
	lda gameROMMbits
	lsr a
	lsr a
	sta bankCounter
	dec bankCounter
                     ;        76543210
                     ;  76543 210
	lda bankCounter				; multiply by 32 for bytes in map
	asl a
	asl a
	asl a
	asl a
	asl a
	sta sourceLo
	lda bankCounter
	lsr a
	lsr a
	lsr a
	sta sourceHi

	lda #<LoRom4Mbit
	clc
	adc sourceLo
	sta destLo
	lda #>LoRom4Mbit
	adc sourceHi
	sta destHi

	jsr CopyBanks



LoROMSRAM:
	lda saveSize
	beq LoROMBankingDone
	PrintString "\nSRAM in 7x/Fx"

	lda #$7F
	sta CONFIGWRITEBANK+$0E0		; 70l // add sram into banks
	sta gameBanks+$0E
	sta CONFIGWRITEBANK+$1E0		; F0l
	sta gameBanks+$1E

LoROMBankingDone:



	lda #$00
	sta CONFIGWRITESRAMLO			; no SRAM in $6000-$7fff
	sta CONFIGWRITESRAMHI

	jmp SetROMBankingDone



ExLoROMBanking:
	PrintString "\nExLoROM "
	lda gameROMMbits

ExLoROMBanking48Mbit:
	cmp #$30
	bne ExLoROMBankingNot48Mbit
	PrintString "48Mbit"

	lda #<ExLoRom48Mbit
	sta destLo
	lda #>ExLoRom48Mbit
	sta destHi

	jmp ExLoROMBankingLoop

ExLoROMBankingNot48Mbit:



ExLoROMBanking64Mbit:
	cmp #$40
	bne ExLoROMBankingNot64Mbit
	PrintString "64Mbit"

	lda #<ExLoRom64Mbit
	sta destLo
	lda #>ExLoRom64Mbit
	sta destHi
	bra ExLoROMBankingLoop

ExLoROMBankingNot64Mbit:



	lda fixheader				; ExLoROM of wrong size found
	cmp #$01
	bne ExLoROMTryHeaderFix			; header fix already attempted

	jmp FatalError



ExLoROMTryHeaderFix:
	jsr PrintClearScreen

	SetCursorPos 1, 0

;  PrintString "\nExLoROM "
;  PrintNum gameROMMbits
;  PrintString " Mbit unsupported"
;  PrintString "\nRetrying with fixed header ..."

	PrintString "Unsupported ExLoROM size, but I'll try to fix it ..."

	lda #$01
	sta fixheader
	lda #$FF
	sta headerType

	jmp CheckInternalHeaderHi



ExLoROMBankingLoop:
	jsr CopyBanks

	jmp LoROMSRAM



HiROMBanking:
	PrintString "\nHiROM "
	PrintNum gameROMMbits
	PrintString " Mbit"

	lda gameROMMbits
	lsr a
	lsr a
	sta bankCounter
	dec bankCounter
                     ;        76543210
                     ;  76543 210
	lda bankCounter				; multiply by 32 for bytes in map
	asl a
	asl a
	asl a
	asl a
	asl a
	sta sourceLo
	lda bankCounter
	lsr a
	lsr a
	lsr a
	sta sourceHi

	lda #<HiRom4Mbit
	clc
	adc sourceLo
	sta destLo
	lda #>HiRom4Mbit
	adc sourceHi
	sta destHi

	jsr CopyBanks

	lda saveSize
	beq HiROMNoSRAM

	PrintString "\nSRAM in 20-3F/A0-BF:$6000-7FFF"

	lda #$0C
	sta CONFIGWRITESRAMLO			; SRAM in $6000-$7fff = 0C 0C
	sta CONFIGWRITESRAMHI

;;;;;;FIXME lda something here?

	cmp #$30
	bne HiROMBankingDone



HiROM48SRAM:
	PrintString "\nSRAM in $80-BF:$6000-7FFF"
	lda #$00
	sta CONFIGWRITESRAMLO			; SRAM in $6000-$7fff = 00 0F
	lda #$0F
	sta CONFIGWRITESRAMHI
	bra HiROMBankingDone



HiROMNoSRAM:
	PrintString "\nNo HiROM SRAM"
	lda #$00
	sta CONFIGWRITESRAMLO			; no SRAM
	sta CONFIGWRITESRAMHI



HiROMBankingDone:
	jmp SetROMBankingDone



ExHiROMBanking:
	PrintString "\nExHiROM "
	lda #$00
	sta CONFIGWRITESRAMLO			; no SRAM
	sta CONFIGWRITESRAMHI

	lda gameROMMbits



ExHiROMBanking48Mbit:
	cmp #$30
	bne ExHiROMBankingNot48Mbit
	PrintString "48Mbit"
	lda #<ExHiRom48Mbit
	sta destLo
	lda #>ExHiRom48Mbit
	sta destHi

;PrintString "\nSRAM in $80-BF:$6000-7FFF"
;lda #$00
 ; sta CONFIGWRITESRAMLO           ;;sram in 6000-7fff = 00 0F
;lda #$0F
;sta CONFIGWRITESRAMHI

	PrintString "\nSRAM in 20-3F/A0-BF:$6000-7FFF"
	lda #$0C
	sta CONFIGWRITESRAMLO			; SRAM in $6000-$7fff = 0C 0C
	sta CONFIGWRITESRAMHI

	jmp ExHiROMBankingLoop

ExHiROMBankingNot48Mbit:



ExHiROMBanking64Mbit:
	cmp #$40
	bne ExHiROMBankingNot64Mbit
	PrintString "64Mbit"
	lda #<ExHiRom64Mbit
	sta destLo
	lda #>ExHiRom64Mbit
	sta destHi
	bra ExHiROMSRAM

ExHiROMBankingNot64Mbit:



ExHiROMBanking96Mbit:
	cmp #$60
	bne ExHiROMBankingNot96Mbit
	PrintString "96Mbit"
	lda #<ExHiRom96Mbit
	sta destLo
	lda #>ExHiRom96Mbit
	sta destHi
	bra ExHiROMSRAM

ExHiROMBankingNot96Mbit:

	PrintNum gameROMMbits
	PrintString "Mbit unsupported"



ExHiROMSRAM:
	lda saveSize
	beq ExHiROMBankingLoop
	PrintString "\nSRAM in 20-3F/A0-BF:$6000-7FFF"
	lda #$0C
	sta CONFIGWRITESRAMLO			; SRAM in $6000-$7fff = 0C 0C
	sta CONFIGWRITESRAMHI

ExHiROMBankingLoop:

	jsr CopyBanks

ExHiROMBankingDone:
;	bra SetROMBankingDone

SetROMBankingDone:



; -------------------------- DSP chip mapping
ROMDSPCheck:
	lda gameROMType
	cmp #$03
	beq ROMHasDSP
	cmp #$04
	beq ROMHasDSP
	cmp #$05
	beq ROMHasDSP

	jmp ROMDSPCheckDone

ROMHasDSP:



;DSPCheck:
	lda #$04				; turn on HiROM chip
	sta CONFIGWRITEDSP			; HiROM $00:6000 = DR, $00:7000 = SR
	lda $007000
	and #%10000000
	bne DSPGood



DSPBad:
	lda #$00
	sta CONFIGWRITEDSP			; turn off DSP

	PrintString "\n\nDSP1 chip required"

	jmp FatalError



DSPGood:
	lda #$00
	sta CONFIGWRITEDSP			; turn off DSP
	lda gameROMMapper
	cmp #$21
	beq HiROMDSP				; HiROM

	lda gameROMMbits			; LoROM 16MB
	cmp #$09
	bcs LoROM16DSP

	bra LoROM8DSP



HiROMDSP:
	PrintString "\nHiROM DSP1"		; $00-1f:6000-7fff
	lda #$04
	sta CONFIGWRITEDSP
	bra ROMDSPCheckDone



LoROM8DSP:
	PrintString "\nLoROM DSP1 4-8Mb"	; $20-3f:8000-ffff
	lda #$01
	sta CONFIGWRITEDSP
	lda #$00
	sta CONFIGWRITEBANK+$050		; 20
	sta gameBanks+$05
	sta CONFIGWRITEBANK+$150		; A0
	sta gameBanks+$15
	sta CONFIGWRITEBANK+$070		; 30
	sta gameBanks+$07
	sta CONFIGWRITEBANK+$170		; B0
	sta gameBanks+$17
	bra ROMDSPCheckDone



LoROM16DSP:
	PrintString "\nLoROM DSP1 16Mb"		; $60-6f:0000-7fff
	lda #$02
	sta CONFIGWRITEDSP
	lda #$00
	sta CONFIGWRITEBANK+$0C0		; 60
	sta gameBanks+$0C
	sta CONFIGWRITEBANK+$1C0		; E0
	sta gameBanks+$1C
;	bra ROMDSPCheckDone



ROMDSPCheckDone:

	jsr PrintBanks				; skip to avoid user confusion due to possible screen overflow



; -------------------------- GameGenie codes
LoadGameGenie:

;lda #$60
;sta CONFIGWRITEBANK+$3F0
;lda #$60
;sta CONFIGWRITEBANK+$3E0
;lda $F08000
;sta errorCode
;PrintHexNum errorCode
;lda #$55
;sta $F08000
;lda $F08000
;sta errorCode
;PrintHexNum errorCode

	PrintString "\n"

	ldy #$0000
	jsr GameGenieWriteCode

	PrintString "\n"

	ldy #$0008
	jsr GameGenieWriteCode

	PrintString "\n"

	ldy #$0010
	jsr GameGenieWriteCode

	PrintString "\n"

	ldy #$0018
	jsr GameGenieWriteCode

	PrintString "\n"

	ldy #$0020
	jsr GameGenieWriteCode



; -------------------------- boot game
;ResetSystem:
	stz Joy1New
	stz Joy1New+1

	lda Joy1Press+1
	and #%00100000				; if user holds Select, log screen and wait
	beq __ResetSystemNow

	jsr LogScreenMessage

;	SetCursorPos 27, 1
;	PrintString "FPGA STATUS = "
;	lda CONFIGREADSTATUS
;	sta errorCode
;	PrintHexNum errorCode

	WaitForUserInput

__ResetSystemNow:
	jsr SaveLastGame

;lda #$00
;sta $4200    ;;turn off nmi
;sta $420B    ;;turn off dma

	lda #$80				; enter forced blank, this should help suppress annoying effects
	sta $2100

	sei					; disable NMI & IRQ so we can permanently reset DMA registers before the game starts
	stz REG_NMITIMEN

	lda #$FF				; clear DMA registers, this fixes Nightmare Busters (Beta ROM) crash upon boot

	ldx #$0000

-	sta $4300, x
	sta $4310, x
	sta $4320, x
	sta $4330, x
	sta $4340, x
	sta $4350, x
	sta $4360, x
	sta $4370, x

	inx
	cpx #$000B				; regs $43x0 through $43xA re-initiated?
	bne -

	stz $420D				; turn off FastROM

	lda useBattery
	asl a
	and #%00000010
	ora #%10000000
	sta CONFIGWRITESTATUS			; reset PowerPak, start game



; *********************** Screen logging message ***********************

LogScreenMessage:
	jsr LogScreen

	PrintString "\nScreen saved to POWERPAK/ERROR.LOG"
rts



; *************************** Error handling ***************************

FatalError:
	jsr LogScreenMessage

	PrintString "\n\nPress any button to return to the titlescreen."

	WaitForUserInput

	jsr PrintClearScreen
	jmp GotoIntroScreen			; return to titlescreen

;	lda #%10000001				; alternatively:
;	sta CONFIGWRITESTATUS			; Start pressed, reset PowerPak, stay in boot mode



NoInternalHeader:
	lda fixheader
	cmp #$01
	beq NoInteralHeaderFixed		; header fix already attempted

	jsr PrintClearScreen

	SetCursorPos 1, 0

	PrintString "No internal header found, I'll make an educated guess ..."

	lda #$01
	sta fixheader

	jmp CheckInternalHeaderHi



NoInteralHeaderFixed:
	PrintString "\nI'm sorry, but I can't load this ROM file. :-("

	jmp FatalError



; ************************ Load ROM information ************************

CopyROMInfo:
	ldx #$0000

-	lda DMAREADDATA				; start at C0 (game title)
	cmp #$80				; check if character exceeds standard ASCII
	bcc +
	lda #'?'				; if so, replace character with question mark
+	sta tempEntry, x
	inx
	cpx #$0015				; 21 bytes
	bne -

	stz tempEntry, x			; NUL-terminate game title

	lda DMAREADDATA				; D5
	sta errorCode
	and #%11101111				; mask off fast/slow
	sta gameROMMapper
	PrintString "\nMode $"
	PrintHexNum errorCode

	lda DMAREADDATA				; D6
	sta gameROMType
	PrintString ", Type $"
	PrintHexNum gameROMType

	lda DMAREADDATA				; D7
;	sta gameROMSize				; ROM size is taken from file size!
	sta errorCode
	PrintString ", Size $"
	PrintHexNum errorCode

	lda DMAREADDATA				; D8
	sta saveSize
	PrintString ", SRAM $"
	PrintHexNum saveSize

	lda #$FC
	sta DMAWRITELO

	lda DMAREADDATA				; FC
	sta gameResetVector

	lda DMAREADDATA				; FD
	sta gameResetVector+1

	PrintString ", Reset $"
	PrintHexNum gameResetVector+1
	PrintHexNum gameResetVector
rts



CopyBanks:
	ldy #$0000

	lda [destLo], y
	sta CONFIGWRITEBANK+$010
	sta gameBanks+$01

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$030
	sta gameBanks+$03

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$050
	sta gameBanks+$05

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$070
	sta gameBanks+$07

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$090
	sta gameBanks+$09

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$0B0
	sta gameBanks+$0B

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$0D0
	sta gameBanks+$0D

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$0F0
	sta gameBanks+$0F

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$110
	sta gameBanks+$11

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$130
	sta gameBanks+$13

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$150
	sta gameBanks+$15

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$170
	sta gameBanks+$17

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$190
	sta gameBanks+$19

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$1B0
	sta gameBanks+$1B

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$1D0
	sta gameBanks+$1D

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$1F0
	sta gameBanks+$1F

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$000
	sta gameBanks+$00

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$020
	sta gameBanks+$02

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$040
	sta gameBanks+$04

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$060
	sta gameBanks+$06

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$080
	sta gameBanks+$08

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$0A0
	sta gameBanks+$0A

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$0C0
	sta gameBanks+$0C

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$0E0
	sta gameBanks+$0E

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$100
	sta gameBanks+$10

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$120
	sta gameBanks+$12

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$140
	sta gameBanks+$14

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$160
	sta gameBanks+$16

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$180
	sta gameBanks+$18

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$1A0
	sta gameBanks+$1A

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$1C0
	sta gameBanks+$1C

	iny

	lda [destLo], y
	sta CONFIGWRITEBANK+$1E0
	sta gameBanks+$1E
rts



PrintBanks:
	PrintString "\n0 1 2 3 4 5 6 7 8 9 A B C D E F\tBanks2\t    Banks3\n"

	ldx #$0001
	ldy #$0010

__PrintBanks1:
	lda gameBanks, x
	sta errorCode
	PrintHexNum errorCode
	inx
	inx
	dey
	bne __PrintBanks1

	PrintString "\t"

	ldx #$0008
	ldy #$0004

__PrintBanks2:
	lda gameBanks, x
	sta errorCode
	PrintHexNum errorCode
	inx
	inx
	dey
	bne __PrintBanks2

	PrintString "    "

	ldx #$0018
	ldy #$0004

__PrintBanks3:
	lda gameBanks, x
	sta errorCode
	PrintHexNum errorCode
	inx
	inx
	dey
	bne __PrintBanks3
rts



; ************************ Copier header check *************************

CopierHeaderCheck:



; -------------------------- check for SWC header
	lda sectorBuffer1+$08			; Super WildCard headers contain $AABB04 at offset $08-$0A
	cmp #$AA
	bne __SWCHeaderCheckDone

	lda sectorBuffer1+$09
	cmp #$BB
	bne __SWCHeaderCheckDone

	lda sectorBuffer1+$0A
	cmp #$04
	bne __SWCHeaderCheckDone

	lda #$01				; SWC copier header found
	sta headerType

	PrintString "SWC Header\n"

	bra __CopierHeaderCheckDone

__SWCHeaderCheckDone:



; -------------------------- check for GD3 header
	lda sectorBuffer1+$00			; Game Doctor headered ROMs start with a "GAME" string
	cmp #'G'
	bne __CopierHeaderCheckDone

	lda sectorBuffer1+$01
	cmp #'A'
	bne __CopierHeaderCheckDone

	lda sectorBuffer1+$02
	cmp #'M'
	bne __CopierHeaderCheckDone

	lda sectorBuffer1+$03
	cmp #'E'
	bne __CopierHeaderCheckDone

	lda #$02
	sta headerType

	PrintString "GD3 Header\n"

__CopierHeaderCheckDone:

rts



; ************************** Banking Database **************************

;	     00   10   20   30   40   50   60   70   80   90   A0   B0   C0   D0   E0   F0
LoRom4Mbit:
	.DB $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
	.DB $00, $00, $00, $00, $20, $20, $20, $20, $00, $00, $00, $00, $20, $20, $20, $20

LoRom8Mbit:
	.DB $20, $21, $20, $21, $20, $21, $20, $21, $20, $21, $20, $21, $20, $21, $20, $21
	.DB $00, $00, $00, $00, $20, $21, $20, $21, $00, $00, $00, $00, $20, $21, $20, $21

LoRom12Mbit:					; UNTESTED
	.DB $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $20, $21, $22, $23

LoRom16Mbit:
	.DB $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23, $20, $21, $22, $23
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $20, $21, $22, $23

LoRom20Mbit:					; UNTESTED
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

LoRom24Mbit:
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

LoRom28Mbit:					; UNTESTED
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

LoRom32Mbit:
	.DB $20, $21, $22, $23, $24, $25, $26, $27, $20, $21, $22, $23, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $24, $25, $26, $27, $00, $00, $00, $00, $24, $25, $26, $27

ExLoRom48Mbit:					; UNTESTED
	.DB $28, $29, $2A, $2B, $20, $21, $22, $23, $28, $29, $2A, $2B, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $24, $25, $26, $27

ExLoRom64Mbit:					; UNTESTED
	.DB $28, $29, $2A, $2B, $20, $21, $22, $23, $2C, $2D, $2E, $2F, $24, $25, $26, $27
	.DB $00, $00, $00, $00, $20, $21, $22, $23, $00, $00, $00, $00, $24, $25, $26, $27



;	     00   10   20   30   40   50   60   70   80   90   A0   B0   C0   D0   E0   F0
HiRom4Mbit:
	.DB $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1
	.DB $00, $00, $00, $00, $A0, $A0, $A0, $A0, $00, $00, $00, $00, $A0, $A0, $A0, $A0

HiRom8Mbit:
	.DB $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1
	.DB $00, $00, $00, $00, $A0, $A0, $A0, $A0, $00, $00, $00, $00, $A0, $A0, $A0, $A0

HiRom12Mbit:					; UNTESTED
	.DB $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3
	.DB $00, $00, $00, $00, $A0, $A2, $A0, $A2, $00, $00, $00, $00, $A0, $A2, $A0, $A2

HiRom16Mbit:
	.DB $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3, $A1, $A3
	.DB $00, $00, $00, $00, $A0, $A2, $A0, $A2, $00, $00, $00, $00, $A0, $A2, $A0, $A2

HiRom20Mbit:					; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom24Mbit:
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom28Mbit:					; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom32Mbit:
	.DB $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A0, $A2, $A4, $A6, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom36Mbit:					; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom40Mbit:					; UNTESTED
	.DB $A1, $A3, $A5, $A7, $A9, $AB, $A9, $AB, $A1, $A3, $A5, $A7, $A1, $A3, $A5, $A7
	.DB $00, $00, $00, $00, $A8, $AA, $A8, $AA, $00, $00, $00, $00, $A0, $A2, $A4, $A6

HiRom44Mbit:					; UNTESTED
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



SRAMTextLo:
	.DB <SRAM0Kb, <SRAM16Kb, <SRAM32Kb, <SRAM64Kb, <SRAM128Kb, <SRAM256Kb, <SRAM512Kb, <SRAM1024Kb

SRAMTextHi:
	.DB >SRAM0Kb, >SRAM16Kb, >SRAM32Kb, >SRAM64Kb, >SRAM128Kb, >SRAM256Kb, >SRAM512Kb, >SRAM1024Kb

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
