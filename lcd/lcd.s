.include "defs.inc"

.export lcd_instruction
.export lcd_print_char
.export lcd_clear
.export lcd_init_no_cursor
.export lcd_gotoxy

E  = %10000000 
RW = %01000000 
RS = %00100000

.segment "CODE"

lcd_instruction:
  jsr lcd_wait
  sta VIA_PORTB         ; Put command on bus
  lda #0            ; RS=0 (Instruction)
  sta VIA_PORTA
  lda #E            ; Pulse E high
  sta VIA_PORTA
  lda #0            ; Pulse E low
  sta VIA_PORTA
  rts

lcd_print_char:
  jsr lcd_wait
  sta VIA_PORTB         ; Put ASCII char on bus
  lda #RS           ; RS=1 (Data)
  sta VIA_PORTA
  lda #(RS | E)     ; RS=1 + Pulse E high
  sta VIA_PORTA
  lda #RS           ; RS=1 + Pulse E low
  sta VIA_PORTA
  rts

lcd_wait:
  pha               ; Save Accumulator
  lda #%00000000    ; Switch VIA_PORTB to Input
  sta VIA_DDRB
@busy_loop:
  lda #RW           ; Set Read Mode
  sta VIA_PORTA
  lda #(RW | E)     ; Pulse Enable
  sta VIA_PORTA
  lda VIA_PORTB         ; Read status
  and #%10000000    ; Check bit 7 (Busy Flag)
  bne @busy_loop    ; If 1, LCD is busy
  lda #RW
  sta VIA_PORTA
  lda #%11111111    ; Switch VIA_PORTB back to Output
  sta VIA_DDRB
  pla               ; Restore Accumulator
  rts

lcd_clear:
  lda #%00000001    ; Clear command
  jsr lcd_instruction
  rts

lcd_init_no_cursor:
  lda #%00111000 ; 8-bit mode, 2-line, 5x8 font
  jsr lcd_instruction
  lda #%00001100 ; Display on, cursor off, blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment cursor, no shift
  jsr lcd_instruction

; Move cursor to X (col), Y (row)
lcd_gotoxy:
    cpy #0
    beq @row0
    txa
    clc
    adc #$40
    jmp @send
@row0:
    txa
@send:
    ora #%10000000
    jsr lcd_instruction
    rts
