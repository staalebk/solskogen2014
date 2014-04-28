; Coding for the trusty 6502
	processor 6502

; Zero page defines:
	SEG.U VARS
	ORG $80
SomeVariableName	ds 1
TwoByteVariableName	ds 2
YetAnotherVariable	ds 1
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
	jsr $C357
	
	
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
		   
	lda #$1E	; Set the character map to be @ 0x3800
	sta $d018


;	asl $d019
	cli			;enable maskable interrupts again

	jmp init	;we better don't RTS, the ROMS are now switched off, there's no way back to the system


init:	ldx #$00
		lda #$20
clearscr: sta $0400,x
		sta $0500,x
        sta $0600,x
        sta $0700,x
        dex
        bne clearscr
	
dark:	lda $d020 ;copy border color into
		sta $d021 ;main area color
		
		ldx #$00
color:	lda #$02
		sta $d800,x
		sta $d900,x
		sta $da00,x
		inx
		cpx #$FF
		bne color
		
		ldx #$00
		ldy #$00
darkl	lda msgz,x
		sta $0428,y
		sec
		sbc #$40
		sta $0400,y
		iny
		clc
		adc #$80
		sta $0400,y
		clc
		adc #$40
		sta $0428,y
		inx
		iny
		cpx #$13
		bne darkl
		
loop:	jmp loop

		
static:	lda #$01
staticl:	sta $d021
		nop
		nop
		sta $d020
		eor #$1
		jmp staticl
		
		


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
 ;      (your code here)

;		lda $d020
;		eor #$1
;		sta $d020
		jsr $BDE4 ;Play some music
;		End my code

        LDA #$01
        STA $D019
        LDY $04
        LDX $03
        LDA $02
        RTI

msgd .byte "DARKLITE`PRESENTS`"
msgz .byte "ZOMGTRONICS`PRESENTS`"

	org $3800
	INCBIN "fontbin"
	org $BC00-$7E
    INCBIN "Delta.sid"