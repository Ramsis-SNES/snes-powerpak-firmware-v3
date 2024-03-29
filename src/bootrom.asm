;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN BOOTLOADER ROM LAYOUT ***
;
;==========================================================================================



; ************************* Assembler settings *************************

;.DEFINE DEMOMODE							; PowerPak demo (e.g. for emulation)
;.DEFINE SHOWDEBUGMSGS							; print stack pointer, selectedEntry, frame length counter etc.
;.DEFINE DEBUG								; don't uncomment this (effects untested)



; ********************** ROM makeup, SNES header ***********************

.EMPTYFILL		$FF

.MEMORYMAP
	DEFAULTSLOT	0
	SLOTSIZE	$8000
	SLOT 0		$8000
.ENDME



.ROMBANKSIZE		$8000						; ROM banks are 32 KiB in size
.ROMBANKS		4						; 4 ROM banks = 1 Mbit



.SNESHEADER								; this also calculates ROM checksum & complement
	ID		"SNES"
	NAME		"SNES PowerPak Loader "
	LOROM
	SLOWROM
	CARTRIDGETYPE	$00
	ROMSIZE		$07
	SRAMSIZE	$00
	COUNTRY		$01
	LICENSEECODE	$00
	VERSION		$00
.ENDSNES



.BANK 0 SLOT 0
.ORG $7FB0

	.DB		"00"						; new licensee code (likely irrelevant)



; *************************** Vector tables ****************************

.SNESNATIVEVECTOR
	COP		ErrorHandlerCOP
	BRK		ErrorHandlerBRK
	ABORT		EmptyHandler
	NMI		VBlank
	UNUSED		$0000
	IRQ		EmptyHandler
.ENDNATIVEVECTOR



.SNESEMUVECTOR
	COP		EmptyHandler
	UNUSED		$0000
	ABORT		EmptyHandler
	NMI		EmptyHandler
	RESET		Main
	IRQBRK		EmptyHandler
.ENDEMUVECTOR



; -------------------------- empty vectors
.BANK 0 SLOT 0
.ORG 0

.SECTION "EmptyVectors" SEMIFREE

EmptyHandler:
	rti

.ENDS



; **************** Variables, macros, library routines *****************

.INCLUDE "lib_variables.asm"						; global variables
.INCLUDE "lib_macros.asm"						; macros



; ******************************* BANK 0 *******************************

.BANK 0 SLOT 0
.ORG 0

.SECTION "FirmwareVersionStrings" FORCE

;STR_Firmware_Title:
	.DB "Unofficial SNES PowerPak "

STR_Firmware_Version:
	.DB "Firmware v"

STR_Firmware_VerNum:
	.DB "3.10"

STR_Firmware_VerNum_End:
	.DB " "

STR_Firmware_Codename:
	.DB "\"MUFASA\"", 0

STR_Firmware_Build:
	.DB "Build #"

STR_Firmware_BuildNum:
	.DB "11446"

STR_Firmware_BuildNum_End:
	.DB 0

;STR_Firmware_Maker:
	.DB "(c) by https://manuloewe.de/", 0

;STR_Firmware_Timestamp:
	.DB "Assembled ", WLA_TIME, 0

PTR_Firmware_Version:
	.DW STR_Firmware_Version

PTR_Firmware_Build:
	.DW STR_Firmware_Build

PTR_findEntry:
	.DW findEntry

PTR_tempEntry:
	.DW tempEntry

SRC_Zeroes:
	.DW 0

.ENDS



; -------------------------- main loader code
.SECTION "MainCode" SEMIFREE

.INCLUDE "main_boot.inc.asm"						; main bootloader code
.INCLUDE "main_cf_interface.inc.asm"
.INCLUDE "main_filebrowser.inc.asm"
.INCLUDE "main_gfxsetup.inc.asm"					; SNES graphics & screen setup
.INCLUDE "main_irqnmi.inc.asm"						; Vblank NMI routines
.INCLUDE "main_romspc.inc.asm"
.INCLUDE "main_options.inc.asm"
.INCLUDE "main_gamegenie.inc.asm"
.INCLUDE "main_rommapping.inc.asm"
.INCLUDE "main_sram.inc.asm"
.INCLUDE "main_settings.inc.asm"
.INCLUDE "main_theme.inc.asm"						; theme file handler
.INCLUDE "main_devnote.inc.asm"						; developer's note
.INCLUDE "main_spcplayer.inc.asm"					; SPC player
.INCLUDE "main_flasher.inc.asm"						; internal EEPROM update flasher
.INCLUDE "lib_randomnrgen.inc.asm"					; random number generator
.INCLUDE "lib_strings.inc.asm"						; text engine

.ENDS



; ******************************* BANK 1 *******************************

.BANK 1 SLOT 0
.ORG 0

.SECTION "CharacterData" FORCE

.INCLUDE "data_gfxdata.inc.asm"						; sprites, fonts, palettes
.INCLUDE "data_hdma_tables.inc.asm"
.INCLUDE "data_font_width_table.inc.asm"

.ENDS



; ******************************* BANK 2 *******************************

.BANK 2 SLOT 0
.ORG 0

.SECTION "SoundStuff" FORCE

.INCLUDE "lib_spcload.inc.asm"						; SPC loader
.INCLUDE "lib_snesmod.inc.asm"						; SNESMod
.INCLUDE "data_sm_spc_alek.inc.asm"					; SPC700 machine code for SnesMod

.ENDS



; ******************************* BANK 3 *******************************

.BANK 3 SLOT 0
.ORG 0

.SECTION "SoundBank" FORCE

SOUNDBANK:

.INCBIN "soundbnk.bnk"							; music binary data (for developer's note)

.ENDS



; ******************************** EOF *********************************
