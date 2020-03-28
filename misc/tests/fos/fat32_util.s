;-----------------------------------------------------------------------------
; fat32_util.s
;-----------------------------------------------------------------------------

        .include "fat32_util.inc"
	.include "lib.inc"
	.include "fat32.inc"
	.include "text_display.inc"

;-----------------------------------------------------------------------------
; Variables
;-----------------------------------------------------------------------------
	.bss

	.code

;-----------------------------------------------------------------------------
; print_dirent
;-----------------------------------------------------------------------------
.proc print_dirent
	; Print file name
	ldx #0
:	lda fat32_dirent + dirent::name, x
	beq :+
	jsr putchar
	inx
	bne :-
:
	; Pad spaces
:	cpx #13
	beq :+
	inx
	lda #' '
	jsr putchar
	bra :-
:
	; Print attributes
	lda fat32_dirent + dirent::attributes
	bit #$10
	bne dir

	; Print size
	copy_bytes val32, fat32_dirent + dirent::size, 4
	lda #' '
	sta padch
	jsr print_val32

	bra cluster

dir:	ldy #0
:	lda dirstr, y
	beq :+
	jsr putchar
	iny
	bra :-
:
cluster:
.if 0
	; Spacing
	lda #' '
	jsr putchar

	; Print cluster
	; copy_bytes val32, fat32_dirent + dirent::cluster, 4
	; lda #0
	; sta padch
	; jsr print_val32

	ldx #3
:	lda fat32_dirent + dirent::cluster, x
	jsr puthex
	dex
	cpx #$FF
	bne :-
.endif

	; New line
	lda #10
	jsr putchar

	rts

dirstr: .byte "<DIR>     ", 0
.endproc