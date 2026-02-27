.setcpu "65C02"
.include "defs.inc"

.export lcd_instruction
.export lcd_print_char
.export lcd_clear
.export lcd_init_no_cursor
.export lcd_gotoxy
.export lcd_print_decimal
.export lcd_print_string
.export MSG_PTR

E  = %10000000
RW = %01000000
RS = %00100000

.segment "ZEROPAGE"
hundreds:   .res 1
remainder:  .res 1
tens:       .res 1
ones:       .res 1
MSG_PTR:    .res 1

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
    adc #$40 ; Row 1 DDRAM starts at $40 (64 decimal)
    ;adc #32 ; für emulator
    jmp @send
@row0:
    txa
@send:
    ora #%10000000
    jsr lcd_instruction
    rts

lcd_print_decimal:
  ; Input: A register contains value to print (0-255)
  ; Prints the decimal value to LCD
  ; Uses: Y, X as temporary storage for digit counters
  
  pha                ; Save original value
 
  ; First, handle the hundreds place
  lda #0
  sta hundreds       ; Use as temp for hundreds count
  pla
  
  ; Divide by 100
@div100:
  cmp #100
  bcc @div100_done
  sbc #100
  inc hundreds
  jmp @div100
  
@div100_done:
  sta remainder      ; Store remainder (tens+ones)
  
  ; Print hundreds digit (only if non-zero)
  lda hundreds
  beq @skip_hundreds
  ora #$30
  jsr lcd_print_char
  
@skip_hundreds:
  lda remainder      ; Get remainder
  
  ; Handle tens place
  lda #0
  sta tens           ; Tens counter
  lda remainder
  
@div10:
  cmp #10
  bcc @div10_done
  sbc #10
  inc tens
  jmp @div10
  
@div10_done:
  sta ones           ; Store ones
  
  ; Print tens digit (only if hundreds was printed or tens > 0)
  lda hundreds
  bne @print_tens    ; If hundreds was printed, always print tens
  lda tens
  beq @skip_tens     ; If tens is zero and no hundreds, skip
  
@print_tens:
  lda tens
  ora #$30
  jsr lcd_print_char
  
@skip_tens:
  ; Always print ones digit
  lda ones
  ora #$30
  jsr lcd_print_char
  
  rts

lcd_print_string:
  pha
  phy
  ldy #0            ; Reset index
@next_char:
  lda (MSG_PTR),y   ; Indirect Indexed: Look at address in $00/$01 + Y
  beq @done         ; If we hit 0 (end of string), stop
  jsr lcd_print_char    ; Send character to LCD
  iny               ; Next character
  jmp @next_char
@done:
  ply
  pla
  rts
