;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.10 (CODENAME: "MUFASA")
;   (c) 2019 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: SPC PLAYER ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;	SPC uploader & player routines written by:
;	- blargg (Shay Green <gblargg@gmail.com>)
;	- ikari_01 (further contributions)
;	- necronomfive (further contributions ??)
;
;==========================================================================================



spc700_load:
	php
	phk								; set data bank = program bank (required because spc700_load was relocated to ROM bank 2 for v3.00)
	plb

	Accu8
	Index16

	sei								; Disable NMI & IRQ
	stz	REG_NMITIMEN						; The SPC player code is really timing sensitive ;)
	jsr	InitWRAMBuffer						; buffer parts of SPC dump to avoid timing problems
	jsr	upload_dsp_regs						; Upload S-DSP registers
	jsr	upload_high_ram						; Upload 63.5K of SPC700 ram
	jsr	upload_low_ram						; Upload rest of ram
	jsr	restore_final						; Restore SPC700 state & start execution
	lda	REG_RDNMI						; clear NMI flag
	lda	#$81							; VBlank NMI + Auto Joypad Read
	sta	REG_NMITIMEN						; re-enable VBlank NMI
;	cli								; never mind, PLP restores this
	plp
	rtl



;---------------------------------------
; Uploads DSP registers and some other setup code

upload_dsp_regs:

; ---- Begin upload

	ldy	#$0002
	jsr	spc_begin_upload

; ---- Upload loader

	ldx	#$0000
-	lda.l	loader,x
	jsr	spc_upload_byte
	inx
	cpy	#31							; size of loader
	bne	-

; ---- Upload SP, PC & PSW

	lda.l	audioSP							; SP
	jsr	spc_upload_byte
	lda.l	audioPC+1						; PC 2
	jsr	spc_upload_byte
	lda.l	audioPC							; PC 1
	jsr	spc_upload_byte
	lda.l	audioPSW						; PSW
	jsr	spc_upload_byte

; ---- Upload DSP registers

	ldx	#$0000
-
; initialize FLG and KON ($6c/$4c) to avoid artifacts
	cpx	#$4C
	bne	+
	lda	#$00
	bra	upload_skip_load
+	cpx	#$6C
	bne	+
	lda	#$E0
	bra	upload_skip_load
+	lda.l	spcRegBuffer, x
upload_skip_load:
	jsr	spc_upload_byte
	inx
	cpx	#128
	bne	-

; --- Upload fixed values for $F1-$F3

	ldy	#$00F1
	jsr	spc_next_upload
	lda	#$80							; stop timers
	jsr	spc_upload_byte
	lda	#$6c							; get dspaddr set for later
	jsr	spc_upload_byte
	lda	#$60
	jsr	spc_upload_byte

; ---- Upload $f8-$1ff

	ldy	#$00F8
	jsr	spc_next_upload
	ldx	#$00F8
-	lda.l	spcF8Buffer, x
	jsr	spc_upload_byte
	inx
	cpx	#$200
	bne	-

; ---- Execute loader

	ldy	#$0002
	jsr	spc_execute
	rts

;---------------------------------------

upload_high_ram:
	ldy	#$0002
	jsr	spc_begin_upload

; ---- Upload transfer routine

	ldx	#$0000
-	lda.l	transfer,x
	jsr	spc_upload_byte
	inx
	cpy	#44							; size of transfer routine
	bne	-

	ldx	#$023f							; prepare transfer address

; ---- Execute transfer routine

	ldy	#$0002
	sty	REG_APUIO2
	stz	REG_APUIO1
	lda	REG_APUIO0
	inc	a
	inc	a
	sta	REG_APUIO0
; Wait for acknowledgement
-	cmp	REG_APUIO0
	bne	-

; ---- Burst transfer of 63.5K using custom routine

outer_transfer_loop:
	ldy	#$003f							; 3
inner_transfer_loop:
	lda.l	$7F0000,x						; 5 |
	sta	REG_APUIO0						; 4 |
	lda.l	$7F0040,x						; 5 |
	sta	REG_APUIO1						; 4 |
	lda.l	$7F0080,x						; 5 |
	sta	REG_APUIO2						; 4 |
	lda.l	$7F00C0,x						; 5 |
	sta	REG_APUIO3						; 4 |
	tya								; 2 >> 38 cycles
-	cmp	REG_APUIO3						; 4 |
	bne	-							; 3 |
	dex								; 2 |
	dey								; 2 |
	bpl	inner_transfer_loop					; 3 >> 14 cycles

	rep	#$21							; 3 | // Accu16, clear carry
	txa								; 2 |
	adc	#$140							; 3 |
	tax								; 2 |

	Accu8								; 3 |

	cpx	#$003f							; 3 |
	bne	outer_transfer_loop					; 3 >> 19 cycles

	rts

;---------------------------------------

upload_low_ram:

; ---- Upload $0002-$00EF using IPL

	ldy	#$0002
	jsr	spc_begin_upload
	ldx	#$0002
-	lda.l	spcIPLBuffer, x
	jsr	spc_upload_byte
	inx
	cpx	#$00F0
	bne	-

	rts

;---------------------------------------
; Executes final restoration code

restore_final:
	jsr	start_exec_io						; prepare execution from I/O registers

; ---- Restore first two bytes of RAM

	lda.l	spcRAM1stBytes
	xba
	lda	#$e8							; MOV A,#spcRAM1stBytes
	tax
	jsr	exec_instr
	ldx	#$00C4							; MOV $00,A
	jsr	exec_instr
	lda.l	spcRAM1stBytes+1
	xba
	lda	#$e8							; MOV A,#spcRAM1stBytes+1
	tax
	jsr	exec_instr
	ldx	#$01C4							; MOV $01,A
	jsr	exec_instr

; ---- Restore SP

	lda.l	audioSP
	sec
	sbc	#3
	xba
	lda	#$cd							; MOV X,#audioSP
	tax
	jsr	exec_instr
	ldx	#$bd							; MOV SP,X
	jsr	exec_instr

; ---- Restore X

	lda.l	audioX
	xba
	lda	#$cd							; MOV X,#audioX
	tax
	jsr	exec_instr

; ---- Restore Y

	lda.l	audioY
	xba
	lda	#$8d							; MOV Y,#audioY
	tax
	jsr	exec_instr

; ---- Restore DSP FLG register

	lda.l	spcFLGReg
	xba
	lda	#$e8							; MOV A,#spcFLGReg
	tax
	jsr	exec_instr
	ldx	#$f3C4							; MOV $f3,A -> $f2 has been set-up before by SPC700 loader
	jsr	exec_instr

; ---- wait a bit (the newer S-APU takes its time to ramp up the volume)
	lda	#$10
-	pha
	jsr	WaitABit
	pla
	dec	a
	bne	-

; ---- Restore DSP KON register

	lda	#$4C
	xba
	lda	#$e8							; MOV A,#$4c
	tax
	jsr	exec_instr
	ldx	#$f2C4							; MOV $f2,A
	jsr	exec_instr
	lda.l	spcKONReg
	xba
	lda	#$e8							; MOV A,#spcKONReg
	tax
	jsr	exec_instr
	ldx	#$f3C4							; MOV $f3,A
	jsr	exec_instr

; ---- Restore DSP register address

	lda.l	spcDSPRegAddr
	xba
	lda	#$e8							; MOV A,#spcDSPRegAddr
	tax
	jsr	exec_instr
	ldx	#$f2C4							; MOV dest,A
	jsr	exec_instr

; ---- Restore CONTROL register

	lda.l	spcCONTROLReg
	and	#$CF							; don't clear input ports
	xba
	lda	#$e8							; MOV A,#spcCONTROLReg
	tax
	jsr	exec_instr
	ldx	#$f1C4  						; MOV $F1,A
	jsr	exec_instr

;---- Restore A

	lda.l	audioA
	xba
	lda	#$e8							; MOV A,#audioA
	tax
	jsr	exec_instr

;---- Restore PSW and PC

	ldx	#$7F00							; NOP; RTI
	stx	REG_APUIO0
	lda	#$FC							; Patch loop to execute instruction just written
	sta	REG_APUIO3

;---- restore IO ports $f4 - $f7

	Accu16

	lda.l	spcIOPorts
	tax
	lda.l	spcIOPorts+2
	sta	REG_APUIO2
	stx	REG_APUIO0						; last to avoid overwriting RETI before run

	Accu8

	rts

;---------------------------------------

spc_begin_upload:
	sty	REG_APUIO2						; Set address
	ldy	#$BBAA							; Wait for SPC
-	cpy	REG_APUIO0
	bne	-

	lda	#$CC							; Send acknowledgement
	sta	REG_APUIO1
	sta	REG_APUIO0
-	cmp	REG_APUIO0						; Wait for acknowledgement
	bne	-

	ldy	#0							; Initialize index
	rts

;---------------------------------------

spc_upload_byte:
	sta	REG_APUIO1
	tya								; Signal it's ready
	sta	REG_APUIO0
-	cmp	REG_APUIO0						; Wait for acknowledgement
	bne	-

	iny
	rts

;---------------------------------------

spc_next_upload:
	sty	REG_APUIO2

; Send command
; Special case operation has been fully tested.
	lda	REG_APUIO0
	inc	a
	inc	a
	bne	+
	inc	a
+	sta	REG_APUIO1
	sta	REG_APUIO0

; Wait for acknowledgement
-	cmp	REG_APUIO0
	bne	-

	ldy	#0
	rts

;---------------------------------------

spc_execute:
	sty	REG_APUIO2
	stz	REG_APUIO1
	lda	REG_APUIO0
	inc	a
	inc	a
	sta	REG_APUIO0

; Wait for acknowledgement
-	cmp	REG_APUIO0
	bne	-

	rts

;---------------------------------------

start_exec_io:

; Set execution address
	ldx	#$00F5
	stx	REG_APUIO2
	stz	REG_APUIO1      					; NOP
	ldx	#$FE2F      						; BRA *-2

; Signal to SPC that we're ready
	lda	REG_APUIO0
	inc	a
	inc	a
	sta	REG_APUIO0

; Wait for acknowledgement
-	cmp	REG_APUIO0
	bne	-

; Quickly write branch
	stx	REG_APUIO2
	rts

;---------------------------------------

exec_instr:

; Replace instruction
	stx	REG_APUIO0
	lda	#$FC
	sta	REG_APUIO3      					; 30

        ; SPC BRA loop takes 4 cycles, so it reads
        ; the branch offset every 4 SPC cycles (84 master).
        ; We must handle the case where it read just before
        ; the write above, and when it reads just after it.
        ; If it reads just after, we have at least 7 SPC
        ; cycles (147 master) to change restore the branch
        ; offset.

        ; 48 minimum, 90 maximum
        ora	#0
        ora	#0
        ora	#0
        nop
        nop
        nop

        ; 66 delay, about the middle of the above limits
	phd ;4
	pld ;5

        ; Give plenty of extra time if single execution
        ; isn't needed, as this avoids such tight timing
        ; requirements.

	phd ;4
	pld ;5
	phd ;4
	pld ;5

        ; Patch loop to skip first two bytes
	lda	#$FE        	; 16
	sta	REG_APUIO3      ; 30

        ; 38 minimum (assuming 66 delay above)
	phd ; 4
	pld ; 5

        ; Give plenty of extra time if single execution
        ; isn't needed, as this avoids such tight timing
        ; requirements.

	phd
	pld
	phd
	pld
	rts



; ***************************** Wait a bit *****************************

; based on a routine written by ikari_01

WaitABit:
-	lda	REG_HVBJOY
	and	#%10000000						; Vblank period flag
	bne	-

-	lda	REG_HVBJOY
	and	#%10000000
	beq	-

	rts



; ************************* Build WRAM buffer **************************

; WRAM buffering (added by ManuLöwe) to avoid having to fiddle around
; with the PowerPak DMA port within the SPC uploading routine itself,
; which would break the timing.

InitWRAMBuffer:

; copy DSP registers to buffer

	lda	#$91
	sta	DMAWRITEBANK
	lda	#$01
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITELO
	ldx	#$0000
-	lda	DMAREADDATA						; reminder: DMAREADDATA auto-increments
	sta	spcRegBuffer, x
	inx
	cpx	#$0080
	bne	-

; copy $f8-$1ff to buffer

	lda	#$90
	sta	DMAWRITEBANK
	lda	#$01
	sta	DMAWRITEHI
	lda	#$F8
	sta	DMAWRITELO
	ldx	#$00F8
-	lda	DMAREADDATA
	sta	spcF8Buffer, x
	inx
	cpx	#$0200
	bne	-

; copy $0002-$00EF (IPL) to buffer

;	lda	#$90
;	sta	DMAWRITEBANK
	lda	#$01
	sta	DMAWRITEHI
	lda	#$02
	sta	DMAWRITELO
	ldx	#$0002
-	lda	DMAREADDATA
	sta	spcIPLBuffer, x
	inx
	cpx	#$00F0
	bne	-

; copy SPC RAM data to buffer

	ldx	#$0000
;	lda	#$90
;	sta	DMAWRITEBANK
	lda	#$01							; SPC RAM data starts at XX 01 00 (where XX = bank no.)
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITELO
-	lda	DMAREADDATA
	sta	$7F0000, x
	inx
	bne	-							; copy 65536 bytes

	rts



; ********************* Init APU RAM (by ikari_01) *********************

apu_ram_init:
	phk								; set data bank = program bank
	plb
	ldy	#$0002
	jsr	spc_begin_upload
	ldx	#$0000
-	lda.w	apu_ram_init_code, x
	jsr	spc_upload_byte
	inx
	cpx	#apu_ram_init_code_END-apu_ram_init_code
	bne	-

	ldx	#$0002
	stx	REG_APUIO2
	stz	REG_APUIO1
	lda	REG_APUIO0
	inc	a
	inc	a
	sta	REG_APUIO0
-	cmp	REG_APUIO0
	bne	-

	rtl



; **************************** SPC700 code *****************************

; All SPC700 routines in SPC700 machine code below this line
; SPC loader & transfer routines by Shay Green <gblargg@gmail.com>
; APU RAM init code by ikari_01

loader:				; .org $0002
	.byt $F8,$21		;	mov x,@loader_data
	.byt $BD		;	mov sp,x
	.byt $CD,$22		;	mov x,#@loader_data+1

	; Push PC and PSW from SPC header
	.byt $BF		;	mov a,(x)+
	.byt $2D		;	push a
	.byt $BF		;	mov a,(x)+
	.byt $2D		;	push a
	.byt $BF		;	mov a,(x)+
	.byt $2D		;	push a

	; Set FLG to $60 rather than value from SPC
	.byt $E8,$60		;	mov a,#$60
	.byt $D4,$6C		;	mov FLG+x,a

	; Restore DSP registers
	.byt $8D,$00		;	mov y,#0
	.byt $BF		; next:	mov a,(x)+
	.byt $CB,$F2		;	mov $F2,y
	.byt $C4,$F3		;	mov $F3,a
	.byt $FC		;	inc	y
	.byt $10,-8		;	bpl next

	.byt $8F,$6C,$F2	;	mov $F2,#FLG			; set for later

	; Rerun loader
	.byt $5F,$C0,$FF	;	jmp $FFC0

;---------------------------------------

transfer:			; .org $0002

	.byt $CD,$FE		; mov x,#$FE				; transfer 254 pages

	; Transfer four-byte chunks
	.byt $8D,$3F		; page: mov y,#$3F
	.byt $E4,$F4		; quad: mov a,$F4
	.byt $D6,$00,$02	; mov0: mov !$0200+y,a
	.byt $E4,$F5		;	mov a,$F5
	.byt $D6,$40,$02	; mov1: mov !$0240+y,a
	.byt $E4,$F6		;	mov a,$F6
	.byt $D6,$80,$02	; mov2: mov !$0280+y,a
	.byt $E4,$F7		;	mov a,$F7			; tell S-CPU we're ready for more
	.byt $CB,$F7		;	mov $F7,Y
	.byt $D6,$C0,$02	; mov3: mov !$02C0+y,a
	.byt $00		;  nop					; give some time for S-CPU HDMA / WRAM refresh
	.byt $DC 		;	dec	y
	.byt $10,-26		;	bpl quad
	; Increment MSBs of addresses
	.byt $AB,$0A		;	inc	mov0+2
	.byt $AB,$0F		;	inc	mov1+2
	.byt $AB,$14		;	inc	mov2+2
	.byt $AB,$1B		;	inc	mov3+2
	.byt $1D    		;	dec	x
	.byt $D0,-39		;	bne	page
	; Rerun loader
	.byt $5F,$C0,$FF	;	jmp $FFC0



apu_ram_init_code:  ; .org $0002
	; part1: fill $0100-$03ff with #$aa
	.byt $e8,$aa      ; mov a, #$aa
	.byt $8d,$00      ; mov y, #$00
	.byt $cd,$03      ; mov x, #$03
	; loop:
	.byt $d6,$00,$01  ; mov !$0100+y, a
	.byt $fc          ; inc y
	.byt $d0,-6       ; bne loop
	.byt $ab,$0a      ; inc loop+2
	.byt $1d          ; dec x
	.byt $d0,-11      ; bne loop
	; part2: zero $0400-$ffff
	.byt $e8,$00      ; mov a, #$00
	.byt $cd,$fc      ; mov x, #$fc
	; loop2:
	.byt $d6,$00,$04  ; mov !$0400+y, a
	.byt $fc          ; inc y
	.byt $d0,-6       ; bne loop2
	.byt $ab,$19      ; inc loop2+2
	.byt $1d          ; dec x
	.byt $d0,-11      ; bne loop2
	; Re-run IPL
	.byt $5f,$c0,$ff ; jmp $ffc0

apu_ram_init_code_END:



; ******************************** EOF *********************************
