;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** GLOBAL MACROS ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;	- Neviksti (some macros), (c) 2002
;
;==========================================================================================



; ******************************* Macros *******************************

; SetCursorPos  y, x

.MACRO SetCursorPos
	ldx #32*\1+32*minPrintY + \2+minPrintX	; add values of indention constants
	stx Cursor
	stz BGPrintMon				; reset BG monitor value to zero (start on BG1)
.ENDM



.MACRO ClearLine
	clc
	lda.b #\1
	adc.b #minPrintY			; add Y indention

	jsr PrintClearLine
.ENDM



.MACRO PrintString				; shortened for v3.00 by ManuLöwe
	jsr PrintF

	.DB \1, 0				; instead of a return address (-1), the string address (-1) gets pushed onto the stack
.ENDM



;here's a macro for printing a number (a byte)
;
; ex:  PrintNum $2103 	;print value of reg $2103
;      PrintNum #9	;print 9

.MACRO PrintNum
	lda \1

	jsr PrintInt8_noload
.ENDM



.MACRO PrintHexNum
	lda \1

	jsr PrintHex8_noload
.ENDM



; Macro WaitForUserInput by ManuLöwe (added for v3.00)
;
; Usage: WaitForUserInput
; Effect: Waits for the user to press any button (d-pad is ignored).

.MACRO WaitForUserInput
	rep #A_8BIT				; A = 16 bit

__CheckJoypad\@:
	wai

	lda Joy1New
	and #$F0F0				; B, Y, Select, Start (no d-pad), A, X, L, R

	beq __CheckJoypad\@

	sep #A_8BIT				; A = 8 bit
.ENDM



; Macro DelayFor by ManuLöwe (added for v3.00, debug sections only)
;
; Usage: DelayFor <number_of_frames>
; Effect: Waits for the given amount of frames.

.MACRO DelayFor
	ldx #\1

__FrameDelay\@:
	wai
	dex
	bne __FrameDelay\@
.ENDM



; Macro DrawFrame by ManuLöwe (added for v3.00)
;
; Usage: DrawFrame <x_start>, <y_start>, <width>, <height>
; Effect: Draws a frame using the BGX text buffer (caveat: window masking applies).

.MACRO DrawFrame

; -------------------------- draw upper border
	ldx #32*\2 + \1

	lda #$20				; upper left corner
	sta TextBuffer.BG1, x			; start on BG1

	lda #$22				; horizontal line

__DrawUpperBorder\@:
	sta TextBuffer.BG2, x

	inx

	sta TextBuffer.BG1, x

	cpx #32*\2 + \1 + \3
	bne __DrawUpperBorder\@

	lda #$24				; upper right corner
	sta TextBuffer.BG2, x

	bra __GoToNextLine\@

; -------------------------- draw left & right border
__DrawLRBorder\@:
	lda #$26				; left vertical line
	sta TextBuffer.BG1, x

;	rep #A_8BIT				; A = 16 bit

;	txa
;	clc
;	adc #\3					; go to right border
;	tax

;	sep #A_8BIT				; A = 8 bit

	lda #$40				; space

	ldy #$0000

__ClearTextInsideFrame\@:
	sta TextBuffer.BG2, x

	inx

	sta TextBuffer.BG1, x

	iny
	cpy #\3
	bne __ClearTextInsideFrame\@

	lda #$28				; right vertical line
	sta TextBuffer.BG2, x

__GoToNextLine\@:
	rep #A_8BIT				; A = 16 bit

	txa
	clc
	adc #32 - \3				; go to next line
	tax

	sep #A_8BIT				; A = 8 bit

	cpx #32*(\2+\4) + \1
	bne __DrawLRBorder\@

; -------------------------- draw lower border
	lda #$2A				; lower left corner
	sta TextBuffer.BG1, x

	lda #$22				; horizontal line

__DrawLowerBorder\@:
	sta TextBuffer.BG2, x

	inx

	sta TextBuffer.BG1, x

	cpx #32*(\2+\4) + \1 + \3
	bne __DrawLowerBorder\@

	lda #$2C				; lower right corner
	sta TextBuffer.BG2, x
.ENDM



; Macro PrintSpriteText by ManuLöwe (added for v3.00)
;
; Usage: PrintSpriteText <y_coordinate>, <x_coordinate>, "Lorem ipsum ...", <font_color>
; Effect: Prints a sprite-based 8*8 VWF text string (max length: 32 characters). Coordinate values work as with SetCursorPos, but no indention is added (0, 0 = upper left screen corner). Valid font colors are palette numbers 3 (white), 4 (red), 5 (green), 6 (blue), or 7 (yellow).

.MACRO PrintSpriteText
	ldx #((8*\1)-2)<<8 + 8*\2
	stx Cursor

	lda #\4
	sta DP_SprTextPalette

	jsr PrintSpriteText

	.DB \3, 0				; the string address (-1) gets pushed onto the stack
.ENDM



; Macro HideCursorSprite by ManuLöwe (added for v3.00)
;
; Usage: HideCursorSprite
; Effect: Moves cursor sprite graphics off the screen.

.MACRO HideCursorSprite
	lda.b #$FF				; hide cursor
	sta.b cursorX

	lda.b #$F0
	sta.b cursorY
.ENDM



; DMA macro by ManuLöwe (added for v2.01)
;
; Usage: DMA_CH0 mode[8bit], A_bus_bank[8bit], A_bus_src[16bit], B_bus_register[8bit], length[16bit]
; Effect: Transfers data via DMA channel 0. For use during Vblank/Forced Blank only.
;
; Expects: A 8 bit, X/Y 16 bit

.MACRO DMA_CH0
	lda #\1					; DMA mode (8 bit)
 	sta $4300

	lda #\4					; B bus register (8 bit)
	sta $4301

	ldx #\3					; data offset (16 bit)
	stx $4302

	lda #\2					; data bank (8 bit)
	sta $4304

	ldx #\5					; data length (16 bit)
	stx $4305

	lda #%00000001				; initiate DMA transfer (channel 0)
	sta $420B
.ENDM



; DMA (with wait-for-Hblank) macro by ManuLöwe (added for v2.01)
;
; Usage: DMA_WaitHblank mode[8bit], A_bus_bank[8bit], A_bus_src_hi[8bit], A_bus_src_lo[8bit], B_bus_register[8bit], length[16bit variable]
;
; Effect: Waits for Hblank, then transfers data via DMA channel 1.
; For use during active display, with a standard data length of 512 bytes.
; Timing is optimized in such a way that the DMA transfer is interrupted once by
; the next HDMA transfer, and ends long before another HDMA transfer (to work
; around DMA <> HDMA conflicts/crashes on CPU rev. 1 consoles).
;
; Expects: A 8 bit, X/Y 16 bit

.MACRO DMA_WaitHblank

__WaitForHblank\@:
	bit REG_HVBJOY				; wait for Hblank period flag to get set
	bvc __WaitForHblank\@

	lda #\1					; DMA mode (8 bit)
 	sta $4310

	lda #\5					; B bus register (8 bit)
	sta $4311

	lda #\4					; data offset, low byte (8 bit)
	sta $4312

	lda #\3					; data offset, high byte (8 bit)
	sta $4313

	lda #\2					; data bank (8 bit)
	sta $4314

	ldx \6					; data length (sourceBytes16 variable, 512 bytes)
	stx $4315

	lda #%00000010				; initiate DMA transfer (channel 1)
	sta $420B
.ENDM



; Macro FindFile by ManuLöwe (added for v2.00)
;
; Usage (files): FindFile "FILE.EXT"
; Usage (dirs) : FindFile "DIRNAME.   "
; Effect: Puts first cluster of file/directory into sourceCluster.
;
; Restrictions:
; - can only find a single file at a time
; - only searches the POWERPAK directory (for CF modules and other firmware-related files)
; - the filename has to be in strict 8.3 format

.MACRO FindFile

.ACCU 8
.INDEX 16

	jsr ClearFindEntry

	ldx #$0001				; number of file types to look for (1)
	stx extNum

	ldx #$0000

__LoadFileNameLoop\@:
	lda.w FileName\@, x			; load filename and store it in findEntry
	cmp #'.'
	beq __FileNameComplete\@
	sta findEntry, x
	inx
	cpx #$0008
	bne __LoadFileNameLoop\@

__FileNameComplete\@:
	inx					; skip '.'
	lda.w FileName\@, x			; load extension and store it in extMatchX
	sta extMatch1

	inx
	lda.w FileName\@, x
	sta extMatch2

	inx
	lda.w FileName\@, x
	sta extMatch3

	rep #A_8BIT				; A = 16 bit

	lda baseDirCluster			; "POWERPAK" dir start
	sta sourceCluster

	lda baseDirCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	stz CLDConfigFlags			; use WRAM buffer, don't skip hidden files

	jsr CardLoadDir				; "POWERPAK" dir
	jsr DirFindEntry			; get first cluster of file to look for

	rep #A_8BIT

	lda tempEntry.tempCluster
	sta sourceCluster

	lda tempEntry.tempCluster+2
	sta sourceCluster+2

	sep #A_8BIT

	bra __FileName_End\@

FileName\@:
	.DB \1

__FileName_End\@:

.ENDM



; Macro IncrementSectorNum by ManuLöwe (added for v2.02)
;
; Usage: IncrementSectorNum
; Effect: Increments source sector. Used by 4 routines in main code.

.MACRO IncrementSectorNum

.ACCU 8
.INDEX 16

	pei (destLo)				; push destLo/destHi onto stack

	jsr LoadNextSectorNum

	rep #A_8BIT				; A = 16 bit

	pla					; pull destLo/destHi from stack
	sta destLo

; check for last sector
; FAT32 last cluster = 0x0FFFFFFF
; FAT16 last cluster = 0x0000FFFF

	lda fat32Enabled			; check for FAT32
	and #$0001
	bne __LastClusterMaskFAT32\@

	stz temp+2				; if FAT16, high word = $0000
	bra __LastClusterMaskDone\@

__LastClusterMaskFAT32\@:
	lda #$0FFF				; if FAT32, high word = $0FFF
	sta temp+2

__LastClusterMaskDone\@:			; if cluster = last cluster, jump to last entry found
	lda sourceCluster
	cmp #$FFFF				; low word = $FFFF (FAT16/32)
	bne __NextSector\@

	lda sourceCluster+2
	cmp temp+2
	bne __NextSector\@

	sep #A_8BIT				; A = 8 bit

	bra _f					; last cluster (intentional forward jump, "beyond" of the macro)

__NextSector\@:
	sep #A_8BIT				; A = 8 bit

.ENDM



; Macro WaitTwoFrames by ManuLöwe (added for v3.00)
;
; Usage: WaitTwoFrames
; Effect: Waits for two Vblanks to pass (used in flashing routines only, where NMI/IRQ is disabled).

.MACRO WaitTwoFrames

__WaitForVblankStart1\@:
	lda REG_HVBJOY
	bpl __WaitForVblankStart1\@

__WaitForVblankEnd1\@:
	lda REG_HVBJOY
	bmi __WaitForVblankEnd1\@

__WaitForVblankStart2\@:
	lda REG_HVBJOY
	bpl __WaitForVblankStart2\@

__WaitForVblankEnd2\@:
	lda REG_HVBJOY
	bmi __WaitForVblankEnd2\@
.ENDM



; Macro CheckToggleBit by ManuLöwe (added for v3.00)
;
; Usage: CheckToggleBit
; Effect: Waits until DQ6 bit toggling stops after writing a flash ROM sector.

.MACRO CheckToggleBit

__DQ6Toggling\@:
	bit $008000				; wait for DQ6 bit toggling to stop
	bvs __DQ6NextTest\@

	bit $008000
	bvc __DeviceReady\@

__DQ6NextTest\@:
	bit $008000
	bvc __DQ6Toggling\@

__DeviceReady\@:

.ENDM



; SNESMod macro: increment memory pointer by 2

.MACRO incptr
	iny
	iny
	bmi __no_overflow\@

	inc spc_ptr+2
	ldy #$8000

__no_overflow\@:

.ENDM



; SNESMod macro: SPC700 sync (port 0)

.MACRO WaitForAPUIO0

__waitForAPUIO0\@:
	cmp REG_APUIO0
	bne __waitForAPUIO0\@
.ENDM



; SNESMod macro: SPC700 sync (port 1)

.MACRO WaitForAPUIO1

__waitForAPUIO1\@:
	cmp REG_APUIO1
	bne __waitForAPUIO1\@
.ENDM



; ******************************** EOF *********************************
