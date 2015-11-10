;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** UPDATER (V1) VARIABLE DEFINITIONS ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;	- Neviksti (some macros), (c) 2002
;
;==========================================================================================



;00 - boot rom
;20 - 
;40 - fpga program
;60 - fpga cs
;80 - card write
;A0 - card read
;C0 - 
;E0 - 


;BOARD REVC
;  $00-$1F boot rom in 8000-FFFF  LOROM 1MB
;  $20-$3F config regs in 8000-FFFF   20=configs/status  30=DMA regs
;  $40-$5F FPGA /program in 8000-FFFF
;  $60-$7F FPGA /cs in 8000-FFFF 
;  $80-$9F CF write in 0000-FFFF
;  $A0-$BF CF READ in 0000-FFFF
;  $C0-$DF 
;  $E0-$FF 



;;CF CARD READ REGISTERS

.DEFINE CARDDATAREAD     $A08000
.DEFINE CARDDATAREADbank $A0
.DEFINE CARDDATAREADhigh $80
.DEFINE CARDDATAREADlow  $00

.DEFINE CARDSTATUS           $A0800E  ;7   ;0111
.DEFINE CARDALTSTATUS        $A08007  ;E   ;1110
.DEFINE CARDDRIVEADDRESS     $A0800F  ;F   ;1111
.DEFINE CARDERROR            $A08008  ;1   ;0001
.DEFINE CARDSECTORCOUNTREAD  $A08004  ;2   ;0010
.DEFINE CARDLBA0READ         $A0800C  ;3   ;0011
.DEFINE CARDLBA1READ         $A08002  ;4   ;0100
.DEFINE CARDLBA2READ         $A0800A  ;5   ;0101
.DEFINE CARDLBA3READ         $A08006  ;6   ;0110

;;CF CARD WRITE REGISTERS
.DEFINE CARDDATAWRITE    $808000  ;0  ;0000
.DEFINE CARDSECTORCOUNT  $808004  ;2  ;0010
.DEFINE CARDLBA0         $80800C  ;3  ;0011
.DEFINE CARDLBA1         $808002  ;4  ;0100
.DEFINE CARDLBA2         $80800A  ;5  ;0101
.DEFINE CARDLBA3         $808006  ;6  ;0110
.DEFINE CARDCOMMAND      $80800E  ;7  ;0111
.DEFINE CARDDEVICE       $808007  ;E  ;1110


;;FPGA CONFIG WRITE REGISTERS
.DEFINE FPGADATAWRITE    $608000
.DEFINE FPGAPROGRAMWRITE $408000




;;MEM MAPPER CONFIG REGS
.DEFINE CONFIGWRITEBANK      $208000
;00h 10h 20h 30h 40h 50h 60h 70h  80h 90h A0h B0h C0h D0h E0h F0h   bit5=rom bit6=sram
;010 030 050 070 090 0B0 0D0 0F0  110 130 150 170 190 1B0 1D0 1F0    xSRxxxxx
;                                                 390 3B0 3D0 3F0   ;;F0 active during boot

;                40l 50l 60l 70l                  C0l D0l E0l F0l 
;                080 0A0 0C0 0E0                  180 1A0 1C0 1E0
;                                                 380 3A0 3C0 3E0   ;;F0 active during boot


.DEFINE CONFIGWRITESRAMLO    $208001
.DEFINE CONFIGWRITESRAMHI    $208002
.DEFINE CONFIGWRITESRAMSIZE  $208003   ;;;0 = use bit, 1 = dont use bit

.DEFINE CONFIGWRITESTATUS    $208004

.DEFINE CONFIGREADSTATUS     $208005
.DEFINE CONFIGWRITEDSP       $208005   ;;0=none, 1=8MbLoROM, 2=16MbLoROM, 4=HIROM

;  7     6      5      4      3       2       1       0
; programmed signature A   clklock sdramidle batt
; rst                      rstclk  rstsdram  batt



.DEFINE DMAWRITELO       $308000
.DEFINE DMAWRITEHI       $308001
.DEFINE DMAWRITEBANK     $308002
.DEFINE DMAREADDATA      $21FF

.DEFINE REG_HVBJOY		$4212
.DEFINE REG_NMITIMEN		$4200



.ENUM $00
  jCardReadSector             dw
  jCardWriteSector            dw
  jForever                    dw
  jCardReset                  dw
  jCardWaitNotBusy            dw
  jCardWaitReady              dw
  jCardWaitDataReq            dw
  jCardCheckError             dw
  jCardLoadLBA                dw
  jCardReadBytesNoDMA         dw
  jCardReadBytesToWRAM        dw
  jCardReadBytesToFPGA        dw
  jCardReadBytesToSDRAM       dw
  jCardReadBytesToSDRAMNoDMA  dw
  jCardReadFile               dw
  jCardWriteFile              dw
  jCardWriteBytesFromWRAM     dw  
  jCardWriteBytesFromSDRAM    dw  
  jCardLoadModule             dw
  jCardLoadDirClearEntryName  dw
  jCardLoadDir                dw
  jClusterToLBA               dw
  jNextCluster                dw
  jDirPrintDir                dw
  jDirPrintEntry              dw
  jDirGetEntry                dw
  jDirFindEntry               dw
  jNextDir                    dw
  jPrintF                     dw
  jPrintInt8_noload           dw
  jPrintHex8_noload           dw
  jPrintClearLine             dw
  jPrintClearScreen           dw 
  jDoScrolling                dw
  jScrollUp                   dw
  jScrollDown                 dw
  jLoadNextSectorNum          dw
  jCardLoadFPGA               dw
  jClearFindEntry             dw
  jGameGeniePrint             dw
  jGameGenieClear             dw
  jGameGenieDecode            dw
  jGameGenieGetOffset         dw
  jGameGenieNextChar          dw
  jGameGeniePrevChar          dw
  jGameGenieCharStore         dw
  jGameGenieWriteCode         dw
  jLoadLogo                   dw
  jLoadRomVersion             dw
  jMemCheck                   dw
  jCopyROMInfo                dw
  jCopyBanks                  dw
  jPrintBanks                 dw
  jLogScreen                  dw
  jSWCHeaderCheck             dw
  jGD3HeaderCheck             dw
.ENDE




.ENUM $00
  kDestNoDMA   db
  kDestWRAM    db
  kDestFPGA    db
  kDestSDRAM   db
  kDestSDRAMNoDMA   db
.ENDE
.ENUM $00
  kSourceNoDMA   db
  kSourceWRAM    db
  kSourceFPGA    db
  kSourceSDRAM   db
  kSourceSDRAMNoDMA   db
.ENDE







.MACRO jump
  phx
	ldx #\1
	jsr (jumpTable, x)
  plx
.ENDM



; SetCursorPos  y, x 
.MACRO SetCursorPos
	ldx #32*\1 + \2
	stx Cursor
.ENDM

.MACRO ClearLine
  lda #\1
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



.ENUM $00
  strPtr             dw
  strPtr2            dw
  loaderState        db
  errorCode          dw
  fat32Enabled       db
  
  sourceBytes        db
  source256          db
  sourceBytes16      dw
  
  sourceLo           db
  sourceHi           db
  sourceBank         db
  sourceType         db
  
  sourceEntryLo      db
  sourceEntryHi      db
  sourceEntryBank    db
  
  destEntryLo        db
  destEntryHi        db
  destEntryBank      db
  
  destLo             db
  destHi             db
  destBank           db
  destType           db
  
  filesInDir         dw
  temp               dsb 8
  selectedEntry      dw
  lfnFound           db       
  
  sourceSector       dsb 4
  sourceCluster      dsb 4
  partitionLBABegin  dsb 4
  clusterBeginLBA    dsb 4    
  sectorsPerCluster  db
  reservedSectors    dw
  sectorsPerFat      dsb 4
  fatBeginLBA        dsb 4
  fat16RootSectors   db
  rootDirCluster     dsb 4
  baseDirCluster     dsb 4
  sectorCounter      dw
  
  Cursor             dw
  
  FrameNum           dw  ;;frame counter
  Joy1 		           DW		; Current button state of joypad1, bit0=0 if it is a valid joypad
  Joy2		           DW		;same thing for all pads...

  Joy1Press	         DW		; Holds joypad1 keys that are pressed and have been pressed since clearing this mem location
  Joy2Press	         DW		;same thing for all pads...
                          ;X Y TL  TR . . . .
                          ;A B sel st U D L R
                          
  Joy1New            dw
  Joy2New            dw
  
  Joy1Old            dw
  Joy2Old            dw  
  
  tempEntry          dsb 34
  findEntry          dsb 10
  
  exMatch1           dsb 4
  exMatch2           dsb 4
  exMatch3           dsb 4 
  
  scrollY            db
  scrollYCounter     db
  scrollYUp          db
  scrollYDown        db
  
  cursorX            db
  cursorY            db
  cursorYCounter     db
  cursorYUp          db
  cursorYDown        db
  
  speedCounter       db
  speedScroll        db
  
  insertTop          db
  insertBottom       db   
  
  saveName           dsb 30
  saveCluster        dsb 4
  saveSize           db
  useBattery         db

  gameName           dsb 30
  gameCluster        dsb 4
  gameSize           dw
  gameResetVector    dw
  gameROMMapper      db
  gameROMType        db
  gameROMSize        db
  gameBanks          dsb 32
  gameROMMbits       db
  sramSizeByte       db
  
  gameGenie          dsb 40
  gameGenieOffset    dsb 40
  gameGenieDecode    dsb 20   ;;decoded codes, 4 bytes per code
  
  ggcode             dsb 4
  
  nextModule         db

  bankCounter        db
  
  dontUseDMA         db
  
  bankOffset         dw
  

  headerType         db
  partitionIndex     dw
  
  ;;added for v1.04
  fixheader          db
  tempheader         db
  ex5Match1          dsb 7
  ex5Match2          dsb 7
  ex5Match3          dsb 7 
  audioPC            dsb 2
  audioA             db
  audioX             db
  audioY             db
  audioPSW           db
  audioSP            db
  spcSecs            dsb 3
  spcTimer           dsb 4
  fadeSecs           dsb 2
  
  lastCluster        dsb 4
  
  
  ;;;;;;;;;;ADDED v1.4
  searchEntry        dsb 34
  headerCounter      dsb 2
.ENDE

.ENUM $0200
  codeBuffer    dsb 5120 ;5KB code for modules
  sectorBuffer1 dsb 512  ;
  TextBuffer    dsb 1024 ;
  SpriteBuf1    dsb 512  ;
  SpriteBuf2    dsb 32  ;
  jumpTable     dsb 128  ;
.ENDE

.ENUM $7F0000
  dirBuffer     dsb 32768  ;;32KB of directory listings, 1000 items
.ENDE



; ******************************** EOF *********************************
