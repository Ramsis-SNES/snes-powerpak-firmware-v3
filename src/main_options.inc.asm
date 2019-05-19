;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.01 (CODENAME: "MUFASA")
;   (c) 2018 by ManuLöwe (https://manuloewe.de/)
;
;	*** MAIN CODE SECTION: GAME OPTIONS ***
;	Code in this file based on v1.0X code written by:
;	- bunnyboy (SNES PowerPak creator), (c) 2009
;
;==========================================================================================



.ACCU 8
.INDEX 16

GotoGameOptions:
	lda	#$D5
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$40
	sta	DMAWRITEBANK						; destroy header $40FFC0
	lda	#$00
	sta	DMAREADDATA
	lda	#$D5
	sta	DMAWRITELO
	lda	#$FF
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK						; destroy header $FFC0
	lda	#$00
	sta	DMAREADDATA
	lda	#$D5
	sta	DMAWRITELO
	lda	#$7F
	sta	DMAWRITEHI
	lda	#$00
	sta	DMAWRITEBANK						; destroy header $7FC0
	lda	#$00
	sta	DMAREADDATA
;	lda	#%00000011						; batt used, bootmode
;	sta	CONFIGWRITESTATUS
	wai
	jsr	PrintClearScreen

	DrawFrame 1, 2, 30, 7
	PrintSpriteText 3, mainSelX+2, "Play this game:", 3

	Accu16

	ldy	#$0000
-	lda	gameName, y						; copy game name to tempEntry for printing
	sta	tempEntry, y
	iny
	iny
	cpy	#$0038							; only copy 56 characters
	bne	-

	Accu8

	SetTextPos 2, 1

	jsr	PrintTempEntry

	lda	#cursorYPlayLoop					; put cursor on "Play" line
	sta	cursorY
	lda	#cursorXstart
	sta	cursorX

	PrintSpriteText 6, mainSelX+2, "Load savegame ...", 3

	Accu16

	ldy	#$0000
-	lda	saveName, y						; copy save name to tempEntry for printing
	sta	tempEntry, y
	iny
	iny
	cpy	#$0038							; only copy 56 characters
	bne	-

	Accu8

	SetTextPos 5, 1

	jsr	PrintTempEntry

	DrawFrame 2, 9, 27, 12
	SetTextPos 8, mainSelX
	PrintString "Load GameGenie code list ..."

	jsr	PrintGGCodes

	SetTextPos 8, mainSelX+18
	PrintString "Clear codes!"

	jsr	ShowHelpGeneral

	stz	Joy1New							; reset input buttons
	stz	Joy1New+1
	stz	Joy1Press
	stz	Joy1Press+1



; **************************** "Play" loop *****************************

PlayLoop:
	wai



; -------------------------- check for A/Start button = start game
	lda	Joy1New
	bmi	+
	lda	Joy1New+1						; check for Start button = ditto
	and	#%00010000
	beq	@AStartButtonsDone
+	jmp	StartGame

@AStartButtonsDone:



; -------------------------- check for B button = return to titlescreen
	lda	Joy1New+1
	bpl	@BButtonDone
	jmp	BackToIntro

@BButtonDone:



; -------------------------- check for d-pad up
	lda	Joy1New+1
	and	#%00001000
	beq	@DpadUpDone
	lda	#cursorYGGcode5						; up pressed, switch to GG code editing loop
	sta	cursorY
	lda	#cursorXcodes
	sta	cursorX
	jsr	ShowHelpGGcodeEdit
	jmp	EditGGCodeLoop

@DpadUpDone:



; -------------------------- check for d-pad down
	lda	Joy1New+1
	and	#%00000100
	beq	@DpadDownDone
	lda	#cursorYSRAMLoop					; down pressed, switch to save RAM loop
	sta	cursorY
	bra	SaveRAMLoop

@DpadDownDone:



; -------------------------- check for Select button = show decoded GG codes
	lda	Joy1Press+1
	and	#%00100000
	beq	+							; if Select is released, clear decoded GG code lines
	jsr	SelectPressed
	bra	@SelButtonDone

+	jsr	SelectReleased

@SelButtonDone:

	bra	PlayLoop



; ***************************** SRAM loop ******************************

SaveRAMLoop:
	wai



; -------------------------- check for A button = launch SRAM browser
	lda	Joy1New
	bpl	@AButtonDone
	jsr	SpriteMessageLoading
	jsr	InitSRMBrowser						; go to SRAM browser
	jmp	GotoGameOptions						; refresh game options screen

@AButtonDone:



; -------------------------- check for Start button = start game
	lda	Joy1New+1
	and	#%00010000
	beq	@StartButtonDone
	jmp	StartGame

@StartButtonDone:



; -------------------------- check for B button = return to titlescreen
	lda	Joy1New+1
	bpl	@BButtonDone
	jmp	BackToIntro

@BButtonDone:



; -------------------------- check for d-pad up
	lda	Joy1New+1
	and	#%00001000
	beq	@DpadUpDone
	lda	#cursorYPlayLoop					; up pressed, switch to play loop
	sta	cursorY
	jmp	PlayLoop

@DpadUpDone:



; -------------------------- check for d-pad down
	lda	Joy1New+1
	and	#%00000100
	beq	@DpadDownDone
	lda	#cursorYLoadGGLoop					; down pressed, switch to GG TXT file loop
	sta	cursorY
	bra	LoadGGCodeLoop

@DpadDownDone:



; -------------------------- check for Select button = show decoded GG codes
	lda	Joy1Press+1
	and	#%00100000
	beq	+							; if Select is released, clear decoded GG code lines
	jsr	SelectPressed
	bra	@SelButtonDone
+	jsr	SelectReleased

@SelButtonDone:
	jmp	SaveRAMLoop



; ************************* Load GG codes loop *************************

LoadGGCodeLoop:
	wai



; -------------------------- check for A button
	lda	Joy1New
	bpl	@AButtonDone

+	lda	cursorX							; check where the cursor is at
	cmp	#cursorXstart
	beq	+
	jsr	GameGenieClearAll					; clear out all GG codes
	jsr	PrintGGCodes						; refresh code display
	bra	@AButtonDone

+	jsr	SpriteMessageLoading
	jsr	InitTXTBrowser						; go to GameGenie TXT browser
	jmp	GotoGameOptions						; refresh game options screen

@AButtonDone:



; -------------------------- check for Start button = start game
	lda	Joy1New+1
	and	#%00010000
	beq	@StartButtonDone
	jmp	StartGame

@StartButtonDone:



; -------------------------- check for B button = return to titlescreen
	lda	Joy1New+1
	and	#%10000000
	beq	@BButtonDone
	jmp	BackToIntro

@BButtonDone:



; -------------------------- check for d-pad up
	lda	Joy1New+1
	and	#%00001000
	beq	@DpadUpDone
	lda	#cursorYSRAMLoop					; up pressed, switch to SRAM loop
	sta	cursorY
	lda	#cursorXstart						; reset cursorX position
	sta	cursorX
	jmp	SaveRAMLoop

@DpadUpDone:



; -------------------------- check for d-pad down
	lda	Joy1New+1
	and	#%00000100
	beq	@DpadDownDone
	lda	#cursorYGGcode1						; down pressed, switch to GG code editing loop
	sta	cursorY
	lda	#cursorXcodes
	sta	cursorX
	jsr	ShowHelpGGcodeEdit
	bra	EditGGCodeLoop

@DpadDownDone:



; -------------------------- check for d-pad right
	lda	Joy1+1
	and	#%00000001
	beq	@DpadRightDone
	lda	#cursorXstart+$90
	sta	cursorX

@DpadRightDone:



; -------------------------- check for d-pad left
	lda	Joy1+1
	and	#%00000010
	beq	@DpadLeftDone
	lda	#cursorXstart
	sta	cursorX

@DpadLeftDone:



; -------------------------- check for Select = show decoded GG codes
	lda	Joy1Press+1
	and	#%00100000
	beq	+							; if Select is released, clear decoded GG code lines
	jsr	SelectPressed
	bra	@SelButtonDone

+	jsr	SelectReleased

@SelButtonDone:
	jmp	LoadGGCodeLoop



; ************************* Edit GG codes loop *************************

EditGGCodeLoop:
	wai



; -------------------------- check for A/X buttons = increase value
	lda	Joy1Press
	and	#%11000000
	beq	@AXButtonsDone

@AXPressed:
	jsr	GGCodeIncChar

	lda	Joy1Old
	and	#%11000000
	bne	@AXHeld
	ldx	#$000E							; 14 frames
-	wai
	lda	Joy1
	and	#%11000000
	beq	@AXButtonsDone
	dex
	bne	-

	bra	@AXPressed

@AXHeld:
	ldx	#$0003							; 3 frames
-	wai
	lda	Joy1
	and	#%11000000
	beq	@AXButtonsDone
	dex
	bne	-

	bra	@AXPressed

@AXButtonsDone:



; -------------------------- check for B/Y buttons = decrease value
	lda	Joy1Press+1
	and	#%11000000
	beq	@BYButtonsDone

@BYPressed:
	jsr	GGCodeDecChar

	lda	Joy1Old+1
	and	#%11000000
	bne	@BYHeld
	ldx	#$000E							; 14 frames
-	wai
	lda	Joy1+1
	and	#%11000000
	beq	@BYButtonsDone
	dex
	bne	-

	bra	@BYPressed

@BYHeld:
	ldx	#$0003							; 3 frames
-	wai
	lda	Joy1+1
	and	#%11000000
	beq	@BYButtonsDone
	dex
	bne	-

	bra	@BYPressed

@BYButtonsDone:



; -------------------------- check for Start button = start game
	lda	Joy1New+1
	and	#%00010000
	beq	@StartButtonDone
	jmp	StartGame

@StartButtonDone:



; -------------------------- check for Select button = show decoded GG codes
	lda	Joy1Press+1
	and	#%00100000
	beq	+							; if Select is released, clear decoded GG code lines
	jsr	SelectPressed
	bra	@SelButtonDone

+	jsr	SelectReleased

@SelButtonDone:



; -------------------------- check for d-pad up
	lda	Joy1New+1
	and	#%00001000
	beq	@DpadUpDone
	lda	cursorY
	cmp	#cursorYGGcode2
	bcs	+
	lda	#cursorYLoadGGLoop					; at code 1, switch to load GG code loop
	sta	cursorY
	lda	#cursorXstart						; reset cursorX position
	sta	cursorX
	jsr	ShowHelpGeneral
	jmp	LoadGGCodeLoop

+	sec
	sbc	#$10
	sta	cursorY

@DpadUpDone:



; -------------------------- check for d-pad down
	lda	Joy1New+1
	and	#%00000100
	beq	@DpadDownDone
	lda	cursorY
	cmp	#cursorYGGcode5
	bcc	+
	lda	#cursorYPlayLoop					; at code 5, switch to "Play" loop
	sta	cursorY
	lda	#cursorXstart						; reset cursorX position
	sta	cursorX
	jsr	ShowHelpGeneral
	jmp	PlayLoop

+	clc
	adc	#$10
	sta	cursorY

@DpadDownDone:



; -------------------------- check for d-pad left = move cursor left
	lda	Joy1Press+1
	and	#%00000010
	beq	@DpadLeftDone

@LeftPressed:
	lda	cursorX
	cmp	#cursorXcodes						; if at leftmost digit ...
	bne	+
	lda	#cursorXcodes+$70					; ... go to rightmost digit
	sta	cursorX
	bra	++

+	sec								; otherwise, cursorX = cursorX - $10
	lda	cursorX
	sbc	#$10
	sta	cursorX
++	lda	Joy1Old+1
	and	#%00000010
	bne	@LeftHeld
	ldx	#$000E							; 14 frames
-	wai
	lda	Joy1+1
	and	#%00000010
	beq	@DpadLeftDone
	dex
	bne	-

	bra	@LeftPressed

@LeftHeld:
	ldx	#$0004							; 4 frames
-	wai
	lda	Joy1+1
	and	#%00000010
	beq	@DpadLeftDone
	dex
	bne	-

	bra	@LeftPressed

@DpadLeftDone:



; -------------------------- check for d-pad right = move cursor right
	lda	Joy1Press+1						; check for d-pad right
	and	#%00000001
	beq	@DpadRightDone

@RightPressed:
	lda	cursorX
	cmp	#cursorXcodes+$70					; if at rightmost digit ...
	bne	+
	lda	#cursorXcodes						; ... go to leftmost digit
	sta	cursorX
	bra	++

+	clc								; otherwise, cursorX = cursorX + $10
	lda	cursorX
	adc	#$10
	sta	cursorX
++	lda	Joy1Old+1
	and	#%00000001
	bne	@RightHeld
	ldx	#$000E							; 14 frames
-	wai
	lda	Joy1+1
	and	#%00000001
	beq	@DpadRightDone
	dex
	bne	-

	bra	@RightPressed

@RightHeld:
	ldx	#$0004							; 4 frames
-	wai
	lda	Joy1+1
	and	#%00000001
	beq	@DpadRightDone
	dex
	bne	-

	bra	@RightPressed

@DpadRightDone:



; -------------------------- check for L+R button = clear out current GG code
	lda	Joy1Press
	and	#%00110000
	cmp	#%00110000
	bne	@LRButtonsDone
	jsr	GGClearCurrentCode
	jsr	PrintGGCodes						; refresh code display

@LRButtonsDone:

	jmp	EditGGCodeLoop



; **************************** Subroutines *****************************



; -------------------------- display GG codes / do misc. screen updates
SelectPressed:								; print decoded GG codes
	SetTextPos GGcode1Y, GGcodesX+17

	ldy	#$0000
	jsr	GameGenieDecode

	SetTextPos GGcode2Y, GGcodesX+17

	ldy	#$0008
	jsr	GameGenieDecode

	SetTextPos GGcode3Y, GGcodesX+17

	ldy	#$0010
	jsr	GameGenieDecode

	SetTextPos GGcode4Y, GGcodesX+17

	ldy	#$0018
	jsr	GameGenieDecode

	SetTextPos GGcode5Y, GGcodesX+17

	ldy	#$0020
	jsr	GameGenieDecode

	rts



SelectReleased:
	SetTextPos GGcode1Y, GGcodesX+17

	jsr	SelectReleased2

	SetTextPos GGcode2Y, GGcodesX+17

	jsr	SelectReleased2

	SetTextPos GGcode3Y, GGcodesX+17

	jsr	SelectReleased2

	SetTextPos GGcode4Y, GGcodesX+17

	jsr	SelectReleased2

	SetTextPos GGcode5Y, GGcodesX+17

	jsr	SelectReleased2

	rts



SelectReleased2:
	PrintString "             "

	rts



; -------------------------- print saved / entered / cleared out codes
PrintGGCodes:
	SetTextPos GGcode1Y, GGcodesX

	ldy	#$0000
	jsr	GameGeniePrint

	SetTextPos GGcode2Y, GGcodesX

	ldy	#$0008
	jsr	GameGeniePrint

	SetTextPos GGcode3Y, GGcodesX

	ldy	#$0010
	jsr	GameGeniePrint

	SetTextPos GGcode4Y, GGcodesX

	ldy	#$0018
	jsr	GameGeniePrint

	SetTextPos GGcode5Y, GGcodesX

	ldy	#$0020
	jsr	GameGeniePrint

	rts



GGClearCurrentCode:
	lda	cursorY
	cmp	#cursorYGGcode1
	bne	+
	ldy	#$0000							; code 1
	bra	@GGClearCurrentCodeDone

+	cmp	#cursorYGGcode2
	bne	+
	ldy	#$0008							; code 2
	bra	@GGClearCurrentCodeDone

+	cmp	#cursorYGGcode3
	bne	+
	ldy	#$0010							; code 3
	bra	@GGClearCurrentCodeDone

+	cmp	#cursorYGGcode4
	bne	+
	ldy	#$0018							; code 4
	bra	@GGClearCurrentCodeDone

+	; cmp	#cursorYGGcode5
;	bne	+
	ldy	#$0020							; code 5

@GGClearCurrentCodeDone:
	jsr	GameGenieClearCode					; clear out current GG code

	rts



GGCodeIncChar:
	lda	cursorY
	cmp	#cursorYGGcode1
	bne	+

	SetTextPos GGcode1Y, GGcodesX

	ldy	#$0000							; store code 1 char
	bra	@GGCodeIncCharDone

+	cmp	#cursorYGGcode2
	bne	+

	SetTextPos GGcode2Y, GGcodesX

	ldy	#$0008							; store code 2 char
	bra	@GGCodeIncCharDone

+	cmp	#cursorYGGcode3
	bne	+

	SetTextPos GGcode3Y, GGcodesX

	ldy	#$0010							; store code 3 char
	bra	@GGCodeIncCharDone

+	cmp	#cursorYGGcode4
	bne	+

	SetTextPos GGcode4Y, GGcodesX

	ldy	#$0018							; store code 4 char
	bra	@GGCodeIncCharDone

+	; cmp	#cursorYGGcode5
;	bne	+

	SetTextPos GGcode5Y, GGcodesX

	ldy	#$0020							; store code 5 char

@GGCodeIncCharDone:
	jsr	GameGenieGetOffset
	jsr	GameGenieNextChar					; save GG code changes

	rts



GGCodeDecChar:
	lda	cursorY
	cmp	#cursorYGGcode1
	bne	+

	SetTextPos GGcode1Y, GGcodesX

	ldy	#$0000							; store code 1 char
	bra	@GGCodeDecCharDone

+	cmp	#cursorYGGcode2
	bne	+

	SetTextPos GGcode2Y, GGcodesX

	ldy	#$0008							; store code 2 char
	bra	@GGCodeDecCharDone

+	cmp	#cursorYGGcode3
	bne	+

	SetTextPos GGcode3Y, GGcodesX

	ldy	#$0010							; store code 3 char
	bra	@GGCodeDecCharDone

+	cmp	#cursorYGGcode4
	bne	+

	SetTextPos GGcode4Y, GGcodesX

	ldy	#$0018							; store code 4 char
	bra	@GGCodeDecCharDone

+	; cmp	#cursorYGGcode5
;	bne	+

	SetTextPos GGcode5Y, GGcodesX

	ldy	#$0020							; store code 5 char

@GGCodeDecCharDone:
	jsr	GameGenieGetOffset
	jsr	GameGeniePrevChar					; save GG code changes

	rts



GameGenieGetOffset:							; look up code/character to be changed, depending on cursor pos.
	lda	cursorY
	sec
	sbc	#cursorYGGcode1
	lsr	a
	sta	temp							; game genie 0,8,16,24,32
	lda	cursorX
	sec
	sbc	#cursorXcodes
	lsr	a
	lsr	a
	lsr	a
	lsr	a							; char 0..7
	clc
	adc	temp
	sta	GameGenie.CharOffset
	stz	GameGenie.CharOffset+1
	rts



PrintTempEntry:
	stz	tempEntry+56						; NUL-terminate entry string after 56 characters
	ldy	#PTR_tempEntry

	PrintString "%s"

	rts



BackToIntro:
	jsr	HideButtonSprites
	jsr	PrintClearScreen
	jmp	GotoIntroScreen



; **************************** Button hints ****************************

ShowHelpGeneral:
	ClearLine 21
	SetTextPos 21, 2
	PrintString " Accept\t\tBack"
	SetTextPos 23, 6
	PrintString " Launch game\t      Decode GG codes"



; -------------------------- show button hints
	Accu16

	lda	#$B014							; Y, X
	sta	SpriteBuf1.Buttons
	lda	#$03A0							; tile properties, tile num for A button
	sta	SpriteBuf1.Buttons+2
	lda	#$F0F0							; Y, X (off-screen)
	sta	SpriteBuf1.Buttons+4
	lda	#$03A6							; tile properties, tile num for X button
	sta	SpriteBuf1.Buttons+6
	lda	#$B050							; Y, X
	sta	SpriteBuf1.Buttons+8
	lda	#$03A2							; tile properties, tile num for B button
	sta	SpriteBuf1.Buttons+10
	lda	#$F0F0							; Y, X (off-screen)
	sta	SpriteBuf1.Buttons+12
	lda	#$03A4							; tile properties, tile num for Y button
	sta	SpriteBuf1.Buttons+14
	lda	#$C030							; Y, X
	sta	SpriteBuf1.Buttons+16
	lda	#$03AC							; tile properties, tile num for Start button highlighted
	sta	SpriteBuf1.Buttons+18
	lda	#$C084							; Y, X
	sta	SpriteBuf1.Buttons+20
	lda	#$03AE							; tile properties, tile num for Select button highlighted
	sta	SpriteBuf1.Buttons+22

	Accu8

	rts



ShowHelpGGcodeEdit:
	ClearLine 21
	SetTextPos 21, 4
	PrintString "+Digit\t   -Digit     L+R: Clear this code"

	Accu16

	lda	#$B020							; Y, X for X button
	sta	SpriteBuf1.Buttons+4
	lda	#$B05C							; Y, X for Y button
	sta	SpriteBuf1.Buttons+12

	Accu8

	rts



; ******************************** EOF *********************************
