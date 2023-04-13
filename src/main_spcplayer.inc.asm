;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: SPC PLAYER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.ACCU 8
.INDEX 16

GotoSPCplayer:
	stz	DP_WarmBootFlags					; clear all warm-boot flags
	lda	#$82							; overwrite cursor sprite with empty sprite (i.e., effectively "hide" cursor without losing its position data)
	sta	SpriteBuf1.Cursor+2
	lda	#%00100000						; disable HDMA windowing channel --> "empty" screen without losing text buffer content
	trb	DP_HDMAchannels

	PrintSpriteText 12, 9, "Loading SPC file ...", 6

	wai								; wait for screen update
	lda	#$00							; read file to SDRAM
	sta	DMAWRITELO
	sta	DMAWRITEHI
	lda	#$90							; any SDRAM bank >= $80 will do (in order not to destroy the dir buffer)
	sta	DMAWRITEBANK
	stz	sectorCounter
	stz	bankCounter
	jsr	CardReadFile						; read selected SPC file (source cluster already set in ROM browser)
	lda	#$90							; pre-fetch some variables for spc700_load
	sta	DMAWRITEBANK
	lda	#$00
	sta	DMAWRITEHI
	lda	#$25
	sta	DMAWRITELO
	lda	DMAREADDATA						; PC $25 (reminder: DMAREADDATA auto-increments)
	sta	audioPC
	lda	DMAREADDATA						; PC $26
	sta	audioPC+1
	lda	DMAREADDATA						; A = $27
	sta	audioA
	lda	DMAREADDATA						; X = $28
	sta	audioX
	lda	DMAREADDATA						; Y = $29
	sta	audioY
	lda	DMAREADDATA						; PSW = $2A
	sta	audioPSW
	lda	DMAREADDATA						; SP = $2B
	sta	audioSP
	lda	#$01
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITELO
	lda	DMAREADDATA						; first two bytes of SPC RAM
	sta	spcRAM1stBytes
	lda	DMAREADDATA
	sta	spcRAM1stBytes+1
	lda	#$F1
	sta	DMAWRITELO
	lda	DMAREADDATA						; DSP CONTROL register
	sta	spcCONTROLReg
	lda	DMAREADDATA						; $F2 = DSP register address
	sta	spcDSPRegAddr
	lda	#$F4
	sta	DMAWRITELO
	lda	DMAREADDATA						; DSP IO port $F4
	sta	spcIOPorts
	lda	DMAREADDATA						; DSP IO port $F5
	sta	spcIOPorts+1
	lda	DMAREADDATA						; DSP IO port $F6
	sta	spcIOPorts+2
	lda	DMAREADDATA						; DSP IO port $F7
	sta	spcIOPorts+3
	lda	#$91
	sta	DMAWRITEBANK
	lda	#$01
	sta	DMAWRITEHI
	lda	#$4C
	sta	DMAWRITELO
	lda	DMAREADDATA						; DSP KON register
	sta	spcKONReg
	lda	#$6C
	sta	DMAWRITELO
	lda	DMAREADDATA						; DSP FLG register
	sta	spcFLGReg
	jsl	spc700_load						; now load SPC file to SPC700
	phk								; set data bank = program bank (required because spc700_load was relocated to ROM bank 2 for v3.00)
	plb
	jsr	ClearSpriteText						; remove "Loading ..." message

	DrawFrame 0, 6+32, 31, 16

	lda	scrollY							; patch HDMA table in WRAM with current Y scroll offset
	sta	HDMAtable.ScrollBG1+3
	sta	HDMAtable.ScrollBG1+18
	sta	HDMAtable.ScrollBG2+3
	sta	HDMAtable.ScrollBG2+18
	lda	#%11101000						; (re)enable color math, windowing, and scroll offset "patch" channels
	tsb	DP_HDMAchannels

;	SetTextPos 5+32, 10
;	PrintString " ~ SPC PLAYER ~"
	PrintSpriteText 7, 10, "~ SPC PLAYER ~", 3
;	SetTextPos 7+32, 12
;	PrintString "XX:XX:XX"						; placeholder for the timer

	stz	tempEntry+58						; NUL-terminate entry string after 58 characters
	ldy	#PTR_tempEntry						; tempEntry holds name of SPC file currently playing

	SetTextPos 9+32, 0
	PrintString "File name:\\n%s"

	lda	#$90							; next, read and display tag info
	sta	DMAWRITEBANK
	lda	#$00
	sta	DMAWRITEHI
	lda	#$2E
	sta	DMAWRITELO
	ldx	#$0000

CopySongTitle:								; song title
	lda	DMAREADDATA
	sta	tempEntry, x
	inx
	cpx	#$0020							; 32 chars
	bne	CopySongTitle

	stz	tempEntry, x						; NUL-terminate song title string
	ldy	#PTR_tempEntry

	SetTextPos 12+32, 0
	PrintString "Song title: %s"

	ldx	#$0000

CopyGameTitle:								; game title
	lda	DMAREADDATA
	sta	tempEntry, x
	inx
	cpx	#$0020
	bne	CopyGameTitle

	stz	tempEntry, x						; NUL-terminate game title string
	ldy	#PTR_tempEntry

	SetTextPos 13+32, 0
	PrintString "Game title: %s"

	lda	#$B1							; jump to position of artist's name
	sta	DMAWRITELO
	ldx	#$0000

CopyArtist:								; artist
	lda	DMAREADDATA
	sta	tempEntry, x
	inx
	cpx	#$0020
	bne	CopyArtist

	stz	tempEntry, x						; NUL-terminate artist string
	ldy	#PTR_tempEntry

	SetTextPos 14+32, 0
	PrintString "Artist(s) : %s"

	lda	#$6E							; jump to position of dumper ID
	sta	DMAWRITELO
	ldx	#$0000

CopyDumper:								; name of dumper
	lda	DMAREADDATA
	sta	tempEntry, x
	inx
	cpx	#$0010
	bne	CopyDumper

	stz	tempEntry, x						; NUL-terminate dumper string
	ldy	#PTR_tempEntry

	SetTextPos 15+32, 0
	PrintString "Dumped by : %s"

	ldx	#$0000

CopyComments:								; comments
	lda	DMAREADDATA
	sta	tempEntry, x
	inx
	cpx	#$0020
	bne	CopyComments

	stz	tempEntry, x						; NUL-terminate comments string
	ldy	#PTR_tempEntry

	SetTextPos 16+32, 0
	PrintString "Comment(s): %s"

	ldx	#$0000

CopyDate:								; date
	lda	DMAREADDATA
	sta	tempEntry, x
	inx
	cpx	#$000B
	bne	CopyDate

	stz	tempEntry, x						; NUL-terminate date string
	ldy	#PTR_tempEntry

	SetTextPos 17+32, 0
	PrintString "Datestamp : %s"



; -------------------------- show button hints
	Accu16

	lda	#$A018							; Y, X
	sta	SpriteBuf1.Buttons
	lda	#$03A8							; tile properties, tile num for d-pad l/r
	sta	SpriteBuf1.Buttons+2
	lda	#$A0C0							; Y, X
	sta	SpriteBuf1.Buttons+4
	lda	#$03A2							; tile properties, tile num for B button
	sta	SpriteBuf1.Buttons+6

	Accu8

	SetTextPos 19+32, 3
	PrintString "Autoplay: "
	PrintSpriteText 21, 14, "L", 3
	SetTextPos 19+32, 13
	PrintString "prev"
	PrintSpriteText 21, 19, "R", 3
	SetTextPos 19+32, 18
	PrintString "next"
	SetTextPos 19+32, 24
	PrintString "Back"

	dec	SpriteBuf1.Text+56					; move the "L" a bit more to the left
	dec	SpriteBuf1.Text+56
	dec	SpriteBuf1.Text+60					; and the "R", too
	dec	SpriteBuf1.Text+60					; dec dec: 6 + 6 = 12 cycles, lda sec sbc sta: 4 + 2 + 2 + 4 = 12 cycles, meh :D



; -------------------------- reset some variables
	Accu16

	stz	spcTimer						; frame counter / timer seconds
	stz	spcTimer+2						; timer minutes / unused
;	stz	Joy1New							; reset input buttons
;	stz	Joy1Press

	Accu8



; -------------------------- player loop
SPCPlayerLoop:
	SetTextPos 7+32, 12						; timer position
	PrintHexNum spcTimer+2
	PrintString ":"
	PrintHexNum spcTimer+1
	PrintString ":"
	PrintHexNum spcTimer

	SetTextPos 19+32, 8						; position of auto-play setting

	lda	DP_SPCPlayerFlags
;	and	#%00000111						; mask off reserved bits (not necessary for now)
	bne	+

	PrintString "off   "						; auto-play flag clear, so auto-play is off 

	bra	@PrintAutoPlayDone

+	sta	temp							; print auto-play time
	ldy	#temp

	PrintString "%b min."

@PrintAutoPlayDone:
	wai

	lda	REG_STAT78						; check display refresh rate
	and	#%00010000
	bne	@IncTimerPAL						; increment seconds depending on framerate

@IncTimerNTSC:
	sed								; decimal mode on
	clc
	lda	spcTimer
	adc	#$01
	sta	spcTimer
	cmp	#$60							; if NTSC, increment seconds every 60th frame
	bcc	@CalcTimerSeconds
	stz	spcTimer						; carry bit set, reset frame counter
	bra	@CalcTimerSeconds

@IncTimerPAL:
	sed								; decimal mode on
	clc
	lda	spcTimer
	adc	#$01
	sta	spcTimer
	cmp	#$50							; if PAL, increment seconds every 50th frame
	bcc	@CalcTimerSeconds
	stz	spcTimer						; carry bit set, reset frame counter

@CalcTimerSeconds:
	lda	spcTimer+1						; increment seconds via carry bit
	adc	#$00
	sta	spcTimer+1
	cmp	#$60							; check if 60 seconds have elapsed
	bcc	@CalcTimerMinutes
	stz	spcTimer+1						; carry bit set, reset seconds

@CalcTimerMinutes:
	lda	spcTimer+2						; increment minutes via carry bit
	adc	#$00
	sta	spcTimer+2
	cmp	#$60							; check if 60 minutes have elapsed
	bcc	@CalcTimerDone
	stz	spcTimer+2						; if 59:59 reached, reset timer

@CalcTimerDone:
	cld								; decimal mode off



; -------------------------- check for d-pad left (auto-play control)
	lda	Joy1New+1
	and	#%00000010
	beq	@DpadLeftDone
	lda	DP_SPCPlayerFlags
;	and	#%00000111						; mask off reserved bits (not necessary for now)
	beq	@DpadLeftDone						; if auto-play is off, jump out
	dec	DP_SPCPlayerFlags					; otherwise, DP_SPCPlayerFlags -= 1

@DpadLeftDone:



; -------------------------- check for d-pad right (auto-play control)
	lda	Joy1New+1
	and	#%00000001
	beq	@DpadRightDone
	lda	DP_SPCPlayerFlags
;	and	#%00000111						; mask off reserved bits (not necessary for now)
	cmp	#7
	bcs	@DpadRightDone						; if time setting was 7 minutes (highest setting), jump out
	inc	DP_SPCPlayerFlags					; otherwise, DP_SPCPlayerFlags += 1

@DpadRightDone:



; -------------------------- check for L shoulder button = previous SPC file (via warm boot)
	lda	Joy1Press
	and	#%00100000
	beq	@LButtonDone
	lda	#%10000000						; set "go to SPC player" flag
	sta	DP_WarmBootFlags
	lda	#%00101000						; disable HDMA windowing & color math channels
	trb	DP_HDMAchannels
	jsr	ClearSpriteText
	jsr	HideButtonSprites
	jsr	SpriteMessageSearching

@CheckPrevFile:
	lda	cursorYCounter
	bne	+
	lda	scrollYCounter
	bne	+
	lda	#$08
	sta	speedScroll
	lda	#$01
	sta	speedCounter
	jsr	ScrollUp

+	lda	#%00000011						; use SDRAM buffer, skip hidden files in next dir
	sta	CLDConfigFlags
	jsr	DirGetEntry						; get selected entry
	lda	tempEntry.Flags						; check for "dir" flag
	and	#$01
	bne	@CheckPrevFile

	ldx	#4							; jump table index 4 = go to previous file
	jmp	FileBrowserCheckSPCFile

@LButtonDone:



; -------------------------- check for R shoulder button = next SPC file (via warm boot)
	lda	Joy1Press
	and	#%00010000
	beq	@RButtonDone

@LoadNextSPC:
	lda	#%10000000						; set "go to SPC player" flag
	sta	DP_WarmBootFlags
	lda	#%00101000						; disable HDMA windowing & color math channels
	trb	DP_HDMAchannels
	jsr	ClearSpriteText
	jsr	HideButtonSprites
	jsr	SpriteMessageSearching

@CheckNextFile:
	lda	cursorYCounter
	bne	+
	lda	scrollYCounter
	bne	+
	lda	#$08
	sta	speedScroll
	lda	#$01
	sta	speedCounter
	jsr	ScrollDown

+	lda	#%00000011						; use SDRAM buffer, skip hidden files in next dir
	sta	CLDConfigFlags
	jsr	DirGetEntry						; get selected entry
	lda	tempEntry.Flags						; check for "dir" flag
	and	#$01
	bne	@CheckNextFile

	ldx	#2							; jump table index 2 = go to next file
	jmp	FileBrowserCheckSPCFile

@RButtonDone:



; -------------------------- check for B button = reset PowerPak (warm boot)
	lda	Joy1Press+1
	bmi	InitWarmBoot

@BButtonDone:



; -------------------------- auto-play handler
	lda	DP_SPCPlayerFlags
;	and	#%00000111						; mask off reserved bits (not necessary for now)
	beq	+							; MSB clear --> auto-play is off
	cmp	spcTimer+2
	beq	@LoadNextSPC						; if minutes match, load next SPC file
	bcc	@LoadNextSPC						; ditto when auto-play setting < timer
+	jmp	SPCPlayerLoop



InitWarmBoot:
	stz	REG_INIDISP						; warm boot requested, make screen black (see below)
	lda	#kWarmBoot1						; write warm boot signature
	sta	DP_ColdBootCheck1
	lda	#kWarmBoot2
	sta	DP_ColdBootCheck2
	lda	#kWarmBoot3
	sta	DP_ColdBootCheck3
	stz	DP_HDMAchannels						; disable HDMA (background color gradient channel might destroy the palette on 50 Hz)
	wai								; wait for HDMA register to clear
	tsx
	stx	DP_StackPointer_BAK					; back up stack pointer
	lda	#%10000001
	sta	CONFIGWRITESTATUS					; reset PowerPak, stay in boot mode



SpriteMessageSearching:
	PrintSpriteText 12, 6, "Searching for SPC file ...", 7

	wai
	rts



; ******************************** EOF *********************************
