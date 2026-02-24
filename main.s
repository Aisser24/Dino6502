.setcpu "65C02"
.include "lcd.inc"
.include "defs.inc"


.segment "ZEROPAGE"
Dino_Y:     .res 1
Cactus_X:   .res 1
Jump_Timer: .res 1


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
  lda #15         ; Start Cactus at right edge
  sta Cactus_X

  cli ; Allow Interrupts
  jsr lcd_init_no_cursor


game_loop:
  ; Start 50ms Frame Timer (50.000 -> $C350 cycles)
  lda #$50
  sta VIA_T1CL
  lda #$C3
  sta VIA_T1CH

  jsr update_physics
  jsr draw_frame

  ; Sync to 20 FPS
@sync:
  lda VIA_IFR
  and #%01000000
  beq @sync
  lda VIA_T1CL
  jmp game_loop

;------------------------------------------------------------
;  Subroutines
;------------------------------------------------------------

draw_frame:
  jsr lcd_clear
  
  ; Draw Dino
  ldx #$1
  ldy Dino_Y
  jsr lcd_gotoxy
  lda #'D' ; TODO: Add custom Dino Character
  jsr lcd_print_char

  ; Draw Cactus
  ldx Cactus_X
  ldy #1
  jsr lcd_gotoxy
  lda #'k' ; TODO: Add custom cactus Character
  jsr lcd_print_char

  rts


update_physics:
  ldx Cactus_X
  dex
  txa
  sta Cactus_X
  
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
  sta Jump_Timer

@clear_flag:
  bit VIA_PORTA
@exit:
  ply
  plx
  pla
  rti


.segment "VECTORS"
    .word $0000      ; NMI
    .word reset      ; RESET
    .word irq_handler ; IRQ
