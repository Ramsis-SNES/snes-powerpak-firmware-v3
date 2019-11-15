;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: CF INTERFACE ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.INDEX 16

; ************************ Begin CF interaction ************************

AccessCFcard:

;CardReset:								; this used to be a subroutine
	lda	#%00000000
	sta	CARDLBA3						; select card 0
	lda	#%00000110						; do card sw reset
	sta	CARDDEVICE						; in device ctl reg
	wai
	wai
	lda	#%00000010
	sta	CARDDEVICE						; clear reset
	wai
	wai								; end of former subroutine

	wai
	jsr	SpriteMessageError					; show preliminary error message (removed upon successful card access)

StateCardNotInserted:							; wait until card inserted, show no card message
	lda	CARDSTATUS
	sta	errorCode
	and	#%11110000						; open bus = $A0
	cmp	#$A0
	bne	@StateCardInserted

	SetTextPos 21, 1
	PrintString "CF card not found.\n  Error code: $"
	PrintHexNum errorCode

	jsr	PrintRomVersion
	jsr	ShowConsoleVersion
	jsr	ShowMainGFX						; show logo
	jmp	Forever

@StateCardInserted:



StateCardBusy:								; wait until card not busy, show card busy message
	lda	CARDSTATUS
	sta	errorCode
	bpl	@StateCardBusyDone					; MSB clear --> card not busy
	wai

	SetTextPos 21, 1
	PrintString "CF card busy.     \n  Error code: $"
	PrintHexNum errorCode

	bra	StateCardBusy

@StateCardBusyDone:



StateCardReady:								; wait until card ready, show card not ready message
	lda	CARDSTATUS
	sta	errorCode
	and	#%01010000
	cmp	#%01010000						; ready = $50
	beq	@StateCardReadyDone
	wai

	SetTextPos 21, 1
	PrintString "CF card not ready.\n  Error code: $"
	PrintHexNum errorCode

	bra	StateCardReady

@StateCardReadyDone:



; -------------------------- read card, check format
	SetTextPos 21, 1
	PrintString "Reading CF card ..."

	lda	#%00000001						; set DMA off flag for now (this is later overwritten by the actual user setting)
	tsb	DP_UserSettings
;	stz	sourceSector						; it's not necessary to clear sourceSector at this point as WRAM was zero-filled upon boot
;	stz	sourceSector+1
;	stz	sourceSector+2
;	stz	sourceSector+3
	ldx	#sectorBuffer1
	stx	destLo
	stz	destBank
	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector						; read sector 0

	Accu16

	lda	sectorBuffer1+$1FE					; last word (FAT signature) check, should be $AA55
	cmp	#$AA55
	beq	+

	Accu8

	jmp	CardFormatError

+	ldx	#$0000							; x = partition index 0, 16, 32, 48

CardFormatCheckLoop:
	Accu8

	lda	#$01							; assume FAT32 for now
	sta	fat32Enabled
	lda	sectorBuffer1+$1C2, x					; read partition type code
	cmp	#$0B							; 0Bh = FAT32
	beq	CardGoodFormat
	cmp	#$0C							; 0Ch = FAT32 with LBA1 13h Extensions
	beq	CardGoodFormat
	stz	fat32Enabled						; byte isn't 0Bh or 0Ch --> partition is not FAT32
	cmp	#$06							; 06h = FAT16, larger than 32MB
	beq	CardGoodFormat
	cmp	#$04							; 04h = FAT16, smaller than 32MB
	beq	CardGoodFormat
	cmp	#$0E							; 0Eh = FAT16 with LBA1 13h Extensions
	beq	CardGoodFormat

	Accu16

	txa								; increment index to next partition entry
	clc
	adc	#16
	tax
	cmp	#64							; all 4 partition entries checked?
	bne	CardFormatCheckLoop

	Accu8

	jmp	CardFormatError						; no usable partition type code found --> error



CardGoodFormat:								; FAT16/FAT32 partition found
	stx	partitionIndex

	ClearLine 21							; hide "Reading CF card ..."
	ClearLine 22							; hide possible error code (from CF busy/not ready message)

	jsr	ClearSpriteText						; remove preliminary error message
	jsr	PrintCardFS						; show CF card filesystem type
	ldx	partitionIndex
	ldy	#$0000

CardCopyPartitionLBABegin:						; copy partitionLBABegin from offset 454
	lda	sectorBuffer1+$1C6, x
	sta	sourceSector, y
	sta	partitionLBABegin, y
	inx
	iny
	cpy	#$0004
	bne	CardCopyPartitionLBABegin

	ldx	#sectorBuffer1
	stx	destLo
	stz	destBank
	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector						; read FAT16/FAT32 Volume ID sector (partition boot record)

	lda	sectorBuffer1+$0D					; copy FAT16/FAT32 sectorsPerCluster from offset 13
	sta	sectorsPerCluster
	lda	sectorBuffer1+$0E					; copy FAT16/FAT32 reservedSectors from offset 14
	sta	reservedSectors
	lda	sectorBuffer1+$0F
	sta	reservedSectors+1
	ldx	#$0000

CardCopySectorsPerFat:							; copy FAT32 sectorsPerFat from offset 36
	lda	sectorBuffer1+$24, x
	sta	sectorsPerFat, x
	inx
	cpx	#$0004
	bne	CardCopySectorsPerFat

	ldx	#$0000

CardCopyRootDirCluster32:						; copy FAT32 rootDirCluster from offset 44
	lda	sectorBuffer1+$2C, x
	sta	rootDirCluster, x
	inx
	cpx	#$0004
	bne	CardCopyRootDirCluster32

	stz	fat16RootSectors					; FAT32 no entry limit in root directory
	lda	fat32Enabled
	cmp	#$01
	beq	CardCopyFatBeginLBA					; when FAT32, leave alone



;;;SPECIAL FAT16 handling

CardCopyRootDirCluster16:
	stz	rootDirCluster
	stz	rootDirCluster+1					; when FAT16, rootDirCluster = 0000 (root dir is not in cluster nums)
	stz	rootDirCluster+2
	stz	rootDirCluster+3
	lda	sectorBuffer1+$16
	sta	sectorsPerFat						; FAT16 copy sectorsPerFat from offset 22
	lda	sectorBuffer1+$17
	sta	sectorsPerFat+1
	stz	sectorsPerFat+2
	stz	sectorsPerFat+3						; FAT16 sectors per fat = 16 bits, in different place than FAT32

CardCopyRootDirEntries16:						; copy max root directory entries from offset 17
	lda	sectorBuffer1+$11
	sta	fat16RootSectors
	lda	sectorBuffer1+$12
	sta	fat16RootSectors+1
;	clc
;	lsr	fat16RootSectors
;	lsr	fat16RootSectors					; FAT16 rootSectors =  (max root entries * 32) / 512   =   fat16RootSectors/16  ASR x4
;	lsr	fat16RootSectors
;	lsr	fat16RootSectors
	lda	#$20
	sta	fat16RootSectors					; FAT16 root dir fixed at 512 entries = 32 sectors



CardCopyFatBeginLBA:
	Accu16

	clc								; fatBeginLBA(4) = partitionLBABegin(4) + reservedSectors(2)
	lda	reservedSectors
	adc	partitionLBABegin
	sta	fatBeginLBA
	lda	partitionLBABegin+2
	adc	#$0000
	sta	fatBeginLBA+2

;CardCopyClusterBeginLBA:
	lda	sectorsPerFat
	sta	clusterBeginLBA
	lda	sectorsPerFat+2
	sta	clusterBeginLBA+2
	clc
	asl	clusterBeginLBA						; clusterBeginLBA(4) = fatBeginLBA(4) + (2 * sectorPerFat(4))
	rol	clusterBeginLBA+2

	Accu8

	clc								; FAT16 = 32 sectors       FAT32 = 0 sectors
	lda	clusterBeginLBA						; clusterBeginLBA(4) = clusterBeginLBA(4) + fat16RootSectors(1)
	adc	fat16RootSectors
	sta	clusterBeginLBA
	lda	clusterBeginLBA+1
	adc	#$00
	sta	clusterBeginLBA+1

	Accu16

	lda	clusterBeginLBA+2
	adc	#$0000
	sta	clusterBeginLBA+2
	clc
	lda	clusterBeginLBA
	adc	fatBeginLBA
	sta	clusterBeginLBA
	lda	clusterBeginLBA+2
	adc	fatBeginLBA+2
	sta	clusterBeginLBA+2
	lda	rootDirCluster
	sta	sourceCluster
	lda	rootDirCluster+2
	sta	sourceCluster+2

	Accu8

 ;	PrintString "\n"
 ;	PrintHexNum sectorsPerCluster
 ;	PrintString "\n"

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
	jsr	PrintRomVersion

	ClearLine 21
	ClearLine 22
	SetTextPos 21, 1
	PrintString "Card format error: FAT16/FAT32 expected!"
	PrintString "\n  Type code: $"
	PrintHexNum sectorBuffer1+$1C2					; partition type code
	PrintString " | Last word ($AA55): $"
	PrintHexNum sectorBuffer1+$1FF					; high byte of signature word
	PrintHexNum sectorBuffer1+$1FE					; low byte of signature word

	jmp	Forever



CardWaitNotBusy:

@CardWaitNotBusyLoop:							; wait for not busy
	lda	CARDSTATUS						; card status read
;	sta	errorCode
	bpl	@CardWaitNotBusyDone					; MSB = card busy flag

;	SetTextPos 12, 0
;	PrintString "    Error $"
;	PrintHexNum errorCode
;	PrintString " - CF card busy    "

	bra	@CardWaitNotBusyLoop

@CardWaitNotBusyDone:
	rts



CardWaitReady:

@CardWaitReadyLoop:							; wait until card ready
	lda	CARDSTATUS
;	sta	errorCode
	and	#%01010000
	cmp	#%01010000
	beq	@CardWaitReadyDone

;	SetTextPos 12, 0
;	PrintString "    Error $"
;	PrintHexNum errorCode
;	PrintString " - CF not ready    "

	bra	@CardWaitReadyLoop

@CardWaitReadyDone:
	rts



CardWaitDataReq:							; wait for not busy, ready, datareq, no error

@CardWaitDataReqLoop:
	lda	CARDSTATUS
;	sta	errorCode
	and	#%01011000
	cmp	#%01011000
	beq	@CardWaitDataReqDone

;	SetTextPos 12, 0
;	PrintString "    Error $"
;	PrintHexNum errorCode
;	PrintString " - CF no data req    "

	bra	@CardWaitDataReqLoop

@CardWaitDataReqDone:
	rts



/*
CardTESTCheckError:
	SetTextPos 22, 0
	PrintString "  "

	wai
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	lda	CARDSTATUS						; get card status, check for general error
	sta	errorCode
	and	#%00000001
	bne	CardError
	lda	REG_RDNMI						; clear NMI flag
	lda	#$81
	sta	REG_NMITIMEN						; re-enable VBlank NMI
	cli

	SetTextPos 22, 0
	PrintString "OK"

	rts
*/



CardCheckError:
	lda	CARDSTATUS						; get card status, check for general error
	sta	errorCode
	and	#%00000001
;	bne	CardError						; CAVEAT: THIS MYSTERIOUSLY DOES NOT WORK!!!
	cmp	#%00000001
	beq	@CardError
	rts

@CardError:
	ClearLine 21
	ClearLine 22
	ClearLine 23
	SetTextPos 21, 1

	ldy	#errorCode

	PrintString "Error $%x - CF card status"

	lda	CARDERROR
	sta	errorCode
	ldy	#errorCode

	PrintString "\n  Error $%x - CF card error"

	lda	CARDSECTORCOUNTREAD
	sta	errorCode
	ldy	#errorCode

	PrintString "\n  CSCR=$%x"

	lda	CARDLBA0READ
	sta	errorCode
	ldy	#errorCode

	PrintString " | LBA0=$%x"

	lda	CARDLBA1READ
	sta	errorCode
	ldy	#errorCode

	PrintString " | LBA1=$%x"

	lda	CARDLBA2READ
	sta	errorCode
	ldy	#errorCode

	PrintString " | LBA2=$%x"

	lda	CARDLBA3READ
	sta	errorCode
	ldy	#errorCode

	PrintString " | LBA3=$%x"

	jmp	Forever



; ************************* Read from CF card **************************

CardLoadLBA:
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	jsr	CardCheckError

	lda	#$01
	sta	CARDSECTORCOUNT
	jsr	CardWaitNotBusy						; LAST check busy/ready/error after each command
	jsr	CardWaitReady
;	jsr	CardCheckError

	lda	sourceSector
	sta	CARDLBA0
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
;	jsr	CardCheckError

	lda	sourceSector+1
	sta	CARDLBA1
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
;	jsr	CardCheckError

	lda	sourceSector+2
	sta	CARDLBA2
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
;	jsr	CardCheckError

	lda	sourceSector+3						; load LBA number
	and	#%00001111
	ora	#%11100000
	sta	sourceSector+3
	sta	CARDLBA3
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	jsr	CardCheckError

	rts



CardReadSector:
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	jsr	CardLoadLBA

	lda	#$20
	sta	CARDCOMMAND						; send card read sector command
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	jsr	CardCheckError
	jsr	CardWaitDataReq

	lda	DP_DataDestination					; read data destination

	Accu16

	and	#$00FF							; remove garbage in Accu B
	asl	a							; use DP_DataDestination as a jump table index
	tax

	Accu8

	jmp	(@PTR_kDest, x)

@PTR_kDest:
	.DW	@CRS_toFPGA
	.DW	@CRS_toSDRAM
	.DW	@CRS_toSDRAMnoDMA
	.DW	@CRS_toWRAM
	.DW	@CRS_toWRAMnoDMA



@CRS_toFPGA:
	ldx	#512							; transfer 512 bytes
-	lda	CARDDATAREAD						; read data byte
	sta	FPGADATAWRITE						; write to FPGA
	dex
	bne	-

	jmp	@CRS_Done

@CRS_toSDRAM:
	DMA_WaitHblank $08, CARDDATAREADbank, CARDDATAREADhigh, CARDDATAREADlow, DMAPORT, 512

	bra	@CRS_Done

@CRS_toSDRAMnoDMA:
	ldx	#512							; transfer 512 bytes
-	lda	CARDDATAREAD						; read data byte
	sta	DMAREADDATA						; write to SDRAM
	dex
	bne	-

	bra	@CRS_Done

@CRS_toWRAM:
	lda	DP_UserSettings
	and	#%00000001						; check for DMA flag
	bne	@CRS_toWRAMnoDMA					; flag set --> don't use DMA
	ldx	destLo
	stx	REG_WMADDL						; set WRAM destination address
	lda	destBank
	sta	REG_WMADDH

	DMA_WaitHblank $08, CARDDATAREADbank, CARDDATAREADhigh, CARDDATAREADlow, $80, 512

	bra	@CRS_Done

@CRS_toWRAMnoDMA:							; read 512 bytes into WRAM
	ldx	#512
	ldy	#$0000
-	lda	CARDDATAREAD
	sta	[destLo], y
	iny
	dex
	bne	-

;	PrintHexNum bankCounter
;	PrintString "CardReadBytesDone\n"

@CRS_Done:
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	jsr	CardCheckError

;	lda	CARDSECTORCOUNTREAD
;	sta	errorCode
;	bne	CardReadSectorFailed					; LAST make sure sectors = 0

;CardReadSectorPassed:
;	jsr	CardWaitNotBusy						; LAST check for busy before error
;	jsr	CardWaitReady
;	jsr	CardCheckError

	lda	REG_RDNMI						; clear NMI flag, this is necessary to prevent occasional graphics glitches (see Fullsnes, 4210h/RDNMI)
	lda	#$81
	sta	REG_NMITIMEN						; re-enable VBlank NMI
	cli
	rts



;CardReadSectorFailed:
;	ClearLine 19
;	ClearLine 20
;	SetTextPos 19, 1
;	PrintString "Error CF sectors left = "
;	PrintHexNum errorCode
;	SetTextPos 20, 1

;	lda	CARDERROR
;	sta	errorCode

;	PrintString "Error $"
;	PrintHexNum errorCode
;	PrintString " - CF card error"

;CardReadSectorFailedForever:
;	jmp	Forever



CardReadGameFill:
	Accu16

	stz	gameSize
	lda	gameName.Cluster					; set source cluster
	sta	sourceCluster
	lda	gameName.Cluster+2
	sta	sourceCluster+2

	Accu8

	stz	sectorCounter
	stz	bankCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector

	bit	fixheader						; check for "assume copier header" flag
	bpl	@ReadSector
	bra	@NextSector						; sector=0 and header present --> skip that sector

.ACCU 16

@Reiterate:
	lda	gameName.Cluster					; set source cluster (again)
	sta	sourceCluster
	lda	gameName.Cluster+2
	sta	sourceCluster+2

	Accu8

	stz	sectorCounter
	stz	bankCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector

@ReadSector:
	lda	#kSDRAM							; read sectors to SDRAM (self-reminder: this needs to be declared every iteration as DP_DataDestination is destroyed in a sub-sub routine of IncrementSectorNum [namely NextCluster])
	sta	DP_DataDestination
	jsr	CardReadSector

	Accu16

	inc	gameSize						; keep track of game size, skipping header sector

	Accu8

@NextSector:
	IncrementSectorNum

	inc	destHi
	inc	destHi
	inc	bankCounter
	bra	@ReadSector

__	lda	gameSize+1
	cmp	#$04							; read file again until $400 sectors = 512KB have been copied
	bcc	+							; (probably in order to "improve" support for smaller ROMs ??)
	rts

+	Accu16

	jmp	@Reiterate



.ACCU 8

CardReadFile:								; sourceCluster already set
	stz	gameSize
	stz	gameSize+1
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector

@CardReadFileLoop:
;	PrintHexNum sourceSector+3
;	PrintHexNum sourceSector+2
;	PrintHexNum sourceSector+1
;	PrintHexNum sourceSector+0
;	PrintString "."

	Accu16

	inc	gameSize						; keep track of file size

	Accu8

	lda	#kSDRAM
	sta	DP_DataDestination
	jsr	CardReadSector

	IncrementSectorNum

	inc	destHi							; dest = dest + 512
	inc	destHi
	inc	bankCounter
	bra	@CardReadFileLoop

__	rts



CardWriteFile:								; sourceCluster already set
	stz	sectorCounter
	stz	bankCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector

@CardWriteFileLoop:
	jsr	CardWriteSector

	IncrementSectorNum

	inc	sourceHi						; source = source + 512
	inc	sourceHi
	inc	bankCounter
	bra	@CardWriteFileLoop

__	rts



CardWriteSector:
	sei								; disable NMI & IRQ
	stz	REG_NMITIMEN
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	jsr	CardCheckError
	jsr	CardLoadLBA
	jsr	CardWaitNotBusy
	jsr	CardWaitReady
	jsr	CardCheckError

	lda	#$30
	sta	CARDCOMMAND						; send card write sector command
	nop
	nop
	jsr	CardCheckError
	jsr	CardWaitDataReq

	lda	DP_DataSource						; read data source

	Accu16

	and	#$00FF							; remove garbage in Accu B
	asl	a							; use DP_DataSource as a jump table index
	tax

	Accu8

	jmp	(@PTR_kSource, x)

@PTR_kSource:
	.DW	$0000							; dummy bytes (no transfers from FPGA)
	.DW	@CWS_fromSDRAM
	.DW	@CWS_fromSDRAM
	.DW	@CWS_fromWRAM
	.DW	@CWS_fromWRAM



@CWS_fromSDRAM:								; write 512 bytes onto CF card
	ldx	#512
-	lda	DMAREADDATA
	sta	CARDDATAWRITE
	dex
	bne	-

	bra	@CWS_Done

@CWS_fromWRAM:								; write 512 bytes onto CF card
	ldx	#512
	ldy	#$0000
-	lda	[sourceLo], y
	sta	CARDDATAWRITE
	iny
	dex
	bne	-

@CWS_Done:
	jsr	CardCheckError

	lda	REG_RDNMI						; clear NMI flag // ADDED for v3.00
	lda	#$81
	sta	REG_NMITIMEN						; re-enable VBlank NMI
	cli
	rts



; cluster->lba     lba_addr(4) = clusterBeginLBA(4) + (cluster_number(2)-2 * sectorsPerCluster(1))
ClusterToLBA:
	Accu16

	sec
	lda	sourceCluster
	sbc	#$0002
	sta	sourceSector
	lda	sourceCluster+2
	sbc	#$0000
	sta	sourceSector+2						; sourceSector = sourceCluster - 2

	Accu8

	lda	sectorsPerCluster
	sta	source256
	lsr	source256
	beq	+							; handle 1 sector per cluster

@ClusterToLBALoop:
	Accu16

	asl	sourceSector
	rol	sourceSector+2						; sourceSector = sourceSector * sectorsPerCluster

	Accu8

	lsr	source256
	bne	@ClusterToLBALoop

+	Accu16

	clc
	lda	sourceSector
	adc	clusterBeginLBA
	sta	sourceSector
	lda	sourceSector+2
	adc	clusterBeginLBA+2
	sta	sourceSector+2						; sourceSector = sourceSector(4) + clusterBeginLBA(4)

	Accu8

	rts



; ********************* Load dir from CF to buffer *********************

; Loads the contents of a directory and stores relevant files in the
; selected buffer (WRAM/SDRAM). CLDConfigFlags are reset upon RTS.

; destLo/Hi = WRAM destination address for sector being read.
; sourceEntryLo/Hi = address of FAT entry within current sector buffer.
; destEntryLo/Hi/Bank = WRAM address where to put file entry (name +
; cluster).

CardLoadDir:
	ldx	#sectorBuffer1
	stx	destLo							; sourceSector1 = where to put sector, where to read entry
	stx	sourceEntryLo
	stz	destBank						; bank $00 = lower 8K of WRAM
	stz	sourceEntryBank						; ditto
	lda	#$7F							; start at WRAM offset $7F0000
	sta	destEntryBank
	stz	destEntryHi
	stz	destEntryLo
	lda	#$00							; start at SDRAM offset $000000
	sta	DMAWRITELO
	sta	DMAWRITEHI
	sta	DMAWRITEBANK

	Accu16

	stz	filesInDir
	stz	temp
	stz	selectedEntry

	Accu8

	stz	sectorCounter
	jsr	ClusterToLBA						; sourceCluster -> first sourceSector

	Accu16

	lda	fat32Enabled
	and	#$0001
	bne	@CLD_ReadSector						; FAT32 detected, go to read sector
	lda	sourceCluster						; FAT16 check if trying to load root dir
	cmp	rootDirCluster
	bne	@CLD_ReadSector
	lda	sourceCluster+2
	cmp	rootDirCluster+2
	bne	@CLD_ReadSector

	Accu8

	sec
	lda	clusterBeginLBA						; FAT16 sourceSector = root dir first sector => clusterLBABegin(4) - fat16RootSectors(1)
	sbc	fat16RootSectors
	sta	sourceSector
	lda	clusterBeginLBA+1
	sbc	#$00
	sta	sourceSector+1

	Accu16

	lda	clusterBeginLBA+2
	sbc	#$0000
	sta	sourceSector+2

@CLD_ReadSector:
	Accu8

	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector						; put into dest
	jsr	CLD_ClearEntryName					; clear tempEntry, reset lfnFound



CardLoadDirLoop:



; -------------------------- check for last entry
	ldy	#$0000
	lda	[sourceEntryLo], y					; if name[0] = 0x00, no more entries
	bne	@CLD_EntryNotLast
	jmp	@CLD_LastEntryFound

@CLD_EntryNotLast:



; -------------------------- check for unused entry
	ldy	#$0000
	lda	[sourceEntryLo], y
	cmp	#$E5							; if name[0] = 0xE5, entry unused, skip
	bne	@CLD_EntryNotUnused
	stz	lfnFound
	jmp	@CLD_NextEntry

@CLD_EntryNotUnused:



; -------------------------- check for LFN entry
	ldy	#$000B
	lda	[sourceEntryLo], y					; if flag = %00001111, long file name entry found
	and	#$0F
	cmp	#$0F
	bne	@CLD_EntryNotLFN
	ldy	#$0000							; check first byte of LFN entry = ordinal field
	lda	[sourceEntryLo], y
	and	#%10111111						; mask off "last entry" bit
	cmp	#$0A							; if index = 1...9, load name
	bcc	@CLD_EntryPrepareLoadLFN
	jsr	CLD_ClearEntryName					; if index >= 10, skip entry (reminder: index = 0 doesn't seem to exist ??)
	jmp	@CLD_NextEntry

@CLD_EntryPrepareLoadLFN:
	sta	REG_M7A							; PPU multiplication
	stz	REG_M7A
	lda	#$0D							; LFNs consist of 13 unicode characters
	sta	REG_M7B

	Accu16

	lda	REG_MPYL						; read result
	sec
	sbc	#$000D							; subtract 13 to make up for missing index 0
	tax								; transfer to X register

	Accu8

	jsr	CLD_LoadLFN						; load LFN entry, store characters to tempEntry
	jmp	@CLD_NextEntry

@CLD_EntryNotLFN:



; -------------------------- check for volume ID entry
	ldy	#$000B
	lda	[sourceEntryLo], y					; if flag = volume id, skip
	and	#$08
	cmp	#$08
	bne	@CLD_EntryNotVolumeID
	jsr	CLD_ClearEntryName
	jmp	@CLD_NextEntry

@CLD_EntryNotVolumeID:



; -------------------------- short file name found, perform additional checks

; -------------------------- check for hidden entry
	ldy	#$000B
	lda	[sourceEntryLo], y
	and	#$02							; if flag = 0x02, hidden, mark as such
	beq	@CLD_EntryHiddenCheckDone
	tsb	tempEntry.Flags						; save "hidden" flag

@CLD_EntryHiddenCheckDone:



; -------------------------- check for directory entry
	ldy	#$000B
	lda	[sourceEntryLo], y					; if flag = directory, load entry
	and	#$10
	beq	@CLD_EntryNotDirectory
	lda	#$01
	tsb	tempEntry.Flags						; save "dir" flag

	Accu16

	bra	@CLD_ProcessMatchingEntry

@CLD_EntryNotDirectory:



; -------------------------- check for entry extension
	ldx	extNum							; check if entry matches any extension wanted,
	dex								; backwards from the Nth (= $NNNN-1) to the 1st (= $0000) extension

@CLD_CheckExtLoop:
	ldy	#$0008
	lda	[sourceEntryLo], y
	cmp	extMatch1, x
	bne	+
	iny
	lda	[sourceEntryLo], y
	cmp	extMatch2, x
	bne	+
	iny
	lda	[sourceEntryLo], y
	cmp	extMatch3, x
	beq	@CLD_EntryExtensionMatch				; extension matches
+	dex								; otherwise, try next extension indicated
	bpl	@CLD_CheckExtLoop

	jsr	CLD_ClearEntryName					; extension doesn't match, skip entry
	jmp	@CLD_NextEntry

@CLD_EntryExtensionMatch:



; -------------------------- check file size
	Accu16

	ldy	#$001E
	lda	[sourceEntryLo], y					; upper 16 bit of file size
	bne	@CLD_FileSizeNotZero
	ldy	#$001C
	lda	[sourceEntryLo], y					; lower 16 bit of file size
	bne	@CLD_FileSizeNotZero

	Accu8

	jsr	CLD_ClearEntryName					; file size = 0, skip entry
	jmp	@CLD_NextEntry

.ACCU 16

@CLD_FileSizeNotZero:
	ldy	#$001C							; check lower 16 bit of file size for copier header
	lda	[sourceEntryLo], y
	and	#$03FF							; from FullSNES: "IF (filesize AND 3FFh)=200h THEN HeaderPresent=True"
	cmp	#$0200
	bne	@CLD_ProcessMatchingEntry
	lda	#$0080							; copier header (apparently) present, set "copier header present" flag
	tsb	tempEntry.Flags						; upper 8 bits (1st byte of tempEntry.Cluster) not affected



; -------------------------- load long/short dir or entry with matching ext. and size not zero
@CLD_ProcessMatchingEntry:
	inc	filesInDir						; increment file counter

	Accu8

	lda	lfnFound
	cmp	#$01
	beq	@CLD_PrepareSaveEntry
	ldy	#$0000							; if lfnFound = 0, copy short file name only
-	lda	[sourceEntryLo], y
	sta	tempEntry, y
	iny
	cpy	#$0008
	bne	-

	lda	tempEntry.Flags
	and	#%00000001						; check for "dir" flag
	bne	@CLD_PrepareSaveEntry
	lda	#'.'							; if not directory, copy short file name extension
	sta	tempEntry+$8
	ldy	#$0008
	lda	[sourceEntryLo], y
	sta	tempEntry+$9
	iny
	lda	[sourceEntryLo], y
	sta	tempEntry+$A
	iny
	lda	[sourceEntryLo], y
	sta	tempEntry+$B

@CLD_PrepareSaveEntry:
	Accu16

	ldy	#$001A
	lda	[sourceEntryLo], y					; copy cluster (32 bit) to last 4 bytes of entry
	sta	tempEntry.Cluster
	ldy	#$0014
	lda	[sourceEntryLo], y
	sta	tempEntry.Cluster+2

	Accu8

	ldy	#$0000							; reset Y for upcoming loop
	lda	CLDConfigFlags						; check for selected buffer
	and	#%00000001
	bne	@CLD_UseSDRAMbuffer
	jsr	CLD_SaveEntryToWRAM

	Accu16

	lda	filesInDir						; check if file counter has reached 512
	cmp	#$0200
	bcc	@CLD_WRAMcontinue

	Accu8								; if so, A = 8 bit

	jmp	@CLD_LastEntryFound					; ... and don't process any more entries

@CLD_WRAMcontinue:
	Accu8								; otherwise, A = 8 bit, and continue

	jsr	CLD_ClearEntryName
	bra	@CLD_NextEntry

@CLD_UseSDRAMbuffer:
	lda	CLDConfigFlags						; check if hidden files/folders are to be skipped
	and	#%00000010
	beq	@CLD_SaveEntryToSDRAM
	lda	tempEntry.Flags
	and	#%00000010						; yes, check for "hidden" flag
	beq	@CLD_SaveEntryToSDRAM

	Accu16

	dec	filesInDir						; hidden dir/file found, decrement file counter ...
	bra	@CLD_SDRAMcontinue					; ... and jump out

.ACCU 8

@CLD_SaveEntryToSDRAM:
	lda	tempEntry, y						; save entry to SDRAM
	sta	DMAREADDATA
	iny
	cpy	#$0080
	bne	@CLD_SaveEntryToSDRAM

	Accu16

	lda	filesInDir
	cmp	#$FFFF							; check if file counter has reached 65535
	bcc	@CLD_SDRAMcontinue

	Accu8								; if so, A = 8 bit

	jmp	@CLD_LastEntryFound					; ... and don't process any more entries

@CLD_SDRAMcontinue:
	Accu8								; otherwise, A = 8 bit, and continue

	jsr	CLD_ClearEntryName



; -------------------------- finally, increment to next entry, and loop
@CLD_NextEntry:
	Accu16

	clc								; increment entry source address
	lda	sourceEntryLo						; sourceEntry += 32 in 0200-0400
	adc	#$0020
	sta	sourceEntryLo

	Accu8

	lda	sourceEntryHi						; if source overflows, get next sector
	cmp	#>sectorBuffer1+$02					; LAST CHANGE
	beq	@CLD_NextSector
	jmp	CardLoadDirLoop



; -------------------------- if necessary, increment source sector
@CLD_NextSector:
	Accu16

	clc
	lda	sourceSector
	adc	#$0001
	sta	sourceSector						; go to next sector num
	lda	sourceSector+2
	adc	#$0000
	sta	sourceSector+2
	lda	fat32Enabled						; if FAT32, increment sector
	and	#$0001
	bne	@CLD_SectorIncrement
	lda	sourceCluster						; FAT16 check if trying to load root dir
	cmp	rootDirCluster
	bne	@CLD_SectorIncrement
	lda	sourceCluster+2
	cmp	rootDirCluster+2
	bne	@CLD_SectorIncrement

	Accu8

	inc	sectorCounter						; FAT16 root dir all sequential sectors
	lda	sectorCounter
	cmp	fat16RootSectors					; if sectorCounter = fat16RootSectors, jump out
	beq	@CLD_LastEntryFound
	bra	@CLD_LoadNextSector					; FAT16 skip cluster lookup when max root sectors not reached

@CLD_SectorIncrement:
	Accu8

	inc	sectorCounter						; one more sector
	lda	sectorCounter
	cmp	sectorsPerCluster					; make sure cluster isn't overflowing
	bne	@CLD_LoadNextSector
	jsr	NextCluster						; move to next cluster

	Accu16

; check for last sector
; FAT32 last cluster = 0x0FFFFFFF
; FAT16 last cluster = 0x0000FFFF

	lda	fat32Enabled						; check for FAT32
	and	#$0001
	bne	@CLD_LastClusterMaskFAT32
	stz	temp+2							; if FAT16, high word = $0000
	bra	@CLD_LastClusterMaskDone

@CLD_LastClusterMaskFAT32:
	lda	#$0FFF							; if FAT32, high word = $0FFF
	sta	temp+2

@CLD_LastClusterMaskDone:						; if cluster = last cluster, jump to last entry found
	lda	sourceCluster
	cmp	#$FFFF							; low word = $FFFF (FAT16/32)
	bne	@CLD_NextSectorNum
	lda	sourceCluster+2
	cmp	temp+2
	bne	@CLD_NextSectorNum

	Accu8

	bra	@CLD_LastEntryFound					; last cluster, jump out

@CLD_NextSectorNum:
	Accu8

	jsr	ClusterToLBA						; sourceCluster -> first sourceSector
	stz	sectorCounter						; reset sector counter

@CLD_LoadNextSector:
	ldx	#sectorBuffer1
	stx	destLo							; reset sector dest
	stx	sourceEntryLo						; reset entry source
	stz	destBank
	stz	sourceEntryBank
	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector
	jmp	CardLoadDirLoop

@CLD_LastEntryFound:
	stz	CLDConfigFlags						; reset CardLoadDir config flags
	rts



; -------------------------- CardLoadDir subroutine: load LFN entry
CLD_LoadLFN:
	ldy	#$0001

@CLD_LoadLFNLoop1:
	lda	[sourceEntryLo], y					; copy unicode chars 1-5 from offsets $01, $03, $05, $07, $09
	cmp	#$FF
	beq	+
	sta	tempEntry, x
+	inx
	iny
	iny
	cpy	#$000B
	bne	@CLD_LoadLFNLoop1

	ldy	#$000E

@CLD_LoadLFNLoop2:
	lda	[sourceEntryLo], y					; copy unicode chars 6-11 from offsets $0E, $10, $12, $14, $16, $18
	cmp	#$FF
	beq	+
	sta	tempEntry, x
+	inx
	iny
	iny
	cpy	#$001A
	bne	@CLD_LoadLFNLoop2

	ldy	#$001C

@CLD_LoadLFNLoop3:
	lda	[sourceEntryLo], y					; copy unicode chars 12-13 from offsets $1C, $1E
	cmp	#$FF
	beq	+
	sta	tempEntry, x
+	inx
	iny
	iny
	cpy	#$0020
	bne	@CLD_LoadLFNLoop3

	lda	#$01
	sta	lfnFound
	rts



; -------------------------- CardLoadDir subroutine: save entry to WRAM buffer
CLD_SaveEntryToWRAM:
	Accu16

-	lda	tempEntry, y						; Y was reset before
	sta	[destEntryLo], y
	iny
	iny
	cpy	#$0080
	bne	-

	clc
	lda	destEntryLo						; destEntryHiLo += 128
	adc	#$0080
	sta	destEntryLo

	Accu8

	rts



; -------------------------- CardLoadDir subroutine: reset tempEntry & LFN variables
CLD_ClearEntryName:
	stz	lfnFound

	Accu16

	lda	#$0000
	ldy	#$0000
-	sta	tempEntry, y
	iny
	iny
	cpy	#$0080
	bne	-

	Accu8

	rts



; **************************** Next cluster ****************************

; Load FAT entry for sourceCluster, store next cluster number into
; sourceSector.

NextCluster:
	Accu16

	asl	sourceCluster						; FAT16: offset = clusternum << 1
	rol	sourceCluster+2						; mask = 00 00 ff ff
	lda	fat32Enabled
	and	#$0001
	beq	@NextClusterSectorNum
	asl	sourceCluster						; FAT32: offset = clutsernum << 2 || cluster 2 << 2 = 8
	rol	sourceCluster+2						; mask = 0f ff ff ff

@NextClusterSectorNum:							; FAT sector num = fatBeginLBA + (offset / 512) || cluster = $2f8
	lda	sourceCluster+1						; first, divide by 256 by shifting sourceCluster 8 bits right,
	sta	sourceSector+0						; and store to sourceSector

	Accu8

	lda	sourceCluster+3
	sta	sourceSector+2
	stz	sourceSector+3						; division by 256 done || sector = 02

	Accu16

	lsr	sourceSector+2						; next, shift sourceSector 1 more bit right (div. by 512) || sector = 01
	ror	sourceSector+0
	clc
	lda	sourceSector						; add fatBeginLBA || sector = 60 = $c000
	adc	fatBeginLBA
	sta	sourceSector
	lda	sourceSector+2
	adc	fatBeginLBA+2
	sta	sourceSector+2

	Accu8

	ldx	#sectorBuffer1						; load FAT sector
	stx	destLo
	stz	destBank
	lda	#kWRAM
	sta	DP_DataDestination
	jsr	CardReadSector

; offset = offset % 512 -- offset of FAT entry within loaded sector 0-511
	lda	sourceCluster+1
	and	#%00000001
	sta	sourceCluster+1						; cluster+1=0
	lda	#<sectorBuffer1						; next cluster = [sector], offset
	sta	sourceLo
	stz	sourceBank

; sourceHi = sectorBuffer1(high) or sectorBuffer1(high)+1 for which 256 byte block to look in
	lda	#>sectorBuffer1
	adc	sourceCluster+1
	sta	sourceHi
	lda	sourceCluster
	sta	temp+2
	stz	temp+3
	ldy	temp+2
	ldx	#$0000

@NextClusterLoop:
	lda	[sourceLo], y
	sta	sourceCluster, x
	iny
	inx
	cpx	#$0004
	bne	@NextClusterLoop

	lda	sourceCluster+3						; FAT32 mask off top 4 bits
	and	#$0F
	sta	sourceCluster+3
	lda	fat32Enabled
	cmp	#$01
	beq	@NextClusterDone					; no more mask for FAT32
	stz	sourceCluster+3						; FAT16 mask
	stz	sourceCluster+2

@NextClusterDone:
	rts



; ************************** Get next sector ***************************

LoadNextSectorNum:							; get next sector, use sectorCounter to check if next cluster needed
	Accu16

	clc
	lda	sourceSector
	adc	#$0001
	sta	sourceSector						; go to next sector num
	lda	sourceSector+2
	adc	#$0000
	sta	sourceSector+2

	Accu8

	inc	sectorCounter						; one more sector
	lda	sectorCounter
	cmp	sectorsPerCluster					; are we there yet?
	bne	+
	stz	sectorCounter						; yes, next cluster needed
	jsr	NextCluster						; get cluster num into sourceCluster from FAT table

.IFDEF DEBUG
	PrintString "cluster="
	PrintString sourceCluster+3
	PrintString sourceCluster+2
	PrintString sourceCluster+1
	PrintString sourceCluster+0
	PrintString "\n"
.ENDIF

	jsr	ClusterToLBA						; get sector num into sourceSector

.IFDEF DEBUG
	PrintString "sector="
	PrintHexNum sourceSector+3
	PrintHexNum sourceSector+2
	PrintHexNum sourceSector+1
	PrintHexNum sourceSector+0
	PrintString "\n"

	DelayFor 172
.ENDIF

+	rts



.ENDASM



; ************************* WIP file creation **************************

GotoSRMTest:
	jsr	HideButtonSprites
	jsr	HideLogoSprites
	jsr	PrintClearScreen

	SetTextPos 0, 0
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

	Accu16

	lda	fatBeginLBA						; first FAT sector --> sourceSector for sector reading
	sta	sourceSector
	lda	fatBeginLBA+2
	sta	sourceSector+2

	Accu8

FindFreeSector:
	lda	#$E0							; mask off upper 3 bits (set in CardLoadLBA, reason unknown ??)
	trb	sourceSector+3

	SetTextPos 4, 6
	PrintHexNum sourceSector+3
	PrintHexNum sourceSector+2
	PrintHexNum sourceSector+1
	PrintHexNum sourceSector+0

	lda	#kWRAM							; set WRAM as destination
	sta	DP_DataDestination
	ldx	#sectorBuffer1
	stx	destLo
	stz	destBank
	jsr	CardReadSector						; read FAT sector to WRAM

	Accu16

	ldx	#$0000
-	lda	sectorBuffer1, x
	bne	@SectorNotEmpty
	inx
	inx
	cpx	#512
	bne	-

	Accu8

	PrintString "\nEmpty sector found!"

	jmp	Forever
;	jmp	FindFreeSector

@SectorNotEmpty:
	Accu16

	inc	sourceSector
	lda	sourceSector
	cmp	#$21CB ; fatBeginLBA + sectorsPerFat on 4GB Sandisk card
	beq	+

	Accu8

	jmp	FindFreeSector

+	Accu8

	PrintSpriteText 19, 2, "Error!", 4

	jmp	Forever



.ASM



; ******************************** EOF *********************************
