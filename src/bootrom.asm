;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** MAIN BOOTLOADER ROM LAYOUT ***
;
;==========================================================================================



; ************************* Assembler settings *************************

;.DEFINE DEMOMODE				; PowerPak demo (e.g. for emulation)

;.DEFINE SHOWDEBUGMSGS				; print stack pointer, selectedEntry, frame length counter etc.

;.DEFINE DEBUG					; don't uncomment this (effects untested)



; ********************** ROM makeup, SNES header ***********************

.MEMORYMAP
	DEFAULTSLOT	0
	SLOTSIZE	$8000
	SLOT 0		$8000
.ENDME



.ROMBANKMAP
	BANKSTOTAL	4
	BANKSIZE	$8000			; ROM banks are 32 KBytes in size
	BANKS		4			; 4 ROM banks = 1Mbit
.ENDRO



.SNESHEADER					; this also calculates ROM checksum & complement
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



.EMPTYFILL		$FF



.BANK 0 SLOT 0
.ORG $7FB0

	.DB		"00"			; new licensee code (likely irrelevant)



; *************************** Vector tables ****************************

.SNESNATIVEVECTOR
	COP		EmptyHandler
	BRK		EmptyHandler
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



.BANK 0 SLOT 0
.ORG 0

.SECTION "EmptyVectors" SEMIFREE

EmptyHandler:
	rti

.ENDS



; **************** Variables, macros, library routines *****************

	.INCLUDE "lib_variables.asm"		; global variables
	.INCLUDE "lib_macros.asm"		; macros



; ******************************* BANK 0 *******************************

.BANK 0 SLOT 0
.ORG 0

.SECTION "FirmwareVersionStrings" FORCE

;STR_Firmware_Title:
	.DB "Unofficial SNES PowerPak "

STR_Firmware_Version:
	.DB "Firmware v"

STR_Firmware_VerNum:
	.DB "3.00"

STR_Firmware_VerNum_End:

	.DB " "

STR_Firmware_Codename:
	.DB "\"MUFASA\"", 0

STR_Firmware_Build:
	.DB "Build #"

STR_Firmware_BuildNum:
	.DB "11317"

STR_Firmware_BuildNum_End:

	.DB 0

;STR_Firmware_Maker:
	.DB $A9, " by www.ManuLoewe.de", 0	; $A9 = copyright symbol

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

PTR_gameName:
	.DW gameName

CONST_Zeroes:
	.DW 0

.ENDS



.SECTION "libs" SEMIFREE

	.INCLUDE "lib_initsnes.inc.asm"		; SNES initialization routines
	.INCLUDE "lib_joypads.inc.asm"		; SNES joypad routines
	.INCLUDE "lib_quicksetup.inc.asm"	; SNES screen setup/Vblank/scrolling routines
	.INCLUDE "lib_sprites.inc.asm"		; SNES sprite setup routines

.ENDS



; -------------------------- main loader code
.SECTION "MainCode" SEMIFREE

	.INCLUDE "main_boot.inc.asm"		; main bootloader code
	.INCLUDE "main_cf_interface.inc.asm"
	.INCLUDE "main_filebrowser.inc.asm"
	.INCLUDE "main_romspc.inc.asm"
	.INCLUDE "main_options.inc.asm"
	.INCLUDE "main_gamegenie.inc.asm"
	.INCLUDE "main_rommapping.inc.asm"
	.INCLUDE "main_sram.inc.asm"
	.INCLUDE "main_settings.inc.asm"
	.INCLUDE "main_theme.inc.asm"		; theme file handler
	.INCLUDE "main_devnote.inc.asm"		; developer's note
	.INCLUDE "main_spcplayer.inc.asm"	; SPC player
	.INCLUDE "main_flasher.inc.asm"
	.INCLUDE "lib_strings.inc.asm"		; text engine

.ENDS



; ******************************* BANK 1 *******************************

.BANK 1 SLOT 0
.ORG 0

.SECTION "CharacterData" FORCE

	.INCLUDE "static_gfxdata.inc.asm"	; sprites, fonts, palettes
	.INCLUDE "static_hdma_tables.inc.asm"
	.INCLUDE "static_font_width_table.inc.asm"

.ENDS



; ******************************* BANK 2 *******************************

.BANK 2 SLOT 0
.ORG 0

.SECTION "SoundStuff" FORCE

	.INCLUDE "lib_spcload.inc.asm"		; SPC loader
	.INCLUDE "lib_snesmod.inc.asm"		; SNESMod
	.INCLUDE "static_sm_spc_alek.inc.asm"	; SPC700 machine code for SnesMod

.ENDS



; ******************************* BANK 3 *******************************

.BANK 3 SLOT 0
.ORG 0

.SECTION "SoundBank" FORCE

SOUNDBANK:

	.INCBIN "soundbnk.bnk"			; music binary data (for developer's note)

.ENDS



; ******************************** EOF *********************************
