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


loop:
  


irq_handler:
  rti


.segment "VECTORS"
    .word $0000      ; NMI
    .word reset      ; RESET
    .word irq_handler ; IRQ
