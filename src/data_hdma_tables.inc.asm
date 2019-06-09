;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** HDMA TABLES ***
;
;==========================================================================================



; N.B. The placeholder table for the background color gradient is built on the fly in the screen/GFX setup routine.



; ***************************** Color math *****************************

; Adds some color to the SPC player "window". Color values are taken
; from theme file data.
; (Scanline numbers differ from the scroll table below because the color
; is only meant to fill the inside of the "window" (without border),
; whereas the scroll table includes the whole 8-scanline-wide "window"
; border tiles.)

HDMA_ColMath:
	.DB 52		; +0 patchme					; for 52 (+1 ??) scanlines (patched for questions "windows" in main_sram.inc.asm),
	.DB $E0, $E0							; apply black (i.e., don't affect display)

	.DB 126		; +3 patchme					; for 126 scanlines (inside of SPC player "window" sans border / also patched in main_sram.inc.asm),
	.DB $FF, $FF	; +4/+5 patchme					; apply color (patched with theme file data --> HDMAtable.ColorMath+4/+5)

	.DB 1								; for the remaining scanlines,
	.DB $E0, $E0							; don't affect display
	.DB 0



; *************************** Scroll offsets ***************************

; Ensures the SPC player "window" is centered vertically, and allows
; its content to be placed on the upper 32×32 tilemap so the lower one
; (containing the directory listing) remains intact.

HDMA_Scroll:
	.DB $2F								; for 47 (+1 ??) scanlines,
	.DB $00, $00							; no horizontal scroll offset
	.DB $00, $00	; +3 patchme scrollY

	.DB $80								; for $80 + $08 = 136 scanlines (size of SPC player "window"),
	.DB $00, $01							; horizontal scroll offset = $0100 (upper 32×32 tile map)
	.DB $00, $00	; v-scroll = 0
	.DB $08
	.DB $00, $01
	.DB $00, $00	; v-scroll = 0

	.DB $29								; for the remaining scanlines,
	.DB $00, $00							; no horizontal scroll offset
	.DB $00, $00	; +18 patchme scrollY
	.DB 0



; ***************************** Windowing ******************************

; HDMA window masking suppresses "scrolling artifact" lines in the file-
; browser. This table is used for both mainscreen and subscreen, hence
; two data bytes per unit.

HDMA_Window:
	.DB $0F								; for 15 (+1 ??) scanlines,
	.DB $03, $03							; enable window masking

	.DB $80								; for $80 + $40 = 192 scanlines ...
	.DB $00, $00
	.DB $40
	.DB $00, $00							; ... disable window masking (i. e., show content)

	.DB $11								; for the remaining scanlines,
	.DB $03, $03							; enable window masking
	.DB 0

HDMA_Window_End:



; ******************************** EOF *********************************
