;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** MAIN CODE SECTION: BOOTLOADER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



; ************************* Main reset vector **************************

Main:
	sei					; disable interrupts
	clc
	xce					; switch to native mode

	rep #$18				; X/Y = 16 bit, decimal mode off
	sep #A_8BIT				; A = 8 bit

	lda DP_ColdBootCheck1			; perform cold-boot check
	cmp #kWarmBoot1
	bne __ColdBoot

	lda DP_ColdBootCheck2
	cmp #kWarmBoot2
	bne __ColdBoot

	lda DP_ColdBootCheck3
	cmp #kWarmBoot3
	bne __ColdBoot

	lda VAR_ColdBootCheck4
	cmp #kWarmBoot4
	bne __ColdBoot

	lda VAR_ColdBootCheck5
	cmp #kWarmBoot5
	bne __ColdBoot

	lda VAR_ColdBootCheck6
	cmp #kWarmBoot6
	bne __ColdBoot

	lda VAR_ColdBootCheck7
	cmp #kWarmBoot7
	bne __ColdBoot



; ***************************** Warm boot ******************************

	ldx DP_StackPointer_BAK			; restore stack pointer
	txs

	jsr WarmBootInit

	lda DP_cursorX_BAK			; restore cursor position
	sta cursorX

	lda DP_cursorY_BAK
	sta cursorY

	lda #%00110000				; activate HDMA channels 4 and 5 (BG color gradient, windowing)
	sta DP_HDMAchannels

	wai

	lda #$0F				; turn on the screen, full brightness
	sta $2100

	jmp __FileBrowserLoop			; return to file browser



; ***************************** Cold boot ******************************

__ColdBoot:
	ldx #$1FFF				; set up the stack
	txs

	jsr InitSNES				; initialize SNES hardware
	jsl apu_ram_init

	phk					; set data bank = program bank (needed as apu_ram_init sits in ROM bank 2)
	plb

	jsr SpriteInit				; set up sprite buffer
	jsr QuickSetup				; set up VRAM, video mode, background and character pointers
	jsr JoyInit				; initialize joypads and enable NMI

	rep #XY_8BIT				; X/Y = 16 bit
	sep #A_8BIT				; A = 8 bit

.IFDEF DEMOMODE
	jmp __InDemoModeToIntroScreen
.ENDIF

	jsr AccessCFcard			; begin CF interaction, back here means valid card found



; -------------------------- load configuration
	jsr CardLoadDir				; root dir

	lda #'P'
	sta findEntry
	sta findEntry+5

	lda #'O'
	sta findEntry+1

	lda #'W'
	sta findEntry+2

	lda #'E'
	sta findEntry+3

	lda #'R'
	sta findEntry+4

	lda #'A'
	sta findEntry+6

	lda #'K'
	sta findEntry+7

	jsr DirFindEntry			; "POWERPAK" dir into tempEntry

	rep #A_8BIT				; A = 16 bit

	lda tempEntry.tempCluster		; "POWERPAK" dir found, save cluster
	sta baseDirCluster

	lda tempEntry.tempCluster+2
	sta baseDirCluster+2

	sep #A_8BIT				; A = 8 bit

.IFDEF DEBUG
	PrintString "baseDirCluster $"
	PrintHexNum baseDirCluster+3
	PrintHexNum baseDirCluster+2
	PrintHexNum baseDirCluster+1
	PrintHexNum baseDirCluster+0
	PrintString "\n"
.ENDIF

	FindFile "POWERPAK.CFG"			; attempt to load configuration file

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

	ldy #$0000

	lda sectorBuffer1, y			; transfer first byte to DMA "blocker" variable (standard = $00 = DMA on)
	sta dontUseDMA				; (reminder: DMA was off until now)

	iny

	rep #A_8BIT				; A = 16 bit

	lda sectorBuffer1, y			; read theme file cluster
	sta DP_ThemeFileClusterLo

	iny
	iny

	lda sectorBuffer1, y
	sta DP_ThemeFileClusterHi

	lda DP_ThemeFileClusterLo
	bne +

	lda DP_ThemeFileClusterHi
	beq __NoThemeFileSaved

+	jmp __ThemeFileClusterSet

__NoThemeFileSaved:
	FindFile "THEMES.   "			; this makes A = 8 bit

	jsr ClearFindEntry

	ldx #$0001				; number of file types to look for (1)
	stx extNum

	lda #'T'
	sta extMatch1

	lda #'H'
	sta extMatch2

	lda #'M'
	sta extMatch3
	sta findEntry

	lda #'U'
	sta findEntry+1

	lda #'F'
	sta findEntry+2

	lda #'A'
	sta findEntry+3
	sta findEntry+5

	lda #'S'
	sta findEntry+4

	stz CLDConfigFlags			; use WRAM buffer

	jsr CardLoadDir				; "THEMES" directory into WRAM buffer,
	jsr DirFindEntry			; "MUFASA.THM" file into tempEntry

	rep #A_8BIT				; A = 16 bit

	lda tempEntry.tempCluster		; "MUFASA.THM" file found, save cluster
	sta DP_ThemeFileClusterLo

	lda tempEntry.tempCluster+2
	sta DP_ThemeFileClusterHi

__ThemeFileClusterSet:
	sep #A_8BIT				; A = 8 bit



; --------------------------- configure FPGA
	lda CONFIGREADSTATUS			; open bus = $20

;	sta errorCode
;	SetCursorPos 14, 1
;	PrintString "FPGA status="
;	PrintHexNum errorCode
;
;	jmp Forever

	and #$F0
	cmp #$A0
	bne ConfigureFPGA

;	SetCursorPos 15, 1
;	PrintString "FPGA was configured"

	lda CONFIGREADSTATUS			; battery used = D1
	and #$02
	bne +

	jmp __ConfigureFPGADone			; battery not used, continue with intro

+	jsr LoadTheme				; battery used, load theme file before activating the screen

	lda #%00110000				; activate HDMA channels 4 and 5
	sta DP_HDMAchannels

	jsr PrintRomVersion			; show ROM version string (with sprite FWT from theme file)

	wai

	lda #$0F				; turn on the screen, full brightness
	sta $2100

	jsr BattUsedInitSaveSRAM		; offer to save SRAM to card
	jmp GotoIntroScreen



ConfigureFPGA:
;	lda #$FF
;	sta $420d				; turn on FastROM

	lda #$01
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA

	lda #$00
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	lda #$01
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA

	FindFile "TOPLEVEL.BIT"

	jsr CardLoadFPGA

;	ClearLine 18
;	SetCursorPos 18, 1
;	PrintString "FPGA just configured\n"

	wai
	lda #%00000001
	sta CONFIGWRITESTATUS			; unlock SDRAM

;	PrintString "unlocked sdram"

	SetCursorPos 24, 0

	jsr FPGACheck
	jsr DSPCheck
	jsr SDRAMCheck

__ConfigureFPGADone:

	jsr LoadTheme				; load theme file data

__InDemoModeToIntroScreen:
	jsr ClearSpriteText			; clear sprite text so PrintRomVersion will use the sprite FWT from the loaded theme file



; --------------------------- load intro
GotoIntroScreen:
	HideCursorSprite			; necessary when returning here from another section

	jsr PrintRomVersion			; restore ROM version string (with sprite FWT from theme file)
	jsr ShowMainGFX				; set up OAM to show main sprite graphics

	lda #$00
	sta CONFIGWRITEDSP			; turn off DSP chip

	rep #A_8BIT				; A = 16 bit

	ldy #$0000				; clear out game name, save name, and clusters
	lda #$2020				; ASCII = 2 spaces (caveat: WLA DX assembles "lda #'  '" into "LDA #$0020"!)

-	sta gameName.gName, y
	sta saveName.sName, y
	iny
	iny
	cpy #$007C
	bne -

	stz gameName.gCluster
	stz gameName.gCluster+2

	stz saveName.sCluster
	stz saveName.sCluster+2

	stz Joy1New				; reset input buttons
	stz Joy1Press

	sep #A_8BIT				; A = 8 bit

	jsr GameGenieClearAll			; clear out Game Genie codes

	SetCursorPos 18, 19
	PrintString "Choose file ..."

	SetCursorPos 20, 19
	PrintString "Settings"

	SetCursorPos 22, 19
	PrintString "Play last game"



; -------------------------- show joypad button hints
	rep #A_8BIT				; A = 16 bit

	lda #$9898				; Y, X
	sta SpriteBuf1.Buttons

	lda #$03A0				; tile properties, tile num for A button
	sta SpriteBuf1.Buttons+2

	lda #$A898				; Y, X
	sta SpriteBuf1.Buttons+4

	lda #$03A6				; tile properties, tile num for X button
	sta SpriteBuf1.Buttons+6

	lda #$B896				; Y, X
	sta SpriteBuf1.Buttons+8

	lda #$03AC				; tile properties, tile num for Start button highlighted
	sta SpriteBuf1.Buttons+10

	sep #A_8BIT				; A = 8 bit



.IFDEF SHOWDEBUGMSGS
	SetCursorPos 0, 22

	rep #A_8BIT				; A = 16 bit

	tsc					; print stack pointer (initial value: $1FFF)

	sep #A_8BIT				; A = 8 bit

	xba
	sta temp
	PrintHexNum temp

	xba
	sta temp
	PrintHexNum temp

;	PrintHexNum DP_ThemeFileClusterLo
;	PrintHexNum DP_ThemeFileClusterLo+1
;	PrintString "-"
;	PrintHexNum DP_ThemeFileClusterHi
;	PrintHexNum DP_ThemeFileClusterHi+1
.ENDIF



	lda #%00110000				; activate HDMA channels 4 and 5
	sta DP_HDMAchannels

	lda #$00

-	wai					; screen fade-in loop

	inc a					; 15 / 3 = 5 frames
	inc a
	inc a
	sta $2100
	cmp #$0F
	bne -



; ***************************** Intro Loop *****************************

IntroLoop:
	wai

;	ClearLine 27
;	SetCursorPos 27, 1
;	PrintString "FPGA STATUS = "
;	lda CONFIGREADSTATUS
;	sta errorCode
;	PrintHexNum errorCode



; -------------------------- check for A button = go to ROM browser
	lda Joy1New
	and #%10000000
	beq +

	jsr SpriteMessageLoading
	jmp InitROMBrowser

+



; -------------------------- check for X button = go to settings
	lda Joy1New
	and #%01000000
	beq +

	jmp GotoSettings

+



; -------------------------- check for Y button = test SRM file creation // WIP
;	lda Joy1New+1
;	and #%01000000
;	beq +

;	jmp GotoSRMTest				; in main_cf_interface.inc.asm

;+



; -------------------------- check for Start button = load last game info
	lda Joy1New+1
	and #%00010000
	beq +

	jsr SpriteMessageLoading
	jsr LoadLastGame
	jmp GotoGameOptions

+

	bra IntroLoop



; ************************** Hardware checks ***************************

FPGACheck:
	lda #$00
	sta CONFIGWRITEDSP			; turn off DSP chip

	lda CONFIGREADSTATUS			; open bus = $20
	sta errorCode
	and #$F0
	cmp #$A0
	bne __FPGACheckFail
rts

__FPGACheckFail:
	jsr SpriteMessageError

	SetCursorPos 21, 1
	PrintString "FPGA check failed.\n  Error code: $"
	PrintHexNum errorCode

	jmp Forever



SDRAMCheck:
	lda $F00000
	sta errorCode

	lda #$55
	sta $F00000

	lda $F00000
	sta errorCode+1

	lda errorCode
	sta $F00000

	lda errorCode+1
	cmp #$55				; useless ?? (subsequent branch instruction missing ever since v1.0X)

	lda #$AA
	sta $F00000

	lda $F00000
	cmp #$AA
	bne __SDRAMError
rts

__SDRAMError:
	jsr SpriteMessageError

	SetCursorPos 21, 1
	PrintString "SDRAM check failed.\n  Error code: $"
	PrintHexNum $F00000

	jmp Forever



DSPCheck:
	SetCursorPos 6, 17

	lda #$04
	sta CONFIGWRITEDSP			; turn on HiROM chip

	lda.l $007000				; HiROM $00:6000 = DR, $00:7000 = SR
	sta errorCode
	and #%10000000
	beq __NoDSP

	PrintString "DSP1: installed"
	bra __DSPCheckDone

__NoDSP:
	PrintString "DSP1: not installed"

__DSPCheckDone:

rts



ShowChipsetDMA:
	jsr ShowConsoleVersion			; lines 9, 10, 11

	SetCursorPos 7, 17
	PrintString "DMA : "

	lda dontUseDMA
	bne __DMAOff

	PrintString "on "
	bra __ShowChipsetDMADone

__DMAOff:
	PrintString "off"

__ShowChipsetDMADone:

	SetCursorPos 13, 17
	PrintString "Video: "			; completed in the following subroutine

	jsr CheckFrameLength
rts



; ************************* Frame length check *************************

; This code snippet is roughly based on a Super GameBoy (rev 1.0) dis-
; assembly, which to my knowledge is the only commercial ROM to perform
; a fail-safe check like this.
;
; I don't fully understand why the Y counter value differs depending
; on the video refresh rate (50 or 60 Hz). In any case, the actual set-
; ting is correctly returned even on hardware that tries to "cheat" by
; overriding bit 4 of register $213F (e.g. ARP, Ultra16).

CheckFrameLength:
	sei					; disable NMI & IRQ so it won't interfere with timing
	stz REG_NMITIMEN

	phy
	ldy #$0000

-	bit REG_HVBJOY				; wait for Vblank
	bpl -

	lda REG_RDNMI				; bit 7 = Vblank NMI flag

-	iny
	lda REG_RDNMI
	bpl -

	lda REG_RDNMI

	lda #$00				; dunno what this is for, possibly timing-related?

	cpy #$15A0				; rough average between 50 and 60 Hz values (see debug section below)
	bcc __60hz
	PrintString "50 Hz"
	bra +

__60hz:
	PrintString "60 Hz"

+



.IFDEF SHOWDEBUGMSGS
; Print current counter value. The number varies depending both on the context of this subroutine and on
; what happens during Vblank, so it's necessary to re-measure after changing anything. Also, the currently
; selected HDMA design has a slight influence (hence the XX). Some measured values:
; @50Hz: $17XX (U16, PAL/1Chip, PAL/2PPUs)
; @60Hz: $13XX (U16, PAL/1Chip modded, US/GPM-01, PAL/2PPUs modded, 1/1/1 chipset SFC)

	SetCursorPos 0, 22

	rep #A_8BIT				; A = 16 bit

	tya

	sep #A_8BIT				; A = 8 bit

	xba
	sta temp
	PrintHexNum temp

	xba
	sta temp
	PrintHexNum temp
.ENDIF



	ply

	lda #$81				; re-enable Vblank NMI + automatic joypad reading
	sta REG_NMITIMEN

	cli
rts



Forever:
	lda #%00110000				; activate HDMA channels 4 and 5 (BG color gradient, windowing)
	sta DP_HDMAchannels

	lda #$0F				; turn on the screen in case we're still in forced blank
	sta $2100

	lda #$81				; enable Vblank NMI + automatic joypad reading
	sta REG_NMITIMEN

	cli

__ForeverLoop:
	wai					; wait for next frame
	bra __ForeverLoop



PrintRomVersion:
	PrintSpriteText 3, 19, "SNES PowerPak", 3

	SetCursorPos 3, 17
	ldy #PTR_Firmware_Version
	PrintString "%s"			; --> Firmware v3.XX "MUFASA"

	SetCursorPos 4, 17
	ldy #PTR_Firmware_Build
	PrintString "(%s)"			; --> (Build #XXXXX)
rts



; ************************ Show main sprite GFX ************************

; To fill OAM most efficiently, there is an "inner loop" for each row
; of 8 large (16×16) sprites, and an "outer loop" for the imagined
; "carriage returns".

; X: $08 $18 $28 $38 $48 $58 $68 $78 in "inner loop", then reset value in "outer loop"
; Y: unchanged in "inner loop", $08 $18 $28 $38 $48 $58 $68 $78 in "outer loop"
; tile num: $X0 $X2 $X4 $X6 $X8 $XA $XC $XE in "inner loop", $0X $2X $4X $6X $8X $AX $CX $EX in "outer loop"

ShowMainGFX:
	rep #A_8BIT				; A = 16 bit

	lda #$0808				; Y, X start values of upper left corner of 128×128 main GFX
	sta temp

	lda #$0080				; tile properties (fixed), tile num (start value)
	sta temp+2

	ldx #$0000

-	lda temp				; Y, X
	sta SpriteBuf1.MainGFX, x
	clc
	adc #$0010				; X += 16
	sta temp
	inx
	inx

	lda temp+2				; tile properties, tile num
	sta SpriteBuf1.MainGFX, x
	clc
	adc #$0002				; tile num += 2
	sta temp+2
	inx
	inx

	bit #$000F				; check if last 4 bits of tile num clear = one row of 8 (large) sprites done?
	bne -					; "inner loop"

	lda temp
	and #$FF08				; reset X = 8
	clc
	adc #$1000				; Y += 16
	sta temp

	lda temp+2
	clc
	adc #$0010				; tile num += 16 (i.e., skip one row of 8×8 tiles)
	sta temp+2

	cpx #$0100				; 256 / 4 = 64 (large) sprites done?
	bne -					; "outer loop"



; -------------------------- fill high OAM
	lda #%1010101010101010			; large sprites

	ldx #$0000

-	sta SpriteBuf2.MainGFX, x
	inx
	inx
	cpx #$0010
	bne -

	sep #A_8BIT				; A = 8 bit
rts



; ********************** Get entry into tempEntry **********************

; This function calculates selectedEntry's buffer address, then copies
; the 128-byte-long entry to the tempEntry variable.
;
; WRAM procedure (using the upper 64K only):
; sourceEntryLo[16bit] = selectedEntry[16bit] × 128
; max. 512 entries, last entry's address = $FF80 (in bank $7F)
;
; SDRAM procedure (using the lower 8MB only):
; DMAWRITELO[24bit] = selectedEntry[16bit] × 128
; max. 65535 entries, last entry's address = $7FFF80
;
; Calculation code using bitwise operations is based on a code snippet
; by thefox. We "shift" selectedEntry[16bit] left 8 bits (no actual
; shifting because it's on byte boundary), then shift the whole value
; right one bit.

DirGetEntry:
	lda CLDConfigFlags			; check for buffer location
	and #%00000001
	beq __GetEntryFromWRAM

	lda selectedEntry+1			; get entry from SDRAM
	lsr a
	sta DMAWRITEBANK

	lda selectedEntry
	ror a
	sta DMAWRITEHI

	lda #$00
	ror a
	sta DMAWRITELO

	ldy #$0000

__GetEntryFromSDRAMLoop:
	lda DMAREADDATA
	sta tempEntry, y
	iny
	cpy #$0080
	bne __GetEntryFromSDRAMLoop
rts



__GetEntryFromWRAM:
	lda #$01				; set bank = $7F
	sta $2183

	lda selectedEntry+1
	lsr a					; selectedEntry+1 into carry bit

	lda selectedEntry
	ror a
	sta $2182

	lda #$00
	ror a
	sta $2181

	ldy #$0000

__GetEntryFromWRAMLoop:
	lda $2180
	sta tempEntry, y
	iny
	cpy #$0080
	bne __GetEntryFromWRAMLoop
rts



; ************************ Find specific entry *************************

DirFindEntry:
	rep #A_8BIT				; A = 16 bit

	stz selectedEntry			; reset selectedEntry

	lda filesInDir				; only do the search if directory isn't empty
	beq __DirFindEntryFailed

__DirFindEntryLoop:
	sep #A_8BIT				; A = 8 bit

	jsr DirGetEntry

	ldy #$0000

__DirFindEntryCharLoop:				; check if entry matches, only look at first 8 chars
	lda tempEntry, y
	cmp findEntry, y
	bne __DirFindEntryNext

	iny
	cpy #$0008
	bne __DirFindEntryCharLoop
rts						; all 8 chars match

__DirFindEntryNext:
	rep #A_8BIT				; A = 16 bit

	inc selectedEntry			; increment to next entry index

	lda selectedEntry			; check for max. no. of files
	cmp filesInDir
	bne __DirFindEntryLoop

__DirFindEntryFailed:
	sep #A_8BIT				; A = 8 bit

	jsr PrintClearScreen
	jsr HideButtonSprites
	jsr SpriteMessageError

	SetCursorPos 21, 1

	ldx #$0000

-	lda findEntry, x
	cmp #' '				; only load actual filename characters to print 
	beq +
	inx
	cpx #$0008
	bne -

+	stz findEntry, x			; NUL-terminate filename string at first space, or after 8 chars

	ldy #PTR_findEntry

	PrintString "%s"

	lda extMatch1				; next, load file extension into tempEntry for printing
	beq +					; if extension starts with a zero ...
	cmp #' '				; ... or a space ...
	beq +					; ... then directory, skip extension

	sta tempEntry				; otherwise, copy file extension

	lda extMatch2
	sta tempEntry+1

	lda extMatch3
	sta tempEntry+2

	stz tempEntry+3				; NUL-terminate file extension string

	ldy #PTR_tempEntry

	PrintString ".%s"			; result: e.g. "UPDATE.ROM file not found!"
+	PrintString " file not found!"		; or (if dir) "POWERPAK file not found!"

	jmp Forever



; ************************ Save/load last game *************************

LoadLastGame:
	FindFile "LASTGAME.LOG"

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

	rep #A_8BIT				; A = 16 bit

	ldy #$0000
	ldx #$0000

LoadLastGameLoop:				; game name and cluster
	lda sectorBuffer1, y
	sta gameName, x
	inx
	inx
	iny
	iny
	cpx #$0080				; 128 bytes
	bne LoadLastGameLoop

	ldx #$0000

LoadLastSaveLoop:				; save name and cluster
	lda sectorBuffer1, y
	sta saveName, x
	inx
	inx
	iny
	iny
	cpx #$0080				; 128 bytes
	bne LoadLastSaveLoop

	ldx #$0000

LoadLastGameGenieLoop:				; GameGenie codes
	lda sectorBuffer1, y
	beq __LoadLastEmptyLOG			; unused GG codes are filled with $10s, so no zeroes allowed
	sta GameGenie.Codes, x
	inx
	inx
	iny
	iny
	cpx #$0028
	bne LoadLastGameGenieLoop

	sep #A_8BIT				; A = 8 bit
rts

__LoadLastEmptyLOG:				; zeroes within GG code list detected --> LOG file must be empty

.ACCU 16

	pla					; clean up the stack as there's no rts from "jsr LoadLastGame" in case of an error

	sep #A_8BIT				; A = 8 bit

	jsr PrintClearScreen
	jsr SpriteMessageError

	SetCursorPos 21, 1
	PrintString "LASTGAME.LOG appears to be empty or corrupt!\n"
	PrintString "  Press any button to return to the titlescreen."

	WaitForUserInput

	jsr PrintClearScreen
	jmp GotoIntroScreen



SaveLastGame:
	FindFile "LASTGAME.LOG"

	rep #A_8BIT				; A = 16 bit

	ldy #$0000
	ldx #$0000

SaveLastGameLoop:				; game name and cluster
	lda gameName, x
	sta sectorBuffer1, y
	inx
	inx
	iny
	iny
	cpx #$0080				; 128 bytes
	bne SaveLastGameLoop

	ldx #$0000

SaveLastSaveLoop:				; save name and cluster
	lda saveName, x
	sta sectorBuffer1, y
	inx
	inx
	iny
	iny
	cpx #$0080				; 128 bytes
	bne SaveLastSaveLoop

	ldx #$0000

SaveLastGameGenieLoop:				; GameGenie codes
	lda GameGenie.Codes, x
	sta sectorBuffer1, y
	inx
	inx
	iny
	iny
	cpx #$0028				; 5 * 8 = 40 bytes
	bne SaveLastGameGenieLoop

	lda #$0000				; fill rest of LASTGAME.LOG with zeroes
-	sta sectorBuffer1, y
	iny
	iny
	cpy #$0200				; 512 bytes total
	bne -

	sep #A_8BIT				; A = 8 bit

	lda #<sectorBuffer1
	sta sourceLo
	lda #>sectorBuffer1
	sta sourceHi

	lda #kSourceWRAM
	sta sourceType

	jsr CardWriteFile
rts



; ***************************** Load FPGA ******************************

CardLoadFPGA:
	lda #$01
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA
	lda #$00
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA
	wai
	wai
	lda #$01
	sta FPGAPROGRAMWRITE			; SEND PROGRAM SIGNAL TO FPGA

	stz sectorCounter			; BIT file cluster already in sourceCluster
	stz bankCounter

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

	wai

	lda #$80
	sta $2100				; turn screen off

CardLoadFPGALoop:
	lda #kDestFPGA
	sta destType

	jsr CardReadSector			; sector -> FPGA
	jsr LoadNextSectorNum

	rep #A_8BIT				; A = 16 bit

; check for last sector
; FAT32 last cluster = 0x0FFFFFFF
; FAT16 last cluster = 0x0000FFFF

	lda fat32Enabled			; check for FAT32
	and #$0001
	bne __FPGALastClusterMaskFAT32

	stz temp+2				; if FAT16, high word = $0000
	bra __FPGALastClusterMaskDone

__FPGALastClusterMaskFAT32:
	lda #$0FFF				; if FAT32, high word = $0FFF
	sta temp+2

__FPGALastClusterMaskDone:			; if cluster = last cluster, jump to last entry found
	lda sourceCluster
	cmp #$FFFF				; low word = $FFFF (FAT16/32)
	bne __FPGANextSector

	lda sourceCluster+2
	cmp temp+2
	bne __FPGANextSector

	sep #A_8BIT				; A = 8 bit

	bra __LoadFPGADone			; last cluster, jump out

__FPGANextSector:
	sep #A_8BIT				; A = 8 bit

	inc bankCounter

	lda bankCounter
	cmp #$6B				; 437312 bits = 54664 bytes = 107 sectors = $6B
	bne CardLoadFPGALoop

__LoadFPGADone:

;	lda #$0F
;	sta $2100				; turn screen on // never mind, done on intro screen
rts



; ************************* Clear "find entry" *************************

ClearFindEntry:
	rep #A_8BIT				; A = 16 bit

	lda #$2020				; ASCII = 2 spaces (caveat #1: WLA DX assembles "lda #'  '" to "LDA #$0020"!)
	sta findEntry				; Caveat #2: It's crucially important to clear out findEntry with spaces (not zeroes)
	sta findEntry+2				; due to the way the FAT filesystem handles short file names < 8 characters!
	sta findEntry+4
	sta findEntry+6

	sep #A_8BIT				; A = 8 bit
rts



; ************************** Log error output **************************

LogScreen:
	stz $2183				; set WRAM address to log buffer for writing (expected in bank $7E)

	ldx #(LogBuffer & $FFFF)		; get low word
	stx $2181

	ldx #$0000				; next, "deinterleave" hi-res text buffer

-	lda TextBuffer.BG1, x
	lsr a					; reconvert hi-res tile to plain ASCII
	sta $2180				; copy it to log buffer

	lda TextBuffer.BG2, x			; same thing for BG2
	lsr a
	sta $2180

	inx
	cpx #$0400				; 1024 bytes per BG (lower 32×32 tilemaps only)
	bne -

	FindFile "ERROR.LOG"			; save to file

	lda #<LogBuffer
	sta sourceLo

	lda #>LogBuffer
	sta sourceHi

	lda #$7E
	sta sourceBank

	lda #kSourceWRAM
	sta sourceType

	jsr CardWriteFile
rts



; *************************** Misc. messages ***************************

ShowConsoleVersion:
	lda REG_RDNMI				; CPU revision
	and #$0F				; mask off Vblank NMI flag and open bus (bits 4-6)
	sta temp

	rep #A_8BIT				; A = 16 bit

	lda $213E				; PPU1/2 revisions
	and #$0F0F				; mask off other/open bus flags
	sta temp+1

	sep #A_8BIT				; A = 8 bit

	ldy #temp

	SetCursorPos 9, 17
	PrintString "CPU : v%b"

	ldy #temp+1

	SetCursorPos 10, 17
	PrintString "PPU1: v%b"

	ldy #temp+2

	SetCursorPos 11, 17
	PrintString "PPU2: v%b"
rts



SpriteMessageLoading:
	HideCursorSprite

	jsr HideButtonSprites
	jsr HideLogoSprites
	jsr PrintClearScreen

	PrintSpriteText 12, 12, "Loading ...", 7

	wai					; make sure it appears on the screen
rts



SpriteMessageError:
	PrintSpriteText 21, 3, "Error!", 4
rts



PrintCardFS:
	SetCursorPos 5, 17
	PrintString "Card: FAT"			; completed subsequently

	lda fat32Enabled
	cmp #$01
	beq __FAT32enabled

	PrintString "16"
	bra __PrintCardFSDone

__FAT32enabled:
	PrintString "32"

__PrintCardFSDone:

rts



; *********************** Music loading routines ***********************

LoadDevMusic:
	sei					; disable NMI & IRQ before loading music
	stz REG_NMITIMEN

	jsl spcBoot				; boot SNESMOD

	lda #:SOUNDBANK				; give soundbank
	sta spc_bank

;	ldx #SOUNDBANK				; load module into SPC
	ldx #$0000

	jsl spcLoad

	lda #39					; allocate around 10K of sound ram (39 256-byte blocks)

	jsl spcAllocateSoundRegion

	lda #$81				; done, re-enable Vblank NMI + Auto Joypad Read
	sta REG_NMITIMEN
	cli
rts



; ******************************** EOF *********************************
