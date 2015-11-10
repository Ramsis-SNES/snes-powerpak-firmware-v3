;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** MAIN CODE SECTION: CF INTERFACE ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.INDEX 16

; ************************ Begin CF interaction ************************

AccessCFcard:
	rep #A_8BIT				; A = 16 bit

	stz gameName.gCluster			; clear out cluster info
	stz gameName.gCluster+2

	stz saveName.sCluster
	stz saveName.sCluster+2

	sep #A_8BIT				; A = 8 bit

	jsr CardReset

	wai

	jsr SpriteMessageError			; show preliminary error message (removed upon success)

StateCardNotInserted:				; wait until card inserted, show no card message
	lda CARDSTATUS
	sta errorCode
	and #%11110000				; open bus = A0
	cmp #$A0
	bne __StateCardInserted

;	wai
;	wai
;	wai

	SetCursorPos 21, 1
	PrintString "CF card not found.\n  Error code: $"
	PrintHexNum errorCode

	jsr PrintRomVersion
	jsr ShowConsoleVersion
	jsr ShowMainGFX				; show logo

	jmp Forever

__StateCardInserted:



StateCardBusy:					; wait until card not busy, show card busy message
	lda CARDSTATUS
	sta errorCode
	and #%10000000
	cmp #%10000000				; busy = $80
	bne StateCardBusyDone

	wai

	SetCursorPos 21, 1
	PrintString "CF card busy.     \n  Error code: $"
	PrintHexNum errorCode

	bra StateCardBusy

StateCardBusyDone:



StateCardReady:					; wait until card ready, show card not ready message
	lda CARDSTATUS
	sta errorCode
	and #%01010000
	cmp #%01010000				; ready = $50
	beq StateCardReadyDone

	wai

	SetCursorPos 21, 1
	PrintString "CF card not ready.\n  Error code: $"
	PrintHexNum errorCode

	bra StateCardReady

StateCardReadyDone:



; -------------------------- read card, check format
	SetCursorPos 21, 1
	PrintString "Reading CF card ..."

	lda #$01				; not using DMA
	sta dontUseDMA

	stz sourceSector
	stz sourceSector+1
	stz sourceSector+2
	stz sourceSector+3

	lda #<sectorBuffer1
	sta destLo
	lda #>sectorBuffer1
	sta destHi
	stz destBank

	lda #kDestWRAM				; try with DMA on
	sta destType

	jsr CardReadSector			; read sector 0 to internal RAM

	lda sectorBuffer1+$1FE			; last word check, should be $55AA
	cmp #$55
	bne CardFormatErrorJump

	lda sectorBuffer1+$1FF
	cmp #$AA
	bne CardFormatErrorJump

	ldy #$0000				; y = partition number  0-3
	ldx #$0000				; x = partition index   0, 16, 32, 48

CardFormatCheckLoop:
	lda #$01				; assume FAT32 for now
	sta fat32Enabled

	lda sectorBuffer1+$1C2, x		; read partiton type
	cmp #$0B				; 0Bh = FAT32
	beq CardGoodFormat

	cmp #$0C				; 0Ch = FAT32 with LBA1 13h Extensions
	beq CardGoodFormat

	stz fat32Enabled			; byte isn't 0Bh or 0Ch --> partition is not FAT32

	cmp #$06				; 06h = FAT16, larger than 32MB
	beq CardGoodFormat

	cmp #$04				; 04h = FAT16, smaller than 32MB
	beq CardGoodFormat

	cmp #$0E				; 0Eh = FAT16 with LBA1 13h Extensions
	beq CardGoodFormat

	rep #A_8BIT				; A = 16 bit

	txa					; increment index to next partition entry
	clc
	adc #16
	tax

	sep #A_8BIT				; A = 8 bit

	iny
	cpy #4					; all 4 partition entries checked?
	bne CardFormatCheckLoop

CardFormatErrorJump:				; no valid/supported partition type found
	jmp CardFormatError



CardGoodFormat:					; FAT16/FAT32 partition found
	stx partitionIndex

	ClearLine 21				; hide "Reading CF card ..."
	ClearLine 22				; hide possible error code (from CF busy/not ready message)

	jsr ClearSpriteText			; remove preliminary error message
	jsr PrintCardFS				; show CF card filesystem type

	ldx partitionIndex
	ldy #$0000

CardCopyPartitionLBABegin:			; copy partitionLBABegin from offset 455
	lda sectorBuffer1+$1C6, x
	sta sourceSector, y
	sta partitionLBABegin, y
	inx
	iny
	cpy #$0004
	bne CardCopyPartitionLBABegin

	lda #<sectorBuffer1
	sta destLo
	lda #>sectorBuffer1
	sta destHi
	stz destBank

	lda #kDestWRAM
	sta destType

	jsr CardReadSector			; read FAT16/FAT32 Volume ID sector (partition boot record)

	lda sectorBuffer1+$0D			; copy FAT16/FAT32 sectorsPerCluster from offset 13
	sta sectorsPerCluster

	lda sectorBuffer1+$0E			; copy FAT16/FAT32 reservedSectors from offset 14
	sta reservedSectors

	lda sectorBuffer1+$0F
	sta reservedSectors+1

	ldx #$0000

CardCopySectorsPerFat:				; copy FAT32 sectorsPerFat from offset 36
	lda sectorBuffer1+$24, x
	sta sectorsPerFat, x
	inx
	cpx #$0004
	bne CardCopySectorsPerFat

	ldx #$0000

CardCopyRootDirCluster32:			; copy FAT32 rootDirCluster from offset 44
	lda sectorBuffer1+$2C, x
	sta rootDirCluster, x
	inx
	cpx #$0004
	bne CardCopyRootDirCluster32

	stz fat16RootSectors			; FAT32 no entry limit in root directory

	lda fat32Enabled
	cmp #$01
	beq CardCopyFatBeginLBA			; when FAT32, leave alone



;;;SPECIAL FAT16 handling

CardCopyRootDirCluster16:
	stz rootDirCluster
	stz rootDirCluster+1			; when FAT16, rootDirCluster = 0000 (root dir is not in cluster nums)
	stz rootDirCluster+2
	stz rootDirCluster+3

	lda sectorBuffer1+$16
	sta sectorsPerFat			; FAT16 copy sectorsPerFat from offset 22

	lda sectorBuffer1+$17
	sta sectorsPerFat+1

	stz sectorsPerFat+2
	stz sectorsPerFat+3			; FAT16 sectors per fat = 16 bits, in different place than FAT32


CardCopyRootDirEntries16:			; copy max root directory entries from offset 17
	lda sectorBuffer1+$11
	sta fat16RootSectors

	lda sectorBuffer1+$12
	sta fat16RootSectors+1

;  clc
;  lsr fat16RootSectors
;  lsr fat16RootSectors           ; FAT16 rootSectors =  (max root entries * 32) / 512   =   fat16RootSectors/16  ASR x4
;  lsr fat16RootSectors
;  lsr fat16RootSectors

	lda #$20
	sta fat16RootSectors			; FAT16 root dir fixed at 512 entries = 32 sectors



CardCopyFatBeginLBA:
	rep #A_8BIT				; A = 16 bit

	clc					; fatBeginLBA(4) = partitionLBABegin(4) + reservedSectors(2)
	lda reservedSectors
	adc partitionLBABegin
	sta fatBeginLBA

	lda partitionLBABegin+2
	adc #$0000
	sta fatBeginLBA+2

;CardCopyClusterBeginLBA:
	lda sectorsPerFat
	sta clusterBeginLBA

	lda sectorsPerFat+2
	sta clusterBeginLBA+2

	clc
	asl clusterBeginLBA			; clusterBeginLBA(4) = fatBeginLBA(4) + (2 * sectorPerFat(4))
	rol clusterBeginLBA+2

	sep #A_8BIT				; A = 8 bit

	clc					; FAT16 = 32 sectors       FAT32 = 0 sectors
	lda clusterBeginLBA			; clusterBeginLBA(4) = clusterBeginLBA(4) + fat16RootSectors(1)
	adc fat16RootSectors
	sta clusterBeginLBA

	lda clusterBeginLBA+1
	adc #$00
	sta clusterBeginLBA+1

	rep #A_8BIT				; A = 16 bit

	lda clusterBeginLBA+2
	adc #$0000
	sta clusterBeginLBA+2

	clc
	lda clusterBeginLBA
	adc fatBeginLBA
	sta clusterBeginLBA

	lda clusterBeginLBA+2
	adc fatBeginLBA+2
	sta clusterBeginLBA+2

	lda rootDirCluster
	sta sourceCluster

	lda rootDirCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

 ; PrintString "\n"
 ; PrintHexNum sectorsPerCluster
 ; PrintString "\n"



.IFDEF DEBUG
	PrintString "fat16 != "
	PrintHexNum fat32Enabled
	PrintString "  RootSectors $"
	PrintHexNum fat16RootSectors
	PrintString "\n"

	PrintString "sectorsPerFat $"
	PrintHexNum sectorsPerFat+3
	PrintHexNum sectorsPerFat+2
	PrintHexNum sectorsPerFat+1
	PrintHexNum sectorsPerFat+0
	PrintString "\n"

	PrintString "partitionLBABegin $"
	PrintHexNum partitionLBABegin+3
	PrintHexNum partitionLBABegin+2
	PrintHexNum partitionLBABegin+1
	PrintHexNum partitionLBABegin+0
	PrintString "\n"

	PrintString "reservedSectors $"
	PrintHexNum reservedSectors+1
	PrintHexNum reservedSectors+0
	PrintString "\n"

	PrintString "fatBeginLBA $"
	PrintHexNum fatBeginLBA+3
	PrintHexNum fatBeginLBA+2
	PrintHexNum fatBeginLBA+1
	PrintHexNum fatBeginLBA+0
	PrintString "\n"

	PrintString "rootDirCluster $"
	PrintHexNum rootDirCluster+3
	PrintHexNum rootDirCluster+2
	PrintHexNum rootDirCluster+1
	PrintHexNum rootDirCluster+0
	PrintString "\n"
.ENDIF



rts



; ************************* CF error handling **************************

CardFormatError:
	jsr PrintRomVersion

	ClearLine 21
	ClearLine 22

	SetCursorPos 21, 1
	PrintString "Card format error: FAT16/FAT32 expected!"

	lda sectorBuffer1+$1C2			; card last word read
	sta errorCode

	ldy #errorCode
	PrintString "\n  $1C2(fm)=$%x"

	lda sectorBuffer1+$1FE			; card last word read
	sta errorCode

	ldy #errorCode
	PrintString " | $1FE($55)=$%x"

	lda sectorBuffer1+$1FF			; card last word read
	sta errorCode

	ldy #errorCode
	PrintString " | $1FF($AA)=$%x"

	jmp Forever



CardReset:
	lda #%00000000
	sta CARDLBA3				; select card 0

	lda #%00000110				; do card sw reset
	sta CARDDEVICE				; in device ctl reg

	wai
	wai

	lda #%00000010
	sta CARDDEVICE				; clear reset

	wai
	wai
rts



CardWaitNotBusy:

CardWaitNotBusyLoop:				; wait for not busy
	lda CARDSTATUS				; card status read
	sta errorCode
	and #%10000000
	cmp #%10000000				; check busy bit
	bne CardWaitNotBusyDone
;  SetCursorPos 12, 0
;  PrintString "    Error $"
;  PrintHexNum errorCode
;  PrintString " - CF card busy    "
	bra CardWaitNotBusyLoop

CardWaitNotBusyDone:

rts



CardWaitReady:

CardWaitReadyLoop:				; wait until card ready
	lda CARDSTATUS
	sta errorCode
	and #%01010000
	cmp #%01010000
	beq CardWaitReadyDone
;  SetCursorPos 12, 0
;  PrintString "    Error $"
;  PrintHexNum errorCode
;  PrintString " - CF not ready    "
	bra CardWaitReadyLoop

CardWaitReadyDone:

rts



CardWaitDataReq:				; wait for not busy, ready, datareq, no error

CardWaitDataReqLoop:
	lda CARDSTATUS
	sta errorCode
	and #%01011000
	cmp #%01011000
	beq CardWaitDataReqDone
;  SetCursorPos 12, 0
;  PrintString "    Error $"
;  PrintHexNum errorCode
;  PrintString " - CF no data req    "
	bra CardWaitDataReqLoop

CardWaitDataReqDone:

rts



CardCheckError:
	lda CARDSTATUS				; get card status, check for general error
	sta errorCode
	and #%00000001
	cmp #%00000001
	beq CardError
rts

CardError:
	ClearLine 21
	ClearLine 22
	ClearLine 23

	SetCursorPos 21, 1

	ldy #errorCode
	PrintString "Error $%x - CF card status"

	lda CARDERROR
	sta errorCode

	ldy #errorCode
	PrintString "\n  Error $%x - CF card error"

	lda CARDSECTORCOUNTREAD
	sta errorCode

	ldy #errorCode
	PrintString "\n  CSCR=$%x"

	lda CARDLBA0READ
	sta errorCode

	ldy #errorCode
	PrintString " | LBA0=$%x"

	lda CARDLBA1READ
	sta errorCode

	ldy #errorCode
	PrintString " | LBA1=$%x"

	lda CARDLBA2READ
	sta errorCode

	ldy #errorCode
	PrintString " | LBA2=$%x"

	lda CARDLBA3READ
	sta errorCode

	ldy #errorCode
	PrintString " | LBA3=$%x"

	jmp Forever



CardLoadLBA:
	jsr CardWaitNotBusy
	jsr CardWaitReady
	jsr CardCheckError

	lda #$01
	sta CARDSECTORCOUNT

	jsr CardWaitNotBusy			; LAST check busy/ready/error after each command
	jsr CardWaitReady
;	jsr CardCheckError

	lda sourceSector
	sta CARDLBA0

	jsr CardWaitNotBusy
	jsr CardWaitReady
;	jsr CardCheckError

	lda sourceSector+1
	sta CARDLBA1

	jsr CardWaitNotBusy
	jsr CardWaitReady
;	jsr CardCheckError

	lda sourceSector+2
	sta CARDLBA2

	jsr CardWaitNotBusy
	jsr CardWaitReady
;	jsr CardCheckError

	lda sourceSector+3			; load LBA number
	and #%00001111
	ora #%11100000
	sta sourceSector+3
	sta CARDLBA3

	jsr CardWaitNotBusy
	jsr CardWaitReady
	jsr CardCheckError
rts



; ************************* Read from CF card **************************

CardReadSector:
	sei					; disable NMI & IRQ
	stz REG_NMITIMEN

	jsr CardLoadLBA

	ldx #$0200				; read 512 bytes at a time
	stx sourceBytes16

;	jsr CardWaitNotBusy
;	jsr CardWaitReady
;	jsr CardCheckError

	lda #$20
	sta CARDCOMMAND				; send card read sector command

	jsr CardWaitNotBusy
	jsr CardWaitReady
	jsr CardCheckError
	jsr CardWaitDataReq

	lda destType				; check for data destination
	cmp #kDestWRAM
	beq __CRS_toWRAM

	cmp #kDestFPGA
	beq __CRS_toFPGA

	cmp #kDestSDRAM
	beq __CRS_toSDRAM

	cmp #kDestSDRAMNoDMA
	beq __CRS_toSDRAMnoDMA

	jmp __CRS_toWRAMnoDMA			; if no destination defined, read data to WRAM not using DMA



__CRS_toWRAM:
	lda dontUseDMA
	bne __CRS_toWRAMnoDMA			; if dontUseDMA != 0, then don't use DMA

	ldx destLo
	stx $2181				; set WRAM destination address

	lda destBank
	sta $2183

	DMA_WaitHblank $08, CARDDATAREADbank, CARDDATAREADhigh, CARDDATAREADlow, $80, sourceBytes16

	bra __CRS_Done



__CRS_toFPGA:
	ldx sourceBytes16

-	lda CARDDATAREAD			; read data byte
	sta FPGADATAWRITE			; write to FPGA
	dex
	bne -

	bra __CRS_Done



__CRS_toSDRAM:
	DMA_WaitHblank $08, CARDDATAREADbank, CARDDATAREADhigh, CARDDATAREADlow, DMAPORT, sourceBytes16

	bra __CRS_Done



__CRS_toSDRAMnoDMA:
	ldx sourceBytes16

-	lda CARDDATAREAD			; read data byte
	sta DMAREADDATA				; write to SDRAM
	dex
	bne -

	bra __CRS_Done



__CRS_toWRAMnoDMA:				; read source256*sourceBytes bytes into WRAM
	ldx sourceBytes16
	ldy #$0000

-	lda CARDDATAREAD
	sta [destLo], y
	iny
	dex
	bne -

;	PrintHexNum bankCounter
;	PrintString "CardReadBytesDone\n"

__CRS_Done:

	jsr CardWaitNotBusy
	jsr CardWaitReady
	jsr CardCheckError

; lda CARDSECTORCOUNTREAD
; sta errorCode
; bne CardReadSectorFailed			; LAST make sure sectors = 0

;CardReadSectorPassed:
; jsr CardWaitNotBusy			; LAST check for busy before error
; jsr CardWaitReady
; jsr CardCheckError

	lda REG_RDNMI				; clear NMI flag, this is necessary to prevent occasional graphics glitches (see Fullsnes, 4210h/RDNMI)

	lda #$81
	sta REG_NMITIMEN			; re-enable VBlank NMI

	cli
rts



;CardReadSectorFailed:
;	ClearLine 19
;	ClearLine 20

;	SetCursorPos 19, 1
;	PrintString "Error CF sectors left = "
;	PrintHexNum errorCode

;	SetCursorPos 20, 1

;	lda CARDERROR
;	sta errorCode
;	PrintString "Error $"
;	PrintHexNum errorCode
;	PrintString " - CF card error"

;CardReadSectorFailedForever:

;	jmp Forever



CardReadGameFill:
	rep #A_8BIT				; A = 16 bit

	stz gameSize

__CRGF_Reiterate:
	lda gameName.gCluster			; set source cluster
	sta sourceCluster

	lda gameName.gCluster+2
	sta sourceCluster+2

	sep #A_8BIT				; A = 8 bit

	stz sectorCounter
	stz bankCounter

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

	lda headerType				; check if header is present
	and #$FF
	bne __CRGF_NextSector			; sector=0 and header present --> skip that sector

__CRGF_ReadSector:
	lda #kDestSDRAM
	sta destType

	jsr CardReadSector

	rep #A_8BIT				; A = 16 bit

	inc gameSize				; keep track of game size, skipping header sectors

	sep #A_8BIT				; A = 8 bit

__CRGF_NextSector:
	IncrementSectorNum

	inc destHi
	inc destHi
	inc bankCounter

	bra __CRGF_ReadSector

__	lda gameSize+1
	cmp #$04				; read file again until $400 sectors = 512KB have been copied
	bcc +					; (probably in order to "improve" support for smaller ROMs ??)
rts

+	rep #A_8BIT				; A = 16 bit

	jmp __CRGF_Reiterate



.ACCU 8

CardReadFile:					; sourceCluster already set
	stz gameSize
	stz gameSize+1

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

__CardReadFileLoop:
;  PrintHexNum sourceSector+3
;  PrintHexNum sourceSector+2
;  PrintHexNum sourceSector+1
;  PrintHexNum sourceSector+0
;  PrintString "."

	rep #A_8BIT				; A = 16 bit

	inc gameSize				; keep track of game size

	sep #A_8BIT				; A = 8 bit

	lda #kDestSDRAM
	sta destType

	jsr CardReadSector

	IncrementSectorNum

	inc destHi				; dest = dest + 512
	inc destHi
	inc bankCounter

	bra __CardReadFileLoop
__ rts



CardWriteFile:					; sourceCluster already set
	stz sectorCounter
	stz bankCounter

	lda #kDestWRAM
	sta destType

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

__CardWriteFileLoop:
	jsr CardWriteSector

	IncrementSectorNum

	inc sourceHi				; source = source + 512
	inc sourceHi
	inc bankCounter

	bra __CardWriteFileLoop
__ rts



CardWriteSector:
	sei					; disable NMI & IRQ
	stz REG_NMITIMEN

	jsr CardWaitNotBusy
	jsr CardWaitReady
	jsr CardCheckError
	jsr CardLoadLBA

	ldx #$0200				; write 512 bytes at a time
	stx sourceBytes16

	jsr CardWaitNotBusy
	jsr CardWaitReady
	jsr CardCheckError

	lda #$30
	sta CARDCOMMAND				; send card write sector command

	nop
	nop

	jsr CardCheckError
	jsr CardWaitDataReq

	lda sourceType				; check for data source
	cmp #kSourceSDRAM
	beq __CWS_fromSDRAM

	cmp #kSourceWRAM
	beq __CWS_fromWRAM

	bra __CWS_Done				; if no source defined, jump out (FIXME ??)



__CWS_fromSDRAM:				; write source256*sourceBytes bytes onto CF card
	ldx sourceBytes16

-	lda DMAREADDATA
	sta CARDDATAWRITE
	dex
	bne -

;	DMA_WaitHblank $88, CARDDATAWRITEbank, CARDDATAWRITEhigh, CARDDATAWRITElow, DMAPORT, sourceBytes16

; N.B. The above B --> A bus DMA (replacing the loop) is tested working,
; but despite the wait-for-Hblank causes visible flickering on the screen
; whilst offering zero speed increase (possibly due to the CARDDATAWRITE
; bottleneck on the hardware side). Tested with Dezaemon (J).srm, which
; is 1 Mbit in size.

	bra __CWS_Done



__CWS_fromWRAM:					; write source256*sourceBytes bytes onto CF card
	ldx sourceBytes16
	ldy #$0000

-	lda [sourceLo], y
	sta CARDDATAWRITE
	iny
	dex
	bne -

__CWS_Done:

	jsr CardCheckError

	lda REG_RDNMI				; clear NMI flag // ADDED for v3.00

	lda #$81
	sta REG_NMITIMEN			; re-enable VBlank NMI

	cli
rts



; cluster->lba     lba_addr(4) = clusterBeginLBA(4) + (cluster_number(2)-2 * sectorsPerCluster(1))
ClusterToLBA:
	rep #A_8BIT				; A = 16 bit

	sec
	lda sourceCluster
	sbc #$0002
	sta sourceSector

	lda sourceCluster+2
	sbc #$0000
	sta sourceSector+2			; sourceSector = sourceCluster - 2

	sep #A_8BIT				; A = 8 bit

	lda sectorsPerCluster
	sta source256

	lsr source256
	beq +					; handle 1 sector per cluster

__ClusterToLBALoop:
	rep #A_8BIT				; A = 16 bit

	asl sourceSector
	rol sourceSector+2			; sourceSector = sourceSector * sectorsPerCluster

	sep #A_8BIT				; A = 8 bit

	lsr source256
	bne __ClusterToLBALoop

+	rep #A_8BIT				; A = 16 bit

	clc
	lda sourceSector
	adc clusterBeginLBA
	sta sourceSector

	lda sourceSector+2
	adc clusterBeginLBA+2
	sta sourceSector+2			; sourceSector = sourceSector(4) + clusterBeginLBA(4)

	sep #A_8BIT				; A = 8 bit
rts



; ********************* Load dir from CF to buffer *********************

; Loads the contents of a directory and stores relevant files in the
; selected buffer (WRAM/SDRAM). CLDConfigFlags are reset upon RTS.

; destLo/Hi = WRAM destination address for sector being read.
; sourceEntryLo/Hi = address of FAT entry within current sector buffer.
; destEntryLo/Hi/Bank = WRAM address where to put file entry (name +
; cluster).

CardLoadDir:
	lda #>sectorBuffer1
	sta destHi				; sourceSector1 = where to put sector, where to read entry
	sta sourceEntryHi

	lda #<sectorBuffer1
	sta destLo
	sta sourceEntryLo

	stz destBank				; bank $00 = lower 8K of WRAM
	stz sourceEntryBank			; ditto

	lda #$7F				; start at WRAM offset $7F0000
	sta destEntryBank
	stz destEntryHi
	stz destEntryLo

	lda #$00				; start at SDRAM offset $000000
	sta DMAWRITELO
	sta DMAWRITEHI
	sta DMAWRITEBANK

	rep #A_8BIT				; A = 16 bit

	stz filesInDir
	stz temp
	stz selectedEntry

	sep #A_8BIT				; A = 8 bit

	stz sectorCounter

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

	rep #A_8BIT				; A = 16 bit

	lda fat32Enabled
	and #$0001
	bne __CLD_ReadSector			; FAT32 detected, go to read sector

	lda sourceCluster			; FAT16 check if trying to load root dir
	cmp rootDirCluster
	bne __CLD_ReadSector

	lda sourceCluster+2
	cmp rootDirCluster+2
	bne __CLD_ReadSector

	sep #A_8BIT				; A = 8 bit

	sec
	lda clusterBeginLBA			; FAT16 sourceSector = root dir first sector => clusterLBABegin(4) - fat16RootSectors(1)
	sbc fat16RootSectors
	sta sourceSector

	lda clusterBeginLBA+1
	sbc #$00
	sta sourceSector+1

	rep #A_8BIT				; A = 16 bit

	lda clusterBeginLBA+2
	sbc #$0000
	sta sourceSector+2

__CLD_ReadSector:
	sep #A_8BIT				; A = 8 bit

	lda #kDestWRAM
	sta destType

	jsr CardReadSector			; put into dest
	jsr CLD_ClearEntryName			; clear tempEntry, reset lfnFound



CardLoadDirLoop:



; -------------------------- check for last entry
	ldy #$0000

	lda [sourceEntryLo], y			; if name[0] = 0x00, no more entries
	bne __CLD_EntryNotLast

	jmp __CLD_LastEntryFound

__CLD_EntryNotLast:



; -------------------------- check for unused entry
	ldy #$0000

	lda [sourceEntryLo], y
	cmp #$E5				; if name[0] = 0xE5, entry unused, skip
	bne __CLD_EntryNotUnused

	stz lfnFound

	jmp __CLD_NextEntry

__CLD_EntryNotUnused:



; -------------------------- check for LFN entry
	ldy #$000B

	lda [sourceEntryLo], y			; if flag = %00001111, long file name entry found
	and #$0F
	cmp #$0F
	bne __CLD_EntryNotLFN

	ldy #$0000				; check first byte of LFN entry = ordinal field

	lda [sourceEntryLo], y
	and #%10111111				; mask off "last entry" bit
	cmp #$0A				; if index = 1...9, load name
	bcc __CLD_EntryPrepareLoadLFN

	jsr CLD_ClearEntryName			; if index >= 10, skip entry (reminder: index = 0 doesn't seem to exist ??)

	jmp __CLD_NextEntry

__CLD_EntryPrepareLoadLFN:
	sta $211B				; PPU multiplication
	stz $211B

	lda #$0D				; LFNs consist of 13 unicode characters
	sta $211C

	rep #A_8BIT				; A = 16 bit

;	nop					; give 2 cycles of extra time (seems unneccessary)

	lda $2134				; read result
	sec
	sbc #$000D				; subtract 13 to start at tempEntry's beginning

	tax					; transfer to X register

	sep #A_8BIT				; A = 8 bit

	jsr CLD_LoadLFN				; load LFN entry, store characters to tempEntry

	jmp __CLD_NextEntry

__CLD_EntryNotLFN:



; -------------------------- check for volume ID entry
	ldy #$000B

	lda [sourceEntryLo], y			; if flag = volume id, skip
	and #$08
	cmp #$08
	bne __CLD_EntryNotVolumeID

	jsr CLD_ClearEntryName

	jmp __CLD_NextEntry

__CLD_EntryNotVolumeID:



; -------------------------- short file name found, perform additional checks

; -------------------------- check for hidden entry
	ldy #$000B

	lda [sourceEntryLo], y
	and #$02				; if flag = 0x02, hidden, mark as such
	beq __CLD_EntryHiddenCheckDone

	tsb tempEntry.tempFlags			; save "hidden" flag

__CLD_EntryHiddenCheckDone:



; -------------------------- check for directory entry
	ldy #$000B

	lda [sourceEntryLo], y			; if flag = directory, load entry
	and #$10
	cmp #$10
	bne __CLD_EntryNotDirectory

	lda #$01
	tsb tempEntry.tempFlags			; save "dir" flag

	bra __CLD_ProcessMatchingEntry

__CLD_EntryNotDirectory:



; -------------------------- check for entry extension
	ldx extNum				; check if entry matches any extension wanted,
	dex					; backwards from the Nth (= $NNNN-1) to the 1st (= $0000) extension

__CLD_CheckExtLoop:
	ldy #$0008

	lda [sourceEntryLo], y
	cmp extMatch1, x
	bne +

	iny

	lda [sourceEntryLo], y
	cmp extMatch2, x
	bne +

	iny

	lda [sourceEntryLo], y
	cmp extMatch3, x
	beq __CLD_EntryExtensionMatch		; extension matches

+	dex					; otherwise, try next extension indicated
	bpl __CLD_CheckExtLoop

	jsr CLD_ClearEntryName			; extension doesn't match, skip entry
	jmp __CLD_NextEntry

__CLD_EntryExtensionMatch:



; -------------------------- check file size
	rep #A_8BIT				; A = 16 bit

	ldy #$001E

	lda [sourceEntryLo], y			; upper 16 bit of file size
	bne __CLD_FileSizeNotZero

	ldy #$001C

	lda [sourceEntryLo], y			; lower 16 bit of file size
	bne __CLD_FileSizeNotZero

	sep #A_8BIT				; A = 8 bit

	jsr CLD_ClearEntryName			; file size = 0, skip entry
	jmp __CLD_NextEntry

__CLD_FileSizeNotZero:

	sep #A_8BIT				; A = 8 bit



; -------------------------- load long/short dir or entry with matching ext. and size not zero
__CLD_ProcessMatchingEntry:
	rep #A_8BIT				; A = 16 bit

	inc filesInDir				; increment file counter

	sep #A_8BIT				; A = 8 bit

	lda lfnFound
	cmp #$01
	beq __CLD_PrepareSaveEntry

	ldy #$0000				; if lfnFound = 0, copy short file name only

-	lda [sourceEntryLo], y
	sta tempEntry, y
	iny
	cpy #$0008
	bne -

	lda tempEntry.tempFlags
	and #%00000001				; check for "dir" flag
	bne __CLD_PrepareSaveEntry

	lda #'.'				; if not directory, copy short file name extension
	sta tempEntry+$8

	ldy #$0008

	lda [sourceEntryLo], y
	sta tempEntry+$9

	iny

	lda [sourceEntryLo], y
	sta tempEntry+$A

	iny

	lda [sourceEntryLo], y
	sta tempEntry+$B

__CLD_PrepareSaveEntry:
	ldy #$001A

	lda [sourceEntryLo], y			; copy clusterhilo to last 4 bytes of entry
	sta tempEntry.tempCluster

	iny

	lda [sourceEntryLo], y
	sta tempEntry.tempCluster+1

	ldy #$0014

	lda [sourceEntryLo], y
	sta tempEntry.tempCluster+2

	iny

	lda [sourceEntryLo], y
	sta tempEntry.tempCluster+3

	ldy #$0000

	lda CLDConfigFlags			; check for selected buffer
	and #%00000001
	bne __CLD_UseSDRAMbuffer

	jsr CLD_SaveEntryToWRAM

	rep #A_8BIT				; A = 16 bit

	lda filesInDir				; check if file counter has reached 512
	cmp #$0200
	bcc __CLD_WRAMcontinue

	sep #A_8BIT				; if so, A = 8 bit

	jmp __CLD_LastEntryFound		; ... and don't process any more entries

__CLD_WRAMcontinue:
	sep #A_8BIT				; otherwise, A = 8 bit, and continue

	jsr CLD_ClearEntryName
	bra __CLD_NextEntry

__CLD_UseSDRAMbuffer:
	lda CLDConfigFlags			; check if hidden files/folders are to be skipped
	and #%00000010
	beq __CLD_SaveEntryToSDRAM

	lda tempEntry.tempFlags
	and #%00000010				; yes, check for "hidden" flag
	beq __CLD_SaveEntryToSDRAM

	rep #A_8BIT				; A = 16 bit

	dec filesInDir				; hidden dir/file found, decrement file counter ...

	bra __CLD_SDRAMcontinue			; ... and jump out

.ACCU 8

__CLD_SaveEntryToSDRAM:
	lda tempEntry, y			; save entry to SDRAM
	sta DMAREADDATA
	iny
	cpy #$0080
	bne __CLD_SaveEntryToSDRAM

	rep #A_8BIT				; A = 16 bit

	lda filesInDir
	cmp #$FFFF				; check if file counter has reached 65535
	bcc __CLD_SDRAMcontinue

	sep #A_8BIT				; if so, A = 8 bit

	jmp __CLD_LastEntryFound		; ... and don't process any more entries

__CLD_SDRAMcontinue:
	sep #A_8BIT				; otherwise, A = 8 bit, and continue

	jsr CLD_ClearEntryName



; -------------------------- finally, increment to next entry, and loop
__CLD_NextEntry:
	rep #A_8BIT				; A = 16 bit

	clc					; increment entry source address
	lda sourceEntryLo			; sourceEntry += 32 in 0200-0400
	adc #$0020
	sta sourceEntryLo

	sep #A_8BIT				; A = 8 bit

	lda sourceEntryHi			; if source overflows, get next sector
	cmp #>sectorBuffer1+$02			; LAST CHANGE
	beq __CLD_NextSector

	jmp CardLoadDirLoop



; -------------------------- if necessary, increment source sector
__CLD_NextSector:
	rep #A_8BIT				; A = 16 bit

	clc
	lda sourceSector
	adc #$0001
	sta sourceSector			; go to next sector num

	lda sourceSector+2
	adc #$0000
	sta sourceSector+2

	lda fat32Enabled			; if FAT32, increment sector
	and #$0001
	bne __CLD_SectorIncrement

	lda sourceCluster			; FAT16 check if trying to load root dir
	cmp rootDirCluster
	bne __CLD_SectorIncrement

	lda sourceCluster+2
	cmp rootDirCluster+2
	bne __CLD_SectorIncrement

	sep #A_8BIT				; A = 8 bit

	inc sectorCounter			; FAT16 root dir all sequential sectors

	lda sectorCounter
	cmp fat16RootSectors			; if sectorCounter = fat16RootSectors, jump out
	beq __CLD_LastEntryFound

	bra __CLD_LoadNextSector		; FAT16 skip cluster lookup when max root sectors not reached

__CLD_SectorIncrement:
	sep #A_8BIT				; A = 8 bit

	inc sectorCounter			; one more sector

	lda sectorCounter
	cmp sectorsPerCluster			; make sure cluster isn't overflowing
	bne __CLD_LoadNextSector

	jsr NextCluster				; move to next cluster

	rep #A_8BIT				; A = 16 bit

; check for last sector
; FAT32 last cluster = 0x0FFFFFFF
; FAT16 last cluster = 0x0000FFFF

	lda fat32Enabled			; check for FAT32
	and #$0001
	bne __CLD_LastClusterMaskFAT32

	stz temp+2				; if FAT16, high word = $0000
	bra __CLD_LastClusterMaskDone

__CLD_LastClusterMaskFAT32:
	lda #$0FFF				; if FAT32, high word = $0FFF
	sta temp+2

__CLD_LastClusterMaskDone:			; if cluster = last cluster, jump to last entry found
	lda sourceCluster
	cmp #$FFFF				; low word = $FFFF (FAT16/32)
	bne __CLD_NextSectorNum

	lda sourceCluster+2
	cmp temp+2
	bne __CLD_NextSectorNum

	sep #A_8BIT				; A = 8 bit

	bra __CLD_LastEntryFound		; last cluster, jump out

__CLD_NextSectorNum:
	sep #A_8BIT				; A = 8 bit

	jsr ClusterToLBA			; sourceCluster -> first sourceSector

	stz sectorCounter			; reset sector counter

__CLD_LoadNextSector:
	lda #<sectorBuffer1
	sta destLo				; reset sector dest
	sta sourceEntryLo			; reset entry source

	lda #>sectorBuffer1
	sta destHi
	sta sourceEntryHi

	stz destBank
	stz sourceEntryBank

	lda #kDestWRAM
	sta destType

	jsr CardReadSector

	jmp CardLoadDirLoop

__CLD_LastEntryFound:

	stz CLDConfigFlags			; reset CardLoadDir config flags
rts



; -------------------------- CardLoadDir subroutine: load LFN entry
CLD_LoadLFN:
	ldy #$0001

__CLD_LoadLFNLoop1:
	lda [sourceEntryLo], y			; copy unicode chars 1-5 from offsets $01, $03, $05, $07, $09
	cmp #$FF
	beq +

	sta tempEntry, x

+	inx
	iny
	iny
	cpy #$000B
	bne __CLD_LoadLFNLoop1

	ldy #$000E

__CLD_LoadLFNLoop2:
	lda [sourceEntryLo], y			; copy unicode chars 6-11 from offsets $0E, $10, $12, $14, $16, $18
	cmp #$FF
	beq +

	sta tempEntry, x

+	inx
	iny
	iny
	cpy #$001A
	bne __CLD_LoadLFNLoop2

	ldy #$001C

__CLD_LoadLFNLoop3:
	lda [sourceEntryLo], y			; copy unicode chars 12-13 from offsets $1C, $1E
	cmp #$FF
	beq +

	sta tempEntry, x

+	inx
	iny
	iny
	cpy #$0020
	bne __CLD_LoadLFNLoop3

	lda #$01
	sta lfnFound
rts



; -------------------------- CardLoadDir subroutine: save entry to WRAM buffer
CLD_SaveEntryToWRAM:
	rep #A_8BIT				; A = 16 bit

-	lda tempEntry, y
	sta [destEntryLo], y
	iny
	iny
	cpy #$0080
	bne -

	clc
	lda destEntryLo				; destEntryHiLo += 128
	adc #$0080
	sta destEntryLo

	sep #A_8BIT				; A = 8 bit
rts



; -------------------------- CardLoadDir subroutine: reset tempEntry & LFN variables
CLD_ClearEntryName:
	stz lfnFound

	rep #A_8BIT				; A = 16 bit

	lda #$0000
	ldy #$0000

-	sta tempEntry, y
	iny
	iny
	cpy #$0080
	bne -

	sep #A_8BIT				; A = 8 bit
rts



; **************************** Next cluster ****************************

; Load FAT entry for sourceCluster, store next cluster number into
; sourceSector.

NextCluster:
	rep #A_8BIT				; A = 16 bit

	asl sourceCluster			; FAT16: offset = clusternum << 1
	rol sourceCluster+2			; mask = 00 00 ff ff

	lda fat32Enabled
	and #$0001
	beq NextClusterSectorNum

	asl sourceCluster			; FAT32: offset = clutsernum << 2 || cluster 2 << 2 = 8
	rol sourceCluster+2			; mask = 0f ff ff ff

NextClusterSectorNum:				; FAT sector num = fatBeginLBA + (offset / 512) || cluster = $2f8
	lda sourceCluster+1			; first, divide by 256 by shifting sourceCluster 8 bits right,
	sta sourceSector+0			; and store to sourceSector

	sep #A_8BIT				; A = 8 bit

	lda sourceCluster+3
	sta sourceSector+2

	stz sourceSector+3			; division by 256 done || sector = 02

	rep #A_8BIT				; A = 16 bit

	lsr sourceSector+2			; next, shift sourceSector 1 more bit right (div. by 512) || sector = 01
	ror sourceSector+0

	clc
	lda sourceSector			; add fatBeginLBA || sector = 60 = $c000
	adc fatBeginLBA
	sta sourceSector

	lda sourceSector+2
	adc fatBeginLBA+2
	sta sourceSector+2

	sep #A_8BIT				; A = 8 bit

	lda #>sectorBuffer1			; load FAT sector
	sta destHi
	lda #<sectorBuffer1
	sta destLo
	stz destBank

	lda #kDestWRAM
	sta destType

	jsr CardReadSector

; offset = offset % 512 -- offset of FAT entry within loaded sector 0-511
	lda sourceCluster+1
	and #%00000001
	sta sourceCluster+1			; cluster+1=0

	lda #<sectorBuffer1			; next cluster = [sector], offset
	sta sourceLo
	stz sourceBank

; sourceHi = sectorBuffer1(high) or sectorBuffer1(high)+1 for which 256 byte block to look in
	lda #>sectorBuffer1
	adc sourceCluster+1
	sta sourceHi

	lda sourceCluster
	sta temp+2
	stz temp+3

	ldy temp+2
	ldx #$0000

NextClusterLoop:
	lda [sourceLo], y
	sta sourceCluster, x
	iny
	inx
	cpx #$0004
	bne NextClusterLoop

	lda sourceCluster+3			; FAT32 mask off top 4 bits
	and #$0F
	sta sourceCluster+3

	lda fat32Enabled
	cmp #$01
	beq NextClusterDone			; no more mask for FAT32

	stz sourceCluster+3			; FAT16 mask
	stz sourceCluster+2

NextClusterDone:

rts



; ************************** Get next sector ***************************

LoadNextSectorNum:				; get next sector, use sectorCounter to check if next cluster needed
	rep #A_8BIT				; A = 16 bit

	clc
	lda sourceSector
	adc #$0001
	sta sourceSector			; go to next sector num

	lda sourceSector+2
	adc #$0000
	sta sourceSector+2

	sep #A_8BIT				; A = 8 bit

	inc sectorCounter			; one more sector

	lda sectorCounter
	cmp sectorsPerCluster
	beq __LoadNextClusterNum
rts

__LoadNextClusterNum:
	stz sectorCounter

	jsr NextCluster				; get cluster num into sourceCluster from FAT table



.IFDEF DEBUG
	PrintString "cluster="
	PrintString sourceCluster+3
	PrintString sourceCluster+2
	PrintString sourceCluster+1
	PrintString sourceCluster+0
	PrintString "\n"
.ENDIF



	jsr ClusterToLBA			; get sector num into sourceSector



.IFDEF DEBUG
	PrintString "sector="
	PrintHexNum sourceSector+3
	PrintHexNum sourceSector+2
	PrintHexNum sourceSector+1
	PrintHexNum sourceSector+0
	PrintString "\n"

	DelayFor 172
.ENDIF



rts



.ENDASM



; ************************* WIP file creation **************************

GotoSRMTest:
	jsr HideButtonSprites
	jsr HideLogoSprites
	jsr PrintClearScreen

	SetCursorPos 0, 0

	PrintString "sectorsPerFat $"
	PrintHexNum sectorsPerFat+3
	PrintHexNum sectorsPerFat+2
	PrintHexNum sectorsPerFat+1
	PrintHexNum sectorsPerFat+0

	PrintString "\n"

	PrintString "fatBeginLBA $"
	PrintHexNum fatBeginLBA+3
	PrintHexNum fatBeginLBA+2
	PrintHexNum fatBeginLBA+1
	PrintHexNum fatBeginLBA+0

	PrintString "\n\nSearching for free sector within FAT ...\nSector no. $"

	rep #A_8BIT				; A = 16 bit

	lda fatBeginLBA				; first FAT sector --> sourceSector for sector reading
	sta sourceSector

	lda fatBeginLBA+2
	sta sourceSector+2

	sep #A_8BIT				; A = 8 bit

FindFreeSector:
	lda #$E0				; mask off upper 3 bits (set in CardLoadLBA, reason unknown ??)
	trb sourceSector+3

	SetCursorPos 4, 6

	PrintHexNum sourceSector+3
	PrintHexNum sourceSector+2
	PrintHexNum sourceSector+1
	PrintHexNum sourceSector+0

	lda #kDestWRAM				; set WRAM as destination
	sta destType

	lda #<sectorBuffer1
	sta destLo
	lda #>sectorBuffer1
	sta destHi
	stz destBank

	jsr CardReadSector			; read FAT sector to WRAM

	rep #A_8BIT				; A = 16 bit

	ldx #$0000

-	lda sectorBuffer1, x
	bne __SectorNotEmpty
	inx
	inx
	cpx #512
	bne -

	sep #A_8BIT				; A = 8 bit

	PrintString "\nEmpty sector found!"

	jmp Forever
;	jmp FindFreeSector

__SectorNotEmpty:
	rep #A_8BIT				; A = 16 bit

	inc sourceSector
	lda sourceSector
	cmp #$21CB ; fatBeginLBA + sectorsPerFat on 4GB Sandisk card
	beq +

	sep #A_8BIT				; A = 8 bit

	jmp FindFreeSector

+	sep #A_8BIT				; A = 8 bit

	PrintSpriteText 19, 2, "Error!", 4

	jmp Forever



.ASM



; ******************************** EOF *********************************
