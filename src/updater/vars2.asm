;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** UPDATER (V2) VARIABLE DEFINITIONS ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;	- Neviksti (some macros), (c) 2002
;
;==========================================================================================



; *************************** Hardware info ****************************

;00 - boot rom
;20 -
;40 - fpga program
;60 - fpga cs
;80 - card write
;A0 - card read
;C0 -
;E0 -



; BOARD REV C
;  $00-$1F boot rom in 8000-FFFF  LOROM 1MB
;  $20-$3F config regs in 8000-FFFF   20=configs/status  30=DMA regs
;  $40-$5F FPGA /program in 8000-FFFF
;  $60-$7F FPGA /cs in 8000-FFFF
;  $80-$9F CF write in 0000-FFFF
;  $A0-$BF CF READ in 0000-FFFF
;  $C0-$DF
;  $E0-$FF



; KNOWN BOARD REVISIONS:
; revC ??????? (source: original PowerPak creator's comment just above)
; revD 8/ 9/09 (source: ManuLöwe's PowerPak :p)
; revE 2/23/10 (source: http://forums.nesdev.com/viewtopic.php?p=97596#p97596)
; revH 8/14/11 (source: http://forums.nesdev.com/viewtopic.php?p=106411#p106411)



;********************;   pdf p113
; CF                  A10  A3  A2  A1  A0  /REG
; SNES                gnd  A3  A2  A1  A0  vcc
;
; data read                0   0   0   0       xxx0
; error                    0   0   0   1       xxx1
; status                   0   1   1   1       xxx7
;
; data write               0   0   0   0       xxx0
; feature write            0   0   0   1       xxx1
; sector count             0   0   1   0       xxx2
; lba 0                    0   0   1   1       xxx3
; lba 1                    0   1   0   0       xxx4
; lba 2                    0   1   0   1       xxx5
; lba 3                    0   1   1   0       xxx6
; command                  0   1   1   1       xxx7
; device                   1   1   1   0       xxxE
;
;*********************;



; *************************** SNES registers ***************************

; status bits

	.DEFINE XY_8BIT			$10
	.DEFINE A_8BIT			$20

; SPC700 I/O registers

	.equ APUIO0			$2140
	.equ APUIO1			$2141
	.equ APUIO2			$2142
	.equ APUIO3			$2143



; ************************* PowerPak registers *************************

; CF CARD READ REGISTERS

	.DEFINE CARDDATAREAD		$A08000
	.DEFINE CARDDATAREADbank	$A0
	.DEFINE CARDDATAREADhigh	$80
	.DEFINE CARDDATAREADlow		$00
	.DEFINE CARDSTATUS		$A0800E	; 7   ;0111
	.DEFINE CARDALTSTATUS		$A08007	; E   ;1110
	.DEFINE CARDDRIVEADDRESS	$A0800F	; F   ;1111
	.DEFINE CARDERROR		$A08008	; 1   ;0001
	.DEFINE CARDSECTORCOUNTREAD	$A08004	; 2   ;0010
	.DEFINE CARDLBA0READ		$A0800C	; 3   ;0011
	.DEFINE CARDLBA1READ		$A08002	; 4   ;0100
	.DEFINE CARDLBA2READ		$A0800A	; 5   ;0101
	.DEFINE CARDLBA3READ		$A08006	; 6   ;0110

; CF CARD WRITE REGISTERS

	.DEFINE CARDDATAWRITE		$808000	; 0  ;0000
	.DEFINE CARDSECTORCOUNT		$808004	; 2  ;0010
	.DEFINE CARDLBA0		$80800C	; 3  ;0011
	.DEFINE CARDLBA1		$808002	; 4  ;0100
	.DEFINE CARDLBA2		$80800A	; 5  ;0101
	.DEFINE CARDLBA3		$808006	; 6  ;0110
	.DEFINE CARDCOMMAND		$80800E	; 7  ;0111
	.DEFINE CARDDEVICE		$808007	; E  ;1110


; FPGA CONFIG WRITE REGISTERS

	.DEFINE FPGADATAWRITE		$608000
	.DEFINE FPGAPROGRAMWRITE	$408000



; ************************* Config. registers **************************

; MEM MAPPER CONFIG REGS

	.DEFINE CONFIGWRITEBANK		$208000

;00h 10h 20h 30h 40h 50h 60h 70h  80h 90h A0h B0h C0h D0h E0h F0h   bit5=rom bit6=sram
;010 030 050 070 090 0B0 0D0 0F0  110 130 150 170 190 1B0 1D0 1F0    xSRxxxxx
;                                                 390 3B0 3D0 3F0   ;;F0 active during boot

;                40l 50l 60l 70l                  C0l D0l E0l F0l
;                080 0A0 0C0 0E0                  180 1A0 1C0 1E0
;                                                 380 3A0 3C0 3E0   ;;F0 active during boot

	.DEFINE CONFIGWRITESRAMLO	$208001
	.DEFINE CONFIGWRITESRAMHI	$208002
	.DEFINE CONFIGWRITESRAMSIZE	$208003	; 0 = use bit, 1 = dont use bit
	.DEFINE CONFIGWRITESTATUS	$208004
	.DEFINE CONFIGREADSTATUS	$208005
	.DEFINE CONFIGWRITEDSP		$208005	; 0=none, 1=8MbLoROM, 2=16MbLoROM, 4=HIROM

;  7     6      5      4      3       2       1       0
; programmed signature A   clklock sdramidle batt
; rst                      rstclk  rstsdram  batt

	.DEFINE DMAWRITELO		$308000
	.DEFINE DMAWRITEHI		$308001
	.DEFINE DMAWRITEBANK		$308002
	.DEFINE DMAREADDATA		$21FF

	.DEFINE REG_NMITIMEN		$4200
	.DEFINE REG_HVBJOY		$4212



; **************************** Jump table ******************************

.ENUM $00
	jCardReadSector			dw
	jCardWriteSector		dw
	jForever			dw
	jCardReset			dw
	jCardWaitNotBusy		dw
	jCardWaitReady			dw
	jCardWaitDataReq		dw
	jCardCheckError			dw
	jCardLoadLBA			dw
	jCardReadBytesNoDMA		dw
	jCardReadBytesToWRAM		dw
	jCardReadBytesToFPGA		dw
	jCardReadBytesToSDRAM		dw
	jCardReadBytesToSDRAMNoDMA	dw
	jCardReadFile			dw
	jCardWriteFile			dw
	jCardWriteBytesFromWRAM		dw
	jCardWriteBytesFromSDRAM	dw
	jCardLoadModule			dw
	jCardLoadDirClearEntryName	dw
	jCardLoadDir			dw
	jClusterToLBA			dw
	jNextCluster			dw
	jDirPrintDir			dw
	jDirPrintEntry			dw
	jDirGetEntry			dw
	jDirFindEntry			dw
	jNextDir			dw
	jPrintF				dw
	jPrintInt8_noload		dw
	jPrintHex8_noload		dw
	jPrintClearLine			dw
	jPrintClearScreen		dw
	jDoScrolling			dw
	jScrollUp			dw
	jScrollDown			dw
	jLoadNextSectorNum		dw
	jCardLoadFPGA			dw
	jClearFindEntry			dw
	jGameGeniePrint			dw
	jGameGenieClear			dw
	jGameGenieDecode		dw
	jGameGenieGetOffset		dw
	jGameGenieNextChar		dw
	jGameGeniePrevChar		dw
	jGameGenieCharStore		dw
	jGameGenieWriteCode		dw
	jLoadLogo			dw
	jLoadRomVersion			dw
	jMemCheck			dw
	jCopyROMInfo			dw
	jCopyBanks			dw
	jPrintBanks			dw
	jLogScreen			dw
	jSWCHeaderCheck			dw
	jGD3HeaderCheck			dw
	jWaitHBlank			dw	; 57 functions, max. = 64
.ENDE



; ************************** Misc. constants ***************************

; Constants (hardcoded up to v2.00-beta1) used by directory printing
; and scrolling routines. Caveat: changing these values won't be enough,
; HDMA windowing will need to be adjusted accordingly to suppress "gar-
; bage" lines in the filebrowser.

	.DEFINE maxFiles		$18	; max. number of files to show in the filebrowser (currently 24),
						; used by scrolling and directory printing/navigation routines

	.DEFINE minPrintX		$02	; number of tiles by which to indent horizontally from the left,
						; used by scrolling and print handler routines, macro "SetCursorPos"

	.DEFINE minPrintY		$02	; number of lines by which to indent vertically from the top,
						; also used by macros "ClearLine", "SetCursorPos"

	.DEFINE cursorYmin		$18	; equal to #minPrintY * $08 + $08 because for the cursor sprite,
						; $08 = line 0, $10 = line 1, $18 = line 2, etc.

	.DEFINE cursorYmax		$D0	; scanline 208, equal to #(maxFiles + minPrintY) * $08

	.DEFINE insertStandardTop	$01	; has to be #minPrintY - 1, or $1F if #minPrintY = 0
						; since screen/tilemap size = 32 = $20

	.DEFINE insertStandardBottom	$1A	; entry point for more stuff, probably equal to #maxFiles + minPrintY



.ENUM $00
	kDestNoDMA			db
	kDestWRAM			db
	kDestFPGA			db
	kDestSDRAM			db
	kDestSDRAMNoDMA			db
.ENDE



.ENUM $00
	kSourceNoDMA			db
	kSourceWRAM			db
	kSourceFPGA			db
	kSourceSDRAM			db
	kSourceSDRAMNoDMA		db
.ENDE



; ******************************* Macros *******************************

.MACRO jump
	phx
	ldx #\1
	jsr (jumpTable, x)
	plx
.ENDM



; SetCursorPos  y, x
.MACRO SetCursorPos
	ldx #32*\1+32*minPrintY + \2+minPrintX	; add values of indention constants
	stx Cursor
	stz BGPrintMon				; reset BG monitor value to zero (start on BG2)
.ENDM



.MACRO ClearLine
	clc
	lda #\1
	adc #minPrintY				; add Y indention
	jump jPrintClearLine
.ENDM



.MACRO PrintString
	LDx #STRlabel\@
	stx strPtr2
	jump jPrintF
	BRA END_STRlabel\@

STRlabel\@:
	.DB \1, 0
END_STRlabel\@:

.ENDM



;here's a macro for printing a number (a byte)
;
; ex:  PrintNum $2103 	;print value of reg $2103
;      PrintNum #9	;print 9
.MACRO PrintNum
	lda \1
	jump jPrintInt8_noload
.ENDM



.MACRO PrintHexNum
	lda \1
	jump jPrintHex8_noload
.ENDM



; Macro FindFile by ManuLöwe

; Puts first cluster of FILE.EXT into sourceCluster.

; Usage: FindFile "FILE.EXT"

; Restrictions:
; - can only find a single file at a time
; - only searches the POWERPAK directory (for CF modules and other firmware-related files)
; - the filename has to be in strict 8.3 format

.MACRO FindFile
	jump jClearFindEntry

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

	lda baseDirCluster			; "POWERPAK" dir start
	sta sourceCluster
	lda baseDirCluster+1
	sta sourceCluster+1
	lda baseDirCluster+2
	sta sourceCluster+2
	lda baseDirCluster+3
	sta sourceCluster+3

	jump jCardLoadDir			; "POWERPAK" dir

	jump jDirFindEntry			; get first cluster of file to look for

	lda tempEntry.tempCluster
	sta sourceCluster
	lda tempEntry.tempCluster+1
	sta sourceCluster+1
	lda tempEntry.tempCluster+2
	sta sourceCluster+2
	lda tempEntry.tempCluster+3
	sta sourceCluster+3

	bra END_FindFile\@

FileName\@:
	.DB \1

END_FindFile\@:

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



; ****************************** .STRUCTs ******************************

; Let's .STRUCT names and stuff that used to be hardcoded in v1.0X. :-)
; Caveat: There's still one last hardcoded dir flag in "DirPrintEntry"!

.STRUCT temp_entry
	tempName		dsb 122		; 128 bytes total
	tempCounter		db		; '$7A'
	tempDirFlag		db		; '$7B'
	tempCluster		dsb 4		; '$7C'-'$7F'
.ENDST



.STRUCT game_name
	gName			dsb 124		; 128 bytes total
	gCluster		dsb 4		; '$7C'-'$7F'
.ENDST



.STRUCT save_name
	sName			dsb 124		; 128 bytes total
	sCluster		dsb 4		; '$7C'-'$7F'
.ENDST



; *********************** Direct page variables ************************

.ENUM $00
	strPtr			dw
	strPtr2			dw
	loaderState		db
	errorCode		dw
	fat32Enabled		db

	sourceBytes		db
	source256		db
	sourceBytes16		dw

	sourceLo		db
	sourceHi		db
	sourceBank		db
	sourceType		db
						; 16 bytes and counting
	sourceEntryLo		db
	sourceEntryHi		db
	sourceEntryBank		db

	destEntryLo		db
	destEntryHi		db
	destEntryBank		db

	destLo			db
	destHi			db
	destBank		db
	destType		db

	filesInDir		dw
	temp			dsb 8
	selectedEntry		dw
	lfnFound		db
						; 39 bytes and counting
	sourceSector		dsb 4
	sourceCluster		dsb 4
	partitionLBABegin	dsb 4
	clusterBeginLBA    	dsb 4
	sectorsPerCluster	db
	reservedSectors		dw
	sectorsPerFat		dsb 4
	fatBeginLBA		dsb 4
	fat16RootSectors	db
	rootDirCluster		dsb 4
	baseDirCluster		dsb 4		; "baseDir" = "POWERPAK" directory
	sectorCounter		dw
						; 77 bytes and counting
	Cursor			dw

	FrameNum		dw		; frame counter
	Joy1			dw		; Current button state of joypad1, bit0=0 if it is a valid joypad
	Joy2			dw		; same thing for all pads...

	Joy1Press		dw		; Holds joypad1 keys that are pressed and have been
						; pressed since clearing this mem location
	Joy2Press		dw		; same thing for all pads...
						; X Y TL  TR . . . .
						; A B sel st U D L R
	Joy1New			dw
	Joy2New			dw

	Joy1Old			dw
	Joy2Old			dw
						; 97 bytes and counting
	findEntry		dsb 10

	extMatch1		dsb 11		; number of bytes = number of file types to search for at once
	extMatch2		dsb 11
	extMatch3		dsb 11
						; 140 bytes and counting
	scrollY			db
	scrollYCounter		db
	scrollYUp		db
	scrollYDown		db

	cursorX			db
	cursorY			db
	cursorYCounter		db
	cursorYUp		db
	cursorYDown		db

	speedCounter		db
	speedScroll		db

	insertTop		db
	insertBottom		db
						; 153 bytes and counting
	saveSize		db
	useBattery		db

	gameSize		dw
	gameResetVector		dw
	gameROMMapper		db
	gameROMType		db
	gameROMSize		db
	gameBanks		dsb 32
	gameROMMbits		db
	sramSizeByte		db
						; 196 bytes and counting
	ggcode			dsb 4

	nextModule		db

	bankCounter		db

	dontUseDMA		db

	bankOffset		dw

	headerType		db
	partitionIndex		dw
						; 208 bytes and counting
; added for v1.04
	fixheader		db
	tempheader		db
	audioPC			dsb 2		; \
	audioA			db		; |
	audioX			db		; | re-used for blargg's SPC player
	audioY			db		; |
	audioPSW		db		; |
	audioSP			db		; /
	spcTimer		dsb 4

	lastCluster		dsb 4

; added for v1.05 (?)
	headerCounter		dsb 2

; added for v2.00
	configDMA		db
	configLogo		db
	configBGdesign		db

	BGPrintMon		db		; keep track of BG we're printing on: $00 = BG2 (start), $01 = BG1
	extNum			dw		; number of file extensions to look for (16 bit)
	disableHDMA		db		; "emergency" HDMA off, $00 = false
.ENDE						; 234 of 512 bytes used



; ******************* Variables in lower 8K of WRAM ********************

.ENUM $0200
	codeBuffer	dsb 5120		; 5KB code for modules
	sectorBuffer1	dsb 512
	tempEntry	INSTANCEOF temp_entry	; \
	gameName	INSTANCEOF game_name	; | these refer back to the .STRUCTs
	saveName	INSTANCEOF save_name	; /
	SpriteBuf1	dsb 512
	SpriteBuf2	dsb 32
	gameGenie	dsb 40
	gameGenieOffset	dsb 40
	gameGenieDecode	dsb 40			; decoded codes, 4 bytes + 4 empty bytes (due to Y reg math) per code
	jumpTable	dsb 128
.ENDE						; 6808 bytes + $200 = $1C98 (7320) bytes used
						; reminder: stack resides at $1FFF



; ********************** Variables in upper WRAM ***********************

.ENUM $7E8000					; used by the SPC RAM buffer
	spcRAM1stBytes		dsb 2
	spcFLGReg		db
	spcKONReg		db
	spcDSPRegAddr		db
	spcCONTROLReg		db
	spcIOPorts		dsb 4
	spcIPLBuffer		dsb 238
	spcRegBuffer		dsb 128
	spcF8Buffer		dsb 264
.ENDE



.ENUM $7EEFFF					; seems safe
	LogBuffer	dsb 2048		; needed for writing error messages to LOG.TXT
	TxtBuf2bpp	dsb 1024		; used to be in the .ENUM $0200 section
	TxtBuf4bpp	dsb 1024		; added for v2.00 (hi-res text rendering)
.ENDE



.ENUM $7F0000
	dirBuffer	dsb 65536		; 64KB of directory listings, 512 items
.ENDE



; ******************************** EOF *********************************
