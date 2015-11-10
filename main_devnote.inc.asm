;==========================================================================================
;
;   UNOFFICIAL SNES POWERPAK FIRMWARE V3.00 (CODENAME: "MUFASA")
;   (c) 2012-2015 by ManuLöwe (http://www.manuloewe.de/)
;
;	*** DEVELOPER'S NOTE ***
;
;==========================================================================================



GotoDevNote:
	sep #A_8BIT				; 8 bit Accumulator, 16 bit X/Y
	rep #XY_8BIT

	jsr ClearSpriteText			; remove "Loading ..." message



; -------------------------- clear upper 32×32 tilemap in case the SPC player was used
	rep #A_8BIT				; A = 16 bit

	lda #$4040				; overwrite 2 tiles at once ($40 = space)
	ldx #$0400				; start at upper 32×32 tilemap

-	sta TextBuffer.BG1, x
	sta TextBuffer.BG2, x
	inx
	inx
	cpx #$0800				; 1024 bytes
	bne -

	sep #A_8BIT				; A = 8 bit



; -------------------------- start music
	lda #$00
	jsl spcPlay

	lda #224
	jsl spcSetModuleVolume



; -------------------------- wall of text
 	SetCursorPos 1, 0			; "page" 1 in lower 32×32 tilemap

	PrintString "Greetings, fellow SNES gamer! :-)\n\n"
	PrintString "Thank you so much for downloading and installing my\n"
	PrintString "unofficial firmware for the SNES PowerPak.\n\n"
	PrintString "Just like you, I've been a huge fan of this awesome\n"
	PrintString "flash cartridge ever since it was released in late 2009.\n"
	PrintString "Thanks to the PowerPak, I discovered a whole new level\n"
	PrintString "of SNES gaming, much like when I got my first SWC DX2\n"
	PrintString "as a teenager, back in the late 1990s. What's more, it\n"
	PrintString "got me into SNES programming in the summer of 2012,\n"
	PrintString "when I realized that if I wanted a state-of-the-art\n"
	PrintString "menu software, I would have to make it myself. ;-)\n\n"
	PrintString "From the first v2.0-beta1 release to this very day,\n"
	PrintString "my motivation to improve both performance and usability\n"
	PrintString "of the SNES PowerPak has never left me. So naturally ..."

	SetCursorPos 21, 2
	PrintString " Cont."

	SetCursorPos 21, 10
	PrintString "Exit"

	SetCursorPos 23, 4
	PrintString "Start/stop music"

 	SetCursorPos 1+32, 0			; "page" 2 in upper 32×32 tilemap

	PrintString "I'm proud to say that v3 \"MUFASA\" takes your SNES\n"
	PrintString "PowerPak to yet another dimension. :D Not only is this\n"
	PrintString "a faster and snappier firmware than ever before, but it\n"
	PrintString "also lets you customize its visuals to your very own\n"
	PrintString "liking: Choose from no less than five themes supplied\n"
	PrintString "within this firmware package--be it bleak and desolate,\n"
	PrintString "just like the original manufacturer's design, or a\n"
	PrintString "colorful homage to your favorite platformer. Or, and\n"
	PrintString "this is even better, create your own individual theme\n"
	PrintString "to enjoy and share with the community of SNES gamers\n"
	PrintString "all around the globe (for details see How To Use.txt)!\n\n"
	PrintString "Thanks for reading. Now, pick a game and play! :-)"

	SetCursorPos 15+32, 0
	PrintString "Long live the SNES PowerPak!\n\n"
	PrintString "(c) 2012-2015 by Ramsis\nhttp://www.manuloewe.de/"

	SetCursorPos 21+32, 2
	PrintString " Back"

	SetCursorPos 21+32, 10
	PrintString "Exit"

	SetCursorPos 23+32, 4
	PrintString "Start/stop music"



; -------------------------- show mosaic effect
	lda #$93				; enable mosaic on BG1 & BG2, start with block size 9

-	sta $2106
	wai					; show mosaic for one frame
	sec
	sbc #$10				; reduce block size by 1
	cmp #$F3				; smallest block size ($03) processed on last iteration?
	bne -

	stz $2106				; turn off mosaic effect



; -------------------------- show button hints
	rep #A_8BIT				; A = 16 bit

	lda #$B014				; Y, X
	sta SpriteBuf1.Buttons

	lda #$03A0				; tile properties, tile num for A button
	sta SpriteBuf1.Buttons+2

	lda #$C014				; Y, X
	sta SpriteBuf1.Buttons+4

	lda #$03A2				; tile properties, tile num for B button
	sta SpriteBuf1.Buttons+6

	lda #$C020				; Y, X
	sta SpriteBuf1.Buttons+8

	lda #$03A4				; tile properties, tile num for Y button
	sta SpriteBuf1.Buttons+10

	lda #$B04E				; Y, X
	sta SpriteBuf1.Buttons+12

	lda #$03AC				; tile properties, tile num for Start button highlighted
	sta SpriteBuf1.Buttons+14

	sep #A_8BIT				; A = 8 bit

	lda #$01				; page 1
	sta temp+7

	stz Joy1New				; reset input buttons
	stz Joy1New+1
	stz Joy1Press
	stz Joy1Press+1



; -------------------------- dev's note loop
DevNoteLoop:
	jsl spcProcess

	wai



; -------------------------- check for A button = toggle "page" switching
	lda Joy1New
	and #%10000000
	beq ++

	lda temp+7				; what page are we on?
	cmp #$01
	beq +

	lda #$01				; set page = 1
	sta temp+7
	jsr GotoDevNotePage1
	bra ++

+	inc temp+7				; set page = 2
	jsr GotoDevNotePage2

++



; -------------------------- check for B button = (re-)start music
	lda Joy1New+1
	and #%10000000
	beq +

	lda #$00
	jsl spcPlay

	lda #224
	jsl spcSetModuleVolume

+



; -------------------------- check for Y button = fade out music
	lda Joy1New+1
	and #%01000000
	beq +

	jsr FadeOutMusic

+



; -------------------------- check for Start button = reset to intro
	lda Joy1Press+1
	and #%00010000
	beq DevNoteLoop



; -------------------------- Start pressed, reset
	lda #$0E				; reduce screen brightness by 1
	sta $2100

	lda #224

-	wai

	sec					; fade out music within 224/8 = 28 frames (~ 0.5 seconds)
	sbc #8
	pha

	jsl spcSetModuleVolume
	jsl spcProcess

	pla

	pha					; make the screen fade to black at the same time

	lsr a					; volume / 16 = screen brightness :-)
	lsr a
	lsr a
	lsr a

	sta $2100

	pla
	bne -

	jsl spcStop
	jsl spcProcess

	wai

	lda #%10000001
	sta CONFIGWRITESTATUS			; reset PowerPak, stay in boot mode



; ************************** "Page" switching **************************

GotoDevNotePage1:



; -------------------------- hide PowerPak logo sprites
	rep #A_8BIT				; A = 16 bit

	lda #$F0F0
	ldx #$0000

-	sta SpriteBuf1.PowerPakLogo, x
	inx
	inx
	inx
	inx
	cpx #$0040				; 16 tiles
	bne -

	sep #A_8BIT				; A = 8 bit



; -------------------------- horizontal scroll effect to the left
	lda #$00

-	sec
	sbc #$10
	sta $210D
	stz $210D
	sta $210F
	stz $210F

	wai

	cmp #$00
	bne -

	stz $210D
	stz $210D
	stz $210F
	stz $210F
rts



GotoDevNotePage2:



; -------------------------- horizontal scroll effect to the right
	lda #$00

-	clc
	adc #$10
	sta $210D
	stz $210D
	sta $210F
	stz $210F

	wai

	cmp #$F0
	bne -

	lda #$01
	stz $210D
	sta $210D
	stz $210F
	sta $210F



; -------------------------- Show PowerPak logo sprites
	rep #A_8BIT				; A = 16 bit

	lda #$889A				; Y, X
	sta temp

	lda #$05C0				; tile properties, tile num
	sta temp+2

	ldx #$0000

-	lda temp
	sta SpriteBuf1.PowerPakLogo, x
	clc
	adc #$0010				; X += 16
	sta temp
	inx
	inx

	lda temp+2
	sta SpriteBuf1.PowerPakLogo, x
	clc
	adc #$0002				; tile num += 2
	sta temp+2
	inx
	inx

	bit #$0006				; check if last 3 bits of tile num clear = one row of 4 (large) sprites done?
	bne -					; "inner" loop

	lda temp
	and #$FF9A				; reset X = $9A
	clc
	adc #$1000				; Y += 16
	sta temp

	cpx #$0020				; after 8 (large) sprites, advance tile num by 16
	bne +

	lda temp+2
	clc
	adc #$0010				; tile num += 16 (i.e., skip one row of 8*8 tiles)
	sta temp+2

+	cpx #$0040				; 64 / 4 = 16 (large) sprites done?
	bne -					; "outer" loop

	sep #A_8BIT				; A = 8 bit
rts



; *************************** Misc. effects ****************************

FadeOutMusic:
	lda #224

-	wai
	sec					; fade out music within 224/8 = 28 frames (~ 0.5 seconds)
	sbc #8
	pha

	jsl spcSetModuleVolume

	jsl spcProcess

	pla
	bne -

	jsl spcStop

	jsl spcProcess

	wai
rts



; ******************************** EOF *********************************
