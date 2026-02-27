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
  lda #%00000000  ; T1 one-shot mode, no latching
  sta VIA_ACR
  lda #%01111111  ; Disable all VIA interrupts (using polling)
  sta VIA_IER

  ; Init Variables
  lda #1          ; Start Dino on bottom row
  sta Dino_Y
  sta Prev_Dino_Y
  lda #15         ; Start Cactus at right edge
  sta Cactus_X
  sta Prev_Cactus_X
  lda #0
  sta Jump_Timer

  ; Interrupts stay disabled — button is polled via IFR
  jsr lcd_init_no_cursor
  jsr load_custom_chars
  jsr lcd_clear


game_loop:
  ; Poll button (CA1 flag set on falling edge regardless of IER)
  lda VIA_IFR
  and #%00000010
  beq @no_press
  bit VIA_PORTA       ; Clear CA1 flag
  lda Dino_Y
  cmp #1
  bne @no_press       ; Ignore if already jumping
  lda #0
  sta Dino_Y
  lda #5
  sta Jump_Timer
@no_press:
  jsr update_physics
  jsr draw_frame

  ; Software delay ~200ms at 1MHz
  ; Inner: 256 * 5 = 1280 cycles, Outer: 156 * 1286 ≈ 200k cycles
  ldy #156
@delay_outer:
  ldx #0
@delay_inner:
  dex
  bne @delay_inner
  dey
  bne @delay_outer

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
  beq @set_on_bottom
  dec Jump_Timer
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


;------------------------------------------------------------
;  IRQ
;------------------------------------------------------------

irq_handler:
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
