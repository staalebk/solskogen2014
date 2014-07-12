; Coding for the trusty 6502
	processor 6502

; Zero page defines:
	SEG.U VARS
	ORG $80
intcount1	ds 1
intcount2	ds 1
scrollbit	ds 1
scrollchr	ds 1
scrollpos   ds 1
iscrollbit	ds 1
iscrollchr	ds 1
iscrollpos  ds 1
counter     ds 1
scene		ds 1

	echo "----",($100 - *) , "bytes of RAM left"
	SEG CODE

; Lets make this stuff autoload address on 4096
	SEG	
	org $0801
	.byte $0c,$08,$0a,$00,$9e,$20,$34,$30,$39,$36,$00,$00,$00
	
; Our entry point
	org $1000
	lda #$00
	tax
	lda #$00
	tay
	lda #$0B
	jsr $BC00

	
	
; clear interrupts
	sei
	lda #$7f
	sta $dc0d	;disable timer interrupts which can be generated by the two CIA chips
	sta $dd0d	;the kernal uses such an interrupt to flash the cursor and scan the keyboard, so we better
				;stop it.	
	lda $dc0d	;by reading this two registers we negate any pending CIA irqs.
	lda $dd0d	;if we don't do this, a pending CIA irq might occur after we finish setting up our irq.
				;we don't want that to happen.
				
	lda #$35	;we turn off the BASIC and KERNAL rom here
	sta $01		;the cpu now sees RAM everywhere except at $d000-$e000, where still the registers of
				;SID/VICII/etc are visible
				
	lda #<irq	;this is how we set up
	sta $fffe	;the address of our interrupt code
	lda #>irq
	sta $ffff
	
	lda #$01   ;this is how to tell the VICII to generate a raster interrupt
	sta $d01a

	lda #$00   ;this is how to tell at which rasterline we want the irq to be triggered
	sta $d012

	lda #$1b   ;as there are more than 256 rasterlines, the topmost bit of $d011 serves as
	sta $d011  ;the 8th bit for the rasterline we want our irq to be triggered.
           ;here we simply set up a character screen, leaving the topmost bit 0.
		   
	lda #$c1   ; set the scroll as far left as possible.
	sta $d016
	sta scrollbit
		   
	lda #$1E	; Set the character map to be @ 0x3800
	sta $d018


;	asl $d019
; zero some stuff
	lda #$00
	sta intcount1
	sta intcount2
	sta scrollchr
	sta scrollpos
	jsr	clearscr
	cli			;enable maskable interrupts again

	jmp *	;we better don't RTS, the ROMS are now switched off, there's no way back to the system


clearscr:	ldx #$00
		lda #$20
clearscrl: sta $0400,x
		sta $0500,x
        sta $0600,x
        sta $0700,x
        dex
        bne clearscrl
	
dark:	lda $d020 ;copy border color into
		sta $d021 ;main area color
		lda #$00
		sta $d020 ; Black border
		sta $d021 ; black main
		
		
		ldx #$00
color:	lda #$02
		sta $d800,x
		sta $d900,x
		sta $da00,x
		sta $db00,x
		inx
		cpx #$00
		bne color
		rts

; First move everything one step to the left
fillr	ldx #$00
.loopr	lda $0479,x
		sta $0478,x
		lda $04A1,x
		sta $04A0,x
		inx
		cpx #$28
		bne .loopr
; Now fill in more juicy stuff on the far right
		lda scrollchr
		cmp #$00
		beq newchar
oldchar	ldx scrollpos
		lda msgz,x
		clc
		adc #$40
		sta $049F
		clc
		adc #$40
		sta $04C7
		lda #$00
		sta scrollchr
		inc scrollpos
		rts
		
newchar	ldx scrollpos
		lda msgz,x
		sta $04C7
		sec
		sbc #$40
		sta $049F
		inc scrollchr
		rts
		
		
		
dscroll	dec scrollbit
;		dec scrollbit  ; Double speed
		lda scrollbit
		cmp #$bf
		bne setsrll
		jsr fillr
		lda #$c7
		sta scrollbit

setsrll sta $d016
		rts








; First move everything one step to the left
ifillr	ldx #$00
.iloopr	lda $0749,x
		sta $0748,x
		lda $0771,x
		sta $0770,x
		inx
		cpx #$28
		bne .iloopr
; Now fill in more juicy stuff on the far right
		lda iscrollchr
		cmp #$00
		beq inewchar
ioldchar	ldx iscrollpos
		lda msgpoo,x
		clc
		adc #$40
		sta $076F
		clc
		adc #$40
		sta $0797
		lda #$00
		sta iscrollchr
		inc iscrollpos
		rts
		
inewchar	ldx iscrollpos
		lda msgpoo,x
		sta $0797
		sec
		sbc #$40
		sta $076F
		inc iscrollchr
		rts
		
		
		
iscroll	dec iscrollbit
		dec iscrollbit  ; Double speed
		lda iscrollbit
		cmp #$bf
		bne isetsrll
		jsr ifillr
		lda #$c7
		sta iscrollbit

isetsrll sta $d016
		rts



irq2	lda #<colourbars	;this is how we set up
		sta $fffe	;the address of our interrupt code
		lda #>colourbars
		sta $ffff
		lda #$D9  ;this is how to tell at which rasterline we want the irq to be triggered
		sta $d012
				jsr iscroll
				asl $d019
				RTI

colourbars  asl $d019               ; acknowledge interrupt	

            lda #00                 ; init raster counter
            sta counter

            ldx index
            ldy counter
            lda delaytable,y
            sbc #01
            bne colourbars+15
            lda colourtable,x      ; set background colour
            sta $d021
            inx
            txa
            and #15
            tax
            iny
            cpy #16
            nop
            bne colourbars+12
resetColour ldy #8                  ; back to black background
            dey
            bne resetColour+2
            ldy #0
            sty $d021

            lda #<update            ; point to next interrupt
            ldx #>update
            sta $fffe
            stx $ffff

            lda #250                ; set trigger line
            sta $d012	
			RTI
			
update      dec smooth              ; apply smoothing to animation
            bne update+20
            lda #03
            sta smooth
            lda index               ; cycle start colour
            adc #01
            and #15
            sta index

            asl $d019               ; acknowledge interrupt


out:		lda #<irq	;this is how we set up
		sta $fffe	;the address of our interrupt code
		lda #>irq
		sta $ffff
		lda #$00   ;this is how to tell at which rasterline we want the irq to be triggered
		sta $d012
		

		
	
        RTI
	;Being all kernal irq handlers switched off we have to do more work by ourselves.
	;When an interrupt happens the CPU will stop what its doing, store the status and return address
	;into the stack, and then jump to the interrupt routine. It will not store other registers, and if
	;we destroy the value of A/X/Y in the interrupt routine, then when returning from the interrupt to
	;what the CPU was doing will lead to unpredictable results (most probably a crash). So we better
	;store those registers, and restore their original value before reentering the code the CPU was
	;interrupted running.

	;If you won't change the value of a register you are safe to not to store / restore its value.
	;However, it's easy to screw up code like that with later modifying it to use another register too
	;and forgetting about storing its state.

	;The method shown here to store the registers is the most orthodox and most failsafe.
irq     STA $02
        LDA $DC0D
        STX $03
        STY $04
;	Stack is now saved, lets party!
;		inc $d020		;  visualize interrupt
		jsr $BC03 ;Play some music
		; Lets see what we should be doing...
;init	lda #$00
;		cmp intcount1
;		bne dscr
;		cmp intcount2
;		bne dscr
		;jsr clearscr
;		jsr draw
		
dscr	lda #$50
		cmp intcount1
		bne prescr
prescr	lda #$00
		cmp intcount2
		;bne timer
		jsr dscroll
		;jsr iscroll
		
timer	inc intcount1
		lda intcount1
		cmp #$00
		bne restore
		inc intcount2
		
		
		
;	Restore stack
;restore	dec $d020	; visualize interrupt	lda #<irq	;this is how we set up
restore		lda #<irq2	;this is how we set up
		sta $fffe	;the address of our interrupt code
		lda #>irq2
		sta $ffff
		lda #$70  ;this is how to tell at which rasterline we want the irq to be triggered
		sta $d012

		LDA #$0F
        STA $D019
        LDY $04
        LDX $03
        LDA $02
        RTI

;msgz .byte "INDIEPOO`PRESENTS``````````EVRY`THING`IS`AWESOME```````````````"
msgz .byte "LOREMIPS`LOREMLIP``````````XXXX`THING`XX`XXXXXXX```````````````"

msgpoo .byte "INDILOL`INDIPOO`INDINO`INDIBAD`INDIBLUE`INDIDOG`INDILAST`INDINOT`INDIPET`INDISICK`INDITHICK`INDIFAT`INDISCHNAPPSED`INDILOW`INDISAD`INDIDONG`INDIITCH`INDIPIG`INDIPEEP`INDICHEAP`INDIBLOW`INDIGOAT`INDIJOKE`INDIPOOR`INDITEAR`INDIJAR`INDICRAP`INDISLIP`INDISPIN``````";`INDIWEEP"
index       .byte 00                ; starting colour index
smooth      .byte 03                
delaytable	.byte $08,$03,$08,$08,$08,$08,$08,$08
            .byte $08,$03,$08,$08,$08,$08,$08,$04
colourtable .byte 13, 03, 14, 04, 06, 04, 14, 13
			.byte 7,10,8,2,9,2,8,10
text        .byte 173, 160, 146, 129, 147, 148, 133, 146 
            .byte 160, 131, 143, 140, 143, 149, 146, 160 
            .byte 131, 153, 131, 140, 133, 160, 155, 151 
            .byte 151, 151, 174, 176, 152, 131, 182, 180 
            .byte 174, 131, 143, 141, 157, 160, 173, 160
            .byte 160, 160, 160, 160, 160, 160, 131, 143
            .byte 140, 143, 149, 146, 160, 147, 144, 140
            .byte 137, 148, 160, 129, 131, 146, 143, 147
            .byte 147, 160, 177, 182, 160, 140, 137, 142
            .byte 133, 147, 160, 160, 160, 160, 160, 160

	org $3800
;	INCBIN "fontbin"
;	org $2000
	INCBIN "flipfont"
	org $BC00
    INCBIN "indiepoo.bin"
	
