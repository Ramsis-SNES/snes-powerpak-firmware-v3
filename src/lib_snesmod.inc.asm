;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** SNESMOD ***
;
;==========================================================================================



;----------------------------------------------------------------------
;
;	SNESMod from CC65 to WLA DX! By KungFuFurby.
;	Original SNESMod by mukunda
;	Conversion Started: 3/9/12, Last update: 3/9/12 Reason: First attempt.
;	Adapted by Alekmaul for pvsneslib
;	Further modified for SNES PowerPak firmware by ManuLöwe
;
;	This software is provided 'as-is', without any express or implied
;	warranty.  In no event will the authors be held liable for any
;	damages arising from the use of this software.
;
;	Permission is granted to anyone to use this software for any
;	purpose, including commercial applications, and to alter it and
;	redistribute it freely, subject to the following restrictions:
;
;	1.	The origin of this software must not be misrepresented; you
;		must not claim that you wrote the original software. If you use
;		this software in a product, an acknowledgment in the product
;		documentation would be appreciated but is not required.
;	2.	Altered source versions must be plainly marked as such, and
;		must not be misrepresented as being the original software.
;	3.	This notice may not be removed or altered from any source
;		distribution.
;
;----------------------------------------------------------------------



; *************************** Local defines ****************************

;----------------------------------------------------------------------
; soundbank defs
;----------------------------------------------------------------------

	.DEFINE SB_SAMPCOUNT	$8000
	.DEFINE SB_MODCOUNT	$8002
	.DEFINE SB_MODTABLE	$8004
	.DEFINE SB_SRCTABLE	$8184

;----------------------------------------------------------------------
; spc commands
;----------------------------------------------------------------------

	.DEFINE CMD_LOAD	$00
	.DEFINE CMD_LOADE	$01
	.DEFINE CMD_VOL		$02
	.DEFINE CMD_PLAY	$03
	.DEFINE CMD_STOP	$04
	.DEFINE CMD_MVOL	$05
	.DEFINE CMD_FADE	$06
	.DEFINE CMD_RES		$07
	.DEFINE CMD_FX		$08
	.DEFINE CMD_TEST	$09
	.DEFINE CMD_SSIZE	$0A

;----------------------------------------------------------------------

; process for 5 scanlines

	.DEFINE PROCESS_TIME	5
	.DEFINE INIT_DATACOPY	13

	.DEFINE SPC_BOOT	$0400		; spc entry/load address

;----------------------------------------------------------------------

.INDEX 16
.ACCU 8

;**********************************************************************
;* upload driver
;*
;* disable time consuming interrupts during this function
;**********************************************************************
spcBoot:			
;----------------------------------------------------------------------

-	ldx	REG_APUIO0	; wait for 'ready signal from SPC
	cpx	#$BBAA		;
	bne	-		;--------------------------------------
	stx	REG_APUIO1	; start transfer:
	ldx	#SPC_BOOT	; port1 = !0
	stx	REG_APUIO2	; port2,3 = transfer address
	lda	#$CC		; port0 = 0CCh
	sta	REG_APUIO0	;--------------------------------------

	WaitForAPUIO0


;----------------------------------------------------------------------
; ready to transfer
;----------------------------------------------------------------------
	lda.l	SM_SPC		; read first byte
	xba			;
	lda	#0		;
	ldx	#1		;
	bra	sb_start	;
;----------------------------------------------------------------------
; transfer data
;----------------------------------------------------------------------
sb_send:
;----------------------------------------------------------------------
	xba			; swap DATA into A
	lda.l	SM_SPC, x	; read next byte
	inx			; swap DATA into B
	xba			;--------------------------------------

	WaitForAPUIO0

	inc	a			; increment counter (port0 data)
;----------------------------------------------------------------------
sb_start:
;----------------------------------------------------------------------
	rep	#A_8BIT			; write port0+port1 data
	sta	REG_APUIO0		;
	sep	#A_8BIT			;--------------------------------------
	cpx	#SM_SPC_end-SM_SPC	; loop until all bytes transferred
	bcc	sb_send			;
;----------------------------------------------------------------------
; all bytes transferred
;----------------------------------------------------------------------

	WaitForAPUIO0

	inc	a			; add 2 or so...
	inc	a			;--------------------------------------
				; mask data so invalid 80h message wont get sent
	stz	REG_APUIO1	; port1=0
	ldx	#SPC_BOOT	; port2,3 = entry point
	stx	REG_APUIO2	;
	sta	REG_APUIO0	; write P0 data
				;--------------------------------------

	WaitForAPUIO0		; final sync

	stz	REG_APUIO0
	
	stz	spc_v		; reset V
	stz	spc_q		; reset Q
	stz	spc_fwrite		; reset command fifo
	stz	spc_fread		;
	stz	spc_sfx_next	;
	
	stz	spc_pr+0
	stz	spc_pr+1
	stz	spc_pr+2
	stz	spc_pr+3

	stz	spc_ptr+0
	stz	spc_ptr+1
	stz	spc_ptr+2
	stz	spc_bank

	stz	spc1+0
	stz	spc1+1
	stz	spc2+0
	stz	spc2+1

	stz	digi_src+0
	stz	digi_src+1
	stz	digi_src+2
	stz	digi_src2+0
	stz	digi_src2+1
	stz	digi_src2+2

	stz	SoundTable+0
	stz	SoundTable+1
	stz	SoundTable+2

	stz	spc_sfx_next

	stz	digi_init
	stz	digi_pitch
	stz	digi_vp
	stz	digi_remain+0
	stz	digi_remain+1
	stz	digi_active
	stz	digi_copyrate

	ldx	#$0
	lda	#$0
-	sta	spc_fifo,x
	inx
	cpx	#$ff
	bne	-

;----------------------------------------------------------------------
; driver installation successful
;----------------------------------------------------------------------
	rtl
;----------------------------------------------------------------------

;**********************************************************************
; upload module to spc
;
; x = module_id
; modifies, a,b,x,y
;
; this function takes a while to execute
;**********************************************************************
spcLoad:
;----------------------------------------------------------------------

;	Accu16

;	lda	6,s		; module_id
;	tax

;	Accu8

	phx			; flush fifo!
	jsr	xspcFlush	;
	plx			;
	
	phx
	ldy	#SB_MODTABLE
	sty	spc2
	jsr	get_address
	rep	#A_8BIT
	lda	[spc_ptr], y	; X = MODULE SIZE
	tax
	
	incptr
	
	lda	[spc_ptr], y	; read SOURCE LIST SIZE
	
	incptr
	
	sty	spc1		; pointer += listsize*2
	asl	a		;
	adc	spc1		;

	bmi	+		;
	ora	#$8000		;

	inc	spc_ptr+2	;
+	tay			;
	
	sep	#A_8BIT		;
	lda	spc_v		; wait for spc
	pha			;

	WaitForAPUIO1

	lda	#CMD_LOAD	; send LOAD message
	sta	REG_APUIO0	;
	pla			;
	eor	#$80		;
	ora	#$01		;
	sta	spc_v		;
	sta	REG_APUIO1	;------------------------------

	WaitForAPUIO1

	jsr	do_transfer
	
;------------------------------------------------------
; transfer sources
;------------------------------------------------------
	
	plx
	ldy	#SB_MODTABLE
	sty	spc2
	jsr	get_address

	incptr
	
	rep	#A_8BIT		; x = number of sources
	lda	[spc_ptr], y	;
	tax			;
	
	incptr
	
transfer_sources:
	lda	[spc_ptr], y	; read source index
	sta	spc1		;
	
	incptr
	
	phy			; push memory pointer
	sep	#A_8BIT		; and counter
	lda	spc_ptr+2	;
	pha			;
	phx			;
	
	jsr	transfer_source
	
	plx			; pull memory pointer
	pla			; and counter
	sta	spc_ptr+2	;
	ply			;
	
	dex
	bne	transfer_sources

__no_more_sources:
	stz	REG_APUIO0	; end transfers
	lda	spc_v		;
	eor	#$80		;
	sta	spc_v		;
	sta	REG_APUIO1	;-----------------

	WaitForAPUIO1

	sta	spc_pr+1
	stz	spc_sfx_next	; reset sfx counter
	rtl

;--------------------------------------------------------------
; spc1 = source index
;--------------------------------------------------------------
transfer_source:
;--------------------------------------------------------------

	ldx	spc1
	ldy	#SB_SRCTABLE
	sty	spc2
	jsr	get_address
	
	lda	#$01		; port0=01h
	sta	REG_APUIO0	;
	rep	#A_8BIT		; x = length (bytes->words)
	lda	[spc_ptr], y	;
	incptr			;
	inc	a		;
	lsr	a		;
	tax			;
	lda	[spc_ptr], y	; port2,3 = loop point
	sta	REG_APUIO2
	incptr
	sep	#A_8BIT
	
	lda	spc_v		; send message
	eor	#$80		;	
	ora	#$01		;
	sta	spc_v		;
	sta	REG_APUIO1	;-----------------------

	WaitForAPUIO1

	cpx	#0
	beq	end_transfer	; if datalen != 0
	bra	do_transfer	; transfer source data
	
;--------------------------------------------------------------
; spc_ptr+y: source address
; x = length of transfer (WORDS)
;--------------------------------------------------------------
transfer_again:
	eor	#$80		;
	sta	REG_APUIO1	;
	sta	spc_v		;

	incptr			;

	WaitForAPUIO1

;--------------------------------------------------------------
do_transfer:
;--------------------------------------------------------------

	rep	#A_8BIT		; transfer 1 word
	lda	[spc_ptr], y	;
	sta	REG_APUIO2	;
	sep	#A_8BIT		;
	lda	spc_v		;
	dex			;
	bne	transfer_again	;
	
	incptr

end_transfer:
	lda	#0		; final word was transferred
	sta	REG_APUIO1	; write p1=0 to terminate
	sta	spc_v		;

	WaitForAPUIO1

	sta	spc_pr+1
	rts

;--------------------------------------------------------------
; spc2 = table offset
; x = index
;
; returns: spc_ptr = 0,0,bank, Y = address
get_address:
;--------------------------------------------------------------

	lda	spc_bank	; spc_ptr = bank:SB_MODTABLE+module_id*3
	sta	spc_ptr+2	;
	rep	#A_8BIT		;
	stx	spc1		;
	txa			;
	asl	a		;
	adc	spc1		;
	adc	spc2		;
	sta	spc_ptr		;
	
	lda	[spc_ptr]	; read address
	pha			;
	sep	#A_8BIT		;
	ldy	#2		;
	lda	[spc_ptr],y	; read bank#
	
	clc			; spc_ptr = long address to module
	adc	spc_bank	;
	sta	spc_ptr+2	;
	ply			;
	stz	spc_ptr
	stz	spc_ptr+1
	rts
	
	
;**********************************************************************
; a = id
; spc1 = params
;**********************************************************************
QueueMessage:
	sei				; disable IRQ in case user 
					; has spcProcess in irq handler

	sep	#XY_8BIT		; queue data in fifo
	ldx	spc_fwrite		;
	sta	spc_fifo, x		;
	inx				;
	lda	spc1			;
	sta	spc_fifo, x		;
	inx				;
	lda	spc1+1			;
	sta	spc_fifo, x		;
	inx				;
	stx	spc_fwrite		;
	rep	#XY_8BIT		;
	cli				;
	rtl

;**********************************************************************
; flush fifo (force sync)
;**********************************************************************
spcFlush:
;----------------------------------------------------------------------

spcFlush1:
	lda	spc_fread		; call spcProcess until
	cmp	spc_fwrite		; fifo becomes empty
	beq	__exit			;
	jsr	spcProcessMessages	;
	bra	spcFlush1		;

;----------------------------------------------------------------------
xspcFlush:
;----------------------------------------------------------------------
	lda	spc_fread		; call spcProcess until
	cmp	spc_fwrite		; fifo becomes empty
	beq	__exit			;
	jsr	xspcProcessMessages	;
	bra	xspcFlush		;
__exit:
	rts
	
xspcProcessMessages:
	sep	#XY_8BIT		; 8-bit index during this function
	lda	spc_fwrite		; exit if fifo is empty
	cmp	spc_fread		;
	beq	__xexit2			;------------------------------
	ldy	#PROCESS_TIME		; y = process time
;----------------------------------------------------------------------
__xprocess_again:
;----------------------------------------------------------------------
	lda	spc_v			; test if spc is ready
	cmp	REG_APUIO1		;
	bne	__xnext			; no: decrement time
					;------------------------------
	ldx	spc_fread		; copy message arguments
	lda	spc_fifo, x		; and update fifo read pos
	sta	REG_APUIO0		;
	sta	spc_pr+0
	inx				;
	lda	spc_fifo, x		;
	sta	REG_APUIO2		;
	sta	spc_pr+2
	inx				;
	lda	spc_fifo, x		;
	sta	REG_APUIO3		;
	sta	spc_pr+3
	inx				;
	stx	spc_fread		;------------------------------
	lda	spc_v			; dispatch message
	eor	#$80			;
	sta	spc_v			;
	sta	REG_APUIO1		;------------------------------
	sta	spc_pr+1
	lda	spc_fread		; exit if fifo has become empty
	cmp	spc_fwrite		;
	beq	__xexit2			;
;----------------------------------------------------------------------
__xnext:
;----------------------------------------------------------------------
	lda	REG_SLHV		; latch H/V and test for change
	lda	REG_OPVCT		;------------------------------
	cmp	spc1			; we will loop until the VCOUNT
	beq	__xprocess_again		; changes Y times
	sta	spc1			;
	dey				;
	bne	__xprocess_again		;
;----------------------------------------------------------------------
__xexit2:
;----------------------------------------------------------------------
	rep	#XY_8BIT		; restore 16-bit index
	rts

;**********************************************************************
; process spc messages for x time
;**********************************************************************
spcProcess:
;----------------------------------------------------------------------

	php
	
	lda	digi_active
	beq	spcProcessMessages
	jsr	spcProcessStream

spcProcessMessages:
	sep	#XY_8BIT		; 8-bit index during this function
	lda	spc_fwrite		; exit if fifo is empty
	cmp	spc_fread		;
	beq	__exit2			;------------------------------
	ldy	#PROCESS_TIME		; y = process time
;----------------------------------------------------------------------
__process_again:
;----------------------------------------------------------------------
	lda	spc_v			; test if spc is ready
	cmp	REG_APUIO1		;
	bne	__next			; no: decrement time
					;------------------------------
	ldx	spc_fread		; copy message arguments
	lda	spc_fifo, x		; and update fifo read pos
	sta	REG_APUIO0		;
	sta	spc_pr+0
	inx				;
	lda	spc_fifo, x		;
	sta	REG_APUIO2		;
	sta	spc_pr+2
	inx				;
	lda	spc_fifo, x		;
	sta	REG_APUIO3		;
	sta	spc_pr+3
	inx				;
	stx	spc_fread		;------------------------------
	lda	spc_v			; dispatch message
	eor	#$80			;
	sta	spc_v			;
	sta	REG_APUIO1		;------------------------------
	sta	spc_pr+1
	lda	spc_fread		; exit if fifo has become empty
	cmp	spc_fwrite		;
	beq	__exit2			;
;----------------------------------------------------------------------
__next:
;----------------------------------------------------------------------
	lda	REG_SLHV		; latch H/V and test for change
	lda	REG_OPVCT		;------------------------------
	cmp	spc1			; we will loop until the VCOUNT
	beq	__process_again		; changes Y times
	sta	spc1			;
	dey				;
	bne	__process_again		;
;----------------------------------------------------------------------
__exit2:
;----------------------------------------------------------------------
	plp				; restore processor status
	rtl
	
;**********************************************************************
; x = starting position
;**********************************************************************
spcPlay:
;----------------------------------------------------------------------

;	lda	6,s	; module_id
	
;	txa				; queue message: 
	sta	spc1+1			; id -- xx

	lda	#CMD_PLAY		;

	jmp	QueueMessage		;
	
spcStop:
	lda	#CMD_STOP

	jmp	QueueMessage

;-------test function-----------;
spcTest:			;#
	php			;#
	lda	spc_v		;#
-	cmp.l	REG_APUIO1	;#
	bne	-		;#
	xba			;#
	lda	#CMD_TEST	;#
	sta.l	REG_APUIO0	;#
	xba			;#
	eor	#$80		;#
	sta	spc_v		;#
	sta.l	REG_APUIO1	;#
	plp			;#
	rts			;#
;--------------------------------#
; ################################

;**********************************************************************
; read status register
;**********************************************************************
spcReadStatus:
	ldx	#5			; read PORT2 with stability checks
	lda	REG_APUIO2		; 
__loop:					;
	cmp	REG_APUIO2		;
	bne	spcReadStatus		;
	dex				;
	bne	__loop			;
	rts
	
;**********************************************************************
; read position register
;**********************************************************************
spcReadPosition:
	ldx	#5			; read PORT3 with stability checks
	lda	REG_APUIO2		;
__loop2:					;
	cmp	REG_APUIO2		;
	bne	spcReadPosition		;
	dex				;
	bne	__loop2			;
	rts

;**********************************************************************
spcGetCues:
;**********************************************************************
	lda	spc_q
	sta	spc1
	jsr	spcReadStatus
	and	#$0F
	sta	spc_q
	sec
	sbc	spc1
	bcs	+
	adc	#16
+
	rts

;**********************************************************************
; x = volume
;**********************************************************************
spcSetModuleVolume:
;**********************************************************************

;	lda	6,s	; volume
	
;	txa				;queue:
	sta	spc1+1			; id -- vv

	lda	#CMD_MVOL		;

	jmp	QueueMessage		;

;**********************************************************************
; x = target volume
; y = speed
;**********************************************************************
spcFadeModuleVolume:
;**********************************************************************

;	Accu16

;	lda	6,s	; speed
;	tay
;	lda	8,s	; target volume
;	tax

;	Accu8
	
	txa				;queue:
	sta	spc1+1			; id xx yy
	tya				;
	sta	spc1			;
	lda	#CMD_FADE
	jmp	QueueMessage



;======================================================================
spcAllocateSoundRegion:
;======================================================================
; a = size of buffer
;----------------------------------------------------------------------

;	lda	6,s	; size of buffer
	pha				; flush command queue
	jsr	xspcFlush		;
					;
	lda	spc_v			; wait for spc

	WaitForAPUIO1

;----------------------------------------------------------------------
	pla				; set parameter
	sta	REG_APUIO3		;
;----------------------------------------------------------------------
	lda	#CMD_SSIZE		; set command
	sta	REG_APUIO0		;
	sta	spc_pr+0		;
;----------------------------------------------------------------------
	lda	spc_v			; send message
	eor	#128			;
	sta	REG_APUIO1		;
	sta	spc_v			;
	sta	spc_pr+1		;
;----------------------------------------------------------------------
	rtl

	
;============================================================================
spcProcessStream:
;============================================================================
	rep	#A_8BIT			; test if there is data to copy
	lda	digi_remain		;
	bne	+			;
	sep	#A_8BIT			;
	stz	digi_active		;
	rts

+	sep	#A_8BIT			;
;-----------------------------------------------------------------------
	lda	spc_pr+0		; send STREAM signal
	ora	#128			;
	sta	REG_APUIO0		;
;-----------------------------------------------------------------------
-	bit	REG_APUIO0		; wait for SPC
	bpl	-			;
;-----------------------------------------------------------------------
	stz	REG_APUIO1		; if digi_init then:
	lda	digi_init		;   clear digi_init
	beq	__no_init		;   set newnote flag
	stz	digi_init		;   copy vp
	lda	digi_vp			;   copy pan
	sta	REG_APUIO2		;   copy pitch
	lda	digi_pitch		;
	sta	REG_APUIO3		;
	lda	#1			;
	sta	REG_APUIO1		;
	lda	digi_copyrate		; copy additional data
	clc				;
	adc	#INIT_DATACOPY		;
	bra	__newnote		;
__no_init:				;
;-----------------------------------------------------------------------
	lda	digi_copyrate		; get copy rate
__newnote:
	rep	#A_8BIT			; saturate against remaining length
	and	#$FF			; 
	cmp	digi_remain		;
	bcc	__nsatcopy		;
	lda	digi_remain		;
	stz	digi_remain		;
	bra	__copysat		;
__nsatcopy:				;
;-----------------------------------------------------------------------
	pha				; subtract amount from remaining
	sec				;
	sbc	digi_remain		;
	eor	#$FFFF			;
	inc	a			;
	sta	digi_remain		;
	pla				;
__copysat:				;
;-----------------------------------------------------------------------
	sep	#A_8BIT			; send copy amount
	sta	REG_APUIO0		;
;-----------------------------------------------------------------------
	sep	#XY_8BIT		; spc1 = nn*3 (amount of tribytes to copy)
	tax				; x = vbyte
	sta	spc1			;
	asl	a			;
	clc				;
	adc	spc1			;
	sta	spc1			;
	ldy	#0			;
;-----------------------------------------------------------------------


__next_block:
	lda	[digi_src2], y
	sta	spc2
	rep	#A_8BIT			; read 2 bytes
	lda	[digi_src], y		;
-	cpx	REG_APUIO0		;-sync with spc
	bne	-			;
	inx				; increment v
	sta	REG_APUIO2		; write 2 bytes
	sep	#A_8BIT			;
	lda	spc2			; copy third byte
	sta	REG_APUIO1		;
	stx	REG_APUIO0		; send data
	iny				; increment pointer
	iny				;
	iny				;
	dec	spc1			; decrement block counter
	bne	__next_block		;
;-----------------------------------------------------------------------
-	cpx	REG_APUIO0		; wait for spc
	bne	-			;
;-----------------------------------------------------------------------
	lda	spc_pr+0		; restore port data
	sta	REG_APUIO0		;
	lda	spc_pr+1		;
	sta	REG_APUIO1		;
	lda	spc_pr+2		;
	sta	REG_APUIO2		;
	lda	spc_pr+3		;
	sta	REG_APUIO3		;
;-----------------------------------------------------------------------
	tya				; add offset to source
	rep	#$31			;
	and	#255			;
	adc	digi_src		;
	sta	digi_src		;
	inc	a			;
	inc	a			;
	sta	digi_src2		;
	sep	#A_8BIT			;
;-----------------------------------------------------------------------
	rts
	


; ******************************** EOF *********************************
