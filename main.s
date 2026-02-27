.setcpu "65C02"
.include "lcd.inc"
.include "defs.inc"


.segment "ZEROPAGE"
Dino_Y:     .res 1
Cactus_X:   .res 1
Jump_Timer: .res 1
Prev_Dino_Y:  .res 1
Prev_Cactus_X: .res 1


.segment "CODE"
reset:
  ldx #$ff
  txs

  ; Initialize VIA for LCD and Button Interrupt
  lda #$ff
  sta VIA_DDRB    ; Port B all output (LCD Data)
  lda #%11100000  ; Port A top 3 output (LCD Ctrl), PA0 input (Button)
  sta VIA_DDRA

  ; Setup CA1 Interrupt (Falling edge for button)
  lda #%00000000  
  sta VIA_PCR
  lda #%10000010  ; Enable CA1 interrupt
  sta VIA_IER

  ; Init Variables
  lda #1          ; Start Dino on bottom row
  sta Dino_Y
  sta Prev_Dino_Y
  lda #15         ; Start Cactus at right edge
  sta Cactus_X
  sta Prev_Cactus_X

  cli ; Allow Interrupts
  jsr lcd_init_no_cursor
  jsr load_custom_chars


game_loop:
  jsr update_physics
  jsr draw_frame

  jsr software_delay
  jmp game_loop

game_over:
  jsr lcd_clear
  lda #<game_over_msg
  sta MSG_PTR
  lda #>game_over_msg
  sta MSG_PTR+1
  jsr lcd_print_string
@end:
  jmp @end

;------------------------------------------------------------
;  Subroutines
;------------------------------------------------------------

draw_frame:
  ; Erase previous Dino position
  ldx #1
  ldy Prev_Dino_Y
  jsr lcd_gotoxy
  lda #' '
  jsr lcd_print_char

  ; Erase previous Cactus position
  ldx Prev_Cactus_X
  ldy #1
  jsr lcd_gotoxy
  lda #' '
  jsr lcd_print_char

  ; Draw Dino at current position
  ldx #1
  ldy Dino_Y
  jsr lcd_gotoxy
  lda #$00            ; Custom char 0: Dino
  jsr lcd_print_char

  ; Draw Cactus at current position
  ldx Cactus_X
  ldy #1
  jsr lcd_gotoxy
  lda #$01            ; Custom char 1: Cactus
  jsr lcd_print_char

  ; Save current positions as previous
  lda Dino_Y
  sta Prev_Dino_Y
  lda Cactus_X
  sta Prev_Cactus_X

  rts


update_physics:
  ; check game over
  lda Dino_Y
  beq @not_game_over ; If Dino_Y is 0 -> Jumping
  lda Cactus_X
  cmp #1 ; if cactus is at x:1 (Player Position) -> Game Over
  beq game_over
@not_game_over:

  ;move Cactus left
  dec Cactus_X
  lda Cactus_X
  cmp #$ff
  bne @skip_reset
  lda #15
  sta Cactus_X
@skip_reset:

  ;if is Jumping -> Decrement Jump Timer
  lda Jump_Timer
  bne @set_on_bottom
  sbc #1
  sta Jump_Timer
  jmp @jump_check_done
@set_on_bottom:
  lda #1
  sta Dino_Y
@jump_check_done:
  

  rts

; Load custom characters into LCD CGRAM
; Writes char 0 (Dino) and char 1 (Cactus) sequentially
load_custom_chars:
  lda #$40            ; Set CGRAM address to 0
  jsr lcd_instruction
  ldx #0
@loop:
  lda custom_chars,x
  jsr lcd_print_char
  inx
  cpx #16             ; 2 chars x 8 bytes
  bne @loop
  rts

; Software delay ~100ms (10 FPS) at 1 MHz
; Inner loop: 256 iterations × 5 cycles = ~1280 cycles
; Outer loop: 78 × 1280 ≈ 99840 cycles ≈ 100ms
software_delay:
  ldx #78
  ;ldx #250
@outer:
  ldy #0           ; 0 wraps to 256 iterations
@inner:
  dey
  bne @inner
  dex
  bne @outer
  rts

;------------------------------------------------------------
;  IRQ
;------------------------------------------------------------

irq_handler:
  pha
  phx
  phy

  lda VIA_IFR
  and #%00000010
  beq @exit

  lda Dino_Y
  cmp #1
  bne @clear_flag

  lda #0
  sta Dino_Y
  lda #10
  ;lda #50
  sta Jump_Timer

@clear_flag:
  bit VIA_PORTA
@exit:
  ply
  plx
  pla
  rti

.segment "RODATA"
game_over_msg: .asciiz "   Game Over!   "

; Custom character bitmaps (5x8 pixels, lower 5 bits per row)
; Char 0: Dino (T-Rex facing right)
;  .XXX.  .XXXX  .XX..  XXXX.  .XXX.  ..XX.  .X.X.  .X.X.
custom_chars:
  .byte $0E, $0F, $0C, $1E, $0E, $06, $0A, $0A
; Char 1: Cactus (Saguaro)
;  ..X..  ..X.X  ..XXX  XXX..  X.X..  ..X..  ..X..  .XXX.
  .byte $04, $05, $07, $1C, $14, $04, $04, $0E

.segment "VECTORS"
    .word $0000      ; NMI
    .word reset      ; RESET
    .word irq_handler ; IRQ
