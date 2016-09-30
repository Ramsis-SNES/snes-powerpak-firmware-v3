;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2016 by ManuLöwe (http://manuloewe.de/)
;
;	*** VARIABLE DEFINITIONS ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



; ****************************** Notation ******************************

; Label prefixes:

; __		= sub-label
; ADDR_		= address value, as defined in this file
; CONST_	= arbitrary constant, stored in ROM
; DP_		= Direct Page variable
; k		= arbitrary constant, as defined in this file
; PTR_		= 2-byte pointer, stored in ROM
; REG_		= SNES hardware register
; STR_		= ASCII string, stored in ROM
; VAR_		= non-Direct Page variable



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

; -------------------------- processor status bits
	.DEFINE XY_8BIT			$10
	.DEFINE A_8BIT			$20
	.DEFINE AXY_8BIT		$30



; -------------------------- CPU/PPU registers
	.DEFINE REG_SLHV		$2137
	.DEFINE REG_OPVCT		$213D
	.DEFINE REG_NMITIMEN		$4200
	.DEFINE REG_RDNMI		$4210
	.DEFINE REG_HVBJOY		$4212
	.DEFINE REG_JOY0		$4218
	.DEFINE REG_JOY1		$421A
	.DEFINE REG_JOY2		$421C
	.DEFINE REG_JOY3		$421E
	.DEFINE REG_JOYSER0		$4016
	.DEFINE REG_JOYSER1		$4017
	.DEFINE REG_WRIO		$4201



; -------------------------- SPC700 I/O ports
	.DEFINE REG_APUIO0		$2140
	.DEFINE REG_APUIO1		$2141
	.DEFINE REG_APUIO2		$2142
	.DEFINE REG_APUIO3		$2143



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
	.DEFINE CARDDATAWRITEbank	$80
	.DEFINE CARDDATAWRITEhigh	$80
	.DEFINE CARDDATAWRITElow	$00
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
	.DEFINE DMAPORT			$FF



; ***************************** Constants ******************************

; -------------------------- Memory map
	.DEFINE ADDR_CGRAM_MAIN_GFX	$80
	.DEFINE ADDR_CGRAM_FONT_SPR	$B0

	.DEFINE ADDR_VRAM_BG1_TILEMAP	$0000	; reminder: each tilemap is 64×32 (2048) tiles = 4096 bytes in size
	.DEFINE ADDR_VRAM_BG2_TILEMAP	$0800
	.DEFINE ADDR_VRAM_BG1_TILES	$2000
	.DEFINE ADDR_VRAM_BG2_TILES	$4000
	.DEFINE ADDR_VRAM_SPR_TILES	$6000



; -------------------------- Navigation, filebrowser layout
; Constants needed for directory printing and scrolling routines.

	.DEFINE maxFiles		24				; max. no. of files to display in the filebrowser, acknowledged by scrolling and directory printing/navigation routines
	.DEFINE minPrintX		2				; no. of "columns" by which to indent from the left, acknowledged by scrolling and print handler routines, and SetCursorPos macro
	.DEFINE minPrintY		2				; no. of "lines" by which to indent from the top, acknowledged by ClearLine/SetCursorPos macros

	.DEFINE cursorXfilebrowser	$0D
	.DEFINE cursorYmin		minPrintY * 8 + 8		; for the cursor sprite, $08 = line 0, $10 = line 1, $18 = line 2, etc.
	.DEFINE cursorYmax		(maxFiles + minPrintY) * 8	; 24 "lines" (max. no. of files), so $D0/208 in this case
	.DEFINE insertStandardTop	(minPrintY - 1) & $1F		; tilemaps have 32 = $20 "lines", so $1F is the first possible "negative" value
	.DEFINE insertStandardBottom	maxFiles + minPrintY		; "line" no. in the tilemap where to put the next (positive) "off-screen" entry



; -------------------------- Option screen layout
	.DEFINE GGcodesX		4

	.DEFINE GGcode1Y		10
	.DEFINE GGcode2Y		12
	.DEFINE GGcode3Y		14
	.DEFINE GGcode4Y		16
	.DEFINE GGcode5Y		18

	.DEFINE mainSelX		2

	.DEFINE cursorXstart		$18
	.DEFINE cursorXcodes		$28

	.DEFINE cursorYPlayLoop		$20
	.DEFINE cursorYSRAMLoop		$38
	.DEFINE cursorYLoadGGLoop	$58

	.DEFINE cursorYGGcode1		$68
	.DEFINE cursorYGGcode2		$78
	.DEFINE cursorYGGcode3		$88
	.DEFINE cursorYGGcode4		$98
	.DEFINE cursorYGGcode5		$A8



; -------------------------- Settings menu layout
	.DEFINE cursorXsettings		$40

	.DEFINE cursorYsetmenu1		$60
	.DEFINE cursorYsetmenu2		$68
	.DEFINE cursorYsetmenu3		$70
	.DEFINE cursorYsetmenu4		$78
	.DEFINE cursorYsetmenu5		$80

	.DEFINE SetMenLineHeight	$08



; -------------------------- CF interface stuff
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



; -------------------------- Cold-boot check
; Added for v3.00 by ManuLöwe. Basically, any seven 8-bit-values will do.

.ENUM $25
	kWarmBoot1			dsb 6	; $25
	kWarmBoot2			dsb 6	; $2B
	kWarmBoot3			dsb 6	; $31
	kWarmBoot4			dsb 6	; $37
	kWarmBoot5			dsb 6	; $3D
	kWarmBoot6			dsb 6	; $43
	kWarmBoot7			dsb 6	; $49
.ENDE



; *********************** Direct page variables ************************

.ENUM $00
	DP_ColdBootCheck1	db

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
	sourceEntryLo		db
	sourceEntryHi		db
	sourceEntryBank		db		; 16 bytes and counting

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
	lfnFound		db		; 36 bytes and counting

	sourceSector		dsb 4
	sourceCluster		dsb 4
	partitionLBABegin	dsb 4
	clusterBeginLBA    	dsb 4
	sectorsPerCluster	db
	reservedSectors		dw
	sectorsPerFat		dsb 4
	fatBeginLBA		dsb 4

	DP_ColdBootCheck2	db

	fat16RootSectors	db
	rootDirCluster		dsb 4
	baseDirCluster		dsb 4		; "baseDir" = "POWERPAK" directory
	sectorCounter		db

	Cursor			dw		; 76 bytes and counting

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
	Joy2Old			dw		; 92 bytes and counting

	findEntry		dsb 9		; 8 bytes at most for short file names + NUL-terminator

	extMatch1		dsb 11		; 11 file types at most to look for during CardLoadDir
	extMatch2		dsb 11
	extMatch3		dsb 11
	extNum			dw		; holds number of file extensions to look for (16 bit for X/Y register use)

	scrollY			db
	scrollYCounter		db
	scrollYUp		db
	scrollYDown		db		; 140 bytes and counting

	cursorX			db		; cursorX/cursorY should be kept in consecutive order due to occasional 16-bit writes
	cursorY			db
	cursorYCounter		db
	cursorYUp		db
	cursorYDown		db

	speedCounter		db
	speedScroll		db

	insertTop		db
	insertBottom		db

	saveSize		db
	useBattery		db

	DP_ColdBootCheck3	db		; 152 bytes and counting

	gameSize		dw
	gameResetVector		dw
	gameROMMapper		db
	gameROMType		db
	gameROMSize		db
	gameBanks		dsb 32
	gameROMMbits		db
	sramSizeByte		db

	ggcode			dsb 4		; 197 bytes and counting

	CLDConfigFlags		db		; CardLoadDir config flags: rrrrrrhb [r = Reserved, h = skip hidden files if set,
						; b = use SDRAM buffer if set, WRAM buffer if clear]
						; The h flag is checked (& reset) in CardLoadDir only.
						; The b flag is checked & reset in CardLoadDir,
						; set & reset in DirPrintEntry, checked (not modified) in DirGetEntry.
						; Reminder: Supporting both buffers is mandatory because FPGA programming --
						; and thus, SDRAM unlocking -- can only occur after TOPLEVEL.BIT has been loaded.

	dontUseDMA		db

	bankCounter		db
	bankOffset		dw
	partitionIndex		dw

	headerType		db		; holds ROM header type ($01 = SWC, $02 = GD3, $FF = unknown)
	fixheader		db

	audioPC			dsb 2		; audio variables for blargg's SPC player
	audioA			db
	audioX			db
	audioY			db
	audioPSW		db
	audioSP			db
	spcTimer		dsb 4		; 217 bytes and counting

	BGPrintMon		db		; keep track of BG we're printing on: $00 = BG1 (start), $01 = BG2
	DP_SelectionFlags	db		; rrrrrrrf [r = Reserved, f = file was chosen if set]

	DP_HDMAchannels		db		; 21wbmr00 [2 = BG2 horizontal scroll offset, 1 = BG1 horizontal scroll offset, w = main/subscreen window, b = background color gradient, m = color math, r = Reserved, 0 = reserved for normal DMA]. Variable content is copied to $420C during Vblank.

	DP_SprTextMon		dw		; keeps track of sprite-based text buffer filling level
	DP_SprTextPalette	db		; holds palette to use when printing sprite-based text

	DP_cursorX_BAK		db		; backup variables for warm boot and/or file browser
	DP_cursorY_BAK		db
	DP_sourceCluster_BAK	dsb 4
	DP_StackPointer_BAK	dw		; 231 bytes and counting
	DP_SubDirCounter	dw		; used in the file browser

	DP_ThemeFileClusterLo	dw		; cluster of selected theme file
	DP_ThemeFileClusterHi	dw

	spc_ptr			dsb 3		; SNESMod variables (up to, and including, "digi_src2")
	spc_v			db
	spc_bank		db
	spc1			dsb 2
	spc2			dsb 2
	spc_fread		db
	spc_fwrite		db
	spc_pr			dsb 4		; port record [for interruption]
	SoundTable		dsb 3
.ENDE						; 255 of 256 bytes used



.ENUM $1B					; "temp" variable area
	digi_src		dsb 3
	digi_src2		dsb 3
.ENDE



; *********************** $0100-$01FF: Reserved ************************



; ****************************** .STRUCTs ******************************

.STRUCT text_buffer
	BG1			dsb 2048
	BG2			dsb 2048
.ENDST



.STRUCT oam_low
	Cursor			dsb 16		; only 4 lower bytes (one 16×16 sprite) used
	Buttons			dsb 48
	PowerPakLogo		dsb 64
	MainGFX			dsb 256
	Text			dsb 128		; for one line of text (32 chars)
.ENDST



.STRUCT oam_high
	Cursor			db		; only 2 lower bits (one 16×16 sprite) used
	Buttons			dsb 3
	PowerPakLogo		dsb 4
	MainGFX			dsb 16
	Text			dsb 8
.ENDST



.STRUCT hdma_tables
	BG			dsb 1121	; HDMA table for BG color gradient
	ColorMath		dsb 10		; HDMA table for SPC player color math
	ScrollBG1		dsb 21		; 2 HDMA tables (4-byte transfer per BG) for scroll offsets
	ScrollBG2		dsb 21
	Window			dsb 13		; HDMA table for windowing
.ENDST



.STRUCT temp_entry
	tempName		dsb 123
	tempFlags		db		; '$7B' / rrrrrrhd [r = Reserved, h = Hidden, d = Directory]
	tempCluster		dsb 4		; '$7C'-'$7F'
.ENDST



.STRUCT game_name
	gName			dsb 124
	gCluster		dsb 4		; '$7C'-'$7F'
.ENDST



.STRUCT save_name
	sName			dsb 124
	sCluster		dsb 4		; '$7C'-'$7F'
.ENDST



.STRUCT game_genie
	CharOffset		dw		; GG char offset, used when printing codes
	Codes			dsb 40		; five GameGenie codes, each 8 bytes long
	RealHex			dsb 8		; real hex equivalent of GG hex characters
	Decoded			dsb 40		; decoded GG codes
	Scratchpad		dsb 4		; GG decoding scratchpad
.ENDST



; ******************* Variables in lower 8K of WRAM ********************

.ENUM $200
	codeBuffer		dsb 1024	; 1 KiB for WRAM flashing routines
	sectorBuffer1		dsb 512

	VAR_ColdBootCheck4	db

	tempEntry	INSTANCEOF temp_entry	; 128 bytes
	gameName	INSTANCEOF game_name	; ditto
	saveName	INSTANCEOF save_name	; ditto
	SpriteBuf1	INSTANCEOF oam_low	; 512 bytes
	SpriteBuf2	INSTANCEOF oam_high	; 32 bytes
	GameGenie	INSTANCEOF game_genie	; 94 bytes
.ENDE
; -------------------------- total: 3071 ($BFF) bytes



.ENUM $C00					; more SNESMod variables
	spc_fifo		dsb 256		; 128-byte command fifo
	spc_sfx_next		db
	spc_q			db
	digi_init		db
	digi_pitch		db
	digi_vp			db
	digi_remain		dsb 2
	digi_active		db
	digi_copyrate		db		; SNESMod: 265 bytes
.ENDE



.ENUM $C00					; SPC RAM buffer variables (memory area shared with SNESMod vars)
	spcRAM1stBytes		dsb 2
	spcFLGReg		db
	spcKONReg		db
	spcDSPRegAddr		db
	spcCONTROLReg		db
	spcIOPorts		dsb 4
	spcIPLBuffer		dsb 238		; SPC RAM buffer part 1: "lower" 248 bytes
.ENDE



.ENUM $C00					; sic! (spcF8Buffer only uses the "upper" 264 of its assigned 512 bytes)
	spcF8Buffer		dsb 512
	spcRegBuffer		dsb 128		; SPC RAM buffer total: 640 bytes
.ENDE
; -------------------------- total: 3711 ($E7F) bytes (reminder: stack is <= $1FFF)



; ********************** Variables in upper WRAM ***********************

.ENUM $7E2000
	TextBuffer	INSTANCEOF text_buffer	; 4096 bytes
.ENDE



.ENUM $7E3000
	LogBuffer		dsb 2048	; for writing error messages to ERROR.LOG
	HDMAtable	INSTANCEOF hdma_tables	; 1186 bytes
	SpriteFWT		dsb 128		; font width table for sprite-based font

	VAR_ColdBootCheck5	db
.ENDE



.ENUM $7E4800					; random location #6
	VAR_ColdBootCheck6	db
.ENDE



.ENUM $7E76D2					; random location #7
	VAR_ColdBootCheck7	db
.ENDE



.ENUM $7F0000
	dirBuffer	dsb 65536		; 64 KiB (512×128 bytes) for directory buffering, also used as a buffer for high RAM of SPC files
.ENDE



; ******************************** EOF *********************************
