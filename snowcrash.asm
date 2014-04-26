	processor 6502

	org $1000

;	sei
	ldx #$00
	lda #$20
clearscr: sta $0400,x
		sta $0500,x
        sta $0600,x
        sta $0700,x
        dex
        bne clearscr
		
	lda #$01
loop:	sta $d021
		sta $d020
		eor #$1
		jmp loop
		
		
