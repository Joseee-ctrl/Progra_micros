.include "m328pdef.inc"

;Variables
.def contador   = r16 ; contador principal 0..15
.def aux        = r17
.def aux2       = r18
.def contadorr2 = r19; contador de referencia para alarma
.def t0ovf      = r20
.def tmp        = r21
.def tickst     = r22

.dseg
.org SRAM_START

.cseg
.org 0x0000
    rjmp RESET

RESET:
    LDI     R16, LOW(RAMEND)
    OUT     SPL, R16
    LDI     R16, HIGH(RAMEND)
    OUT     SPH, R16

    clr r1
    clr contador
    clr contadorr2
    clr tickst

; PD2-PD5 salidas (LEDs Timer0)
    ldi aux, 0b11111100
    out DDRD, aux
    cbi PORTD, 2
    cbi PORTD, 3
    cbi PORTD, 4
    cbi PORTD, 5

;DDRB: PB5 salida (alarma)
    sbi DDRB, 5
    cbi PORTB, 5

;Botones en PC0 y PC1 con pull-up 
    cbi DDRC, 0
    cbi DDRC, 1
    sbi PORTC, 0
    sbi PORTC, 1

 ;Timer0 normal con prescaler 1024 
    ldi aux, 0x00
    out TCCR0A, aux
    ldi aux, (1<<CS02)|(1<<CS00)
    out TCCR0B, aux

    rjmp MAIN_LOOP

MAIN_LOOP:

    rcall Tick100ms_Timer0; Timer0 no bloqueante

    tst tmp
    breq NO_TICK

    inc contador
    andi contador, 0x0F
    rcall MostrarLEDs; actualizar LEDs

NO_TICK:
    rcall AlarmaCheck; revisar alarma
    rjmp MAIN_LOOP

; Timer0 normal a casi 100ms
Tick100ms_Timer0:
    clr tmp
    tst tickst
    brne T0_CHECK

    ldi t0ovf, 6
    ldi aux, 229
    out TCNT0, aux
    ldi aux, (1<<TOV0)
    out TIFR0, aux
    ldi tickst, 1
    ret

T0_CHECK:
    in aux2, TIFR0
    sbrs aux2, TOV0
    ret

;overflow ocurrió, limpiar bandera
    ldi aux, (1<<TOV0)
    out TIFR0, aux
    clr aux
    out TCNT0, aux

    dec t0ovf
    brne T0_NOTYET

    clr tickst
    ldi tmp, 1
    ret

T0_NOTYET:
    ret


MostrarLEDs:
    mov aux, contador
    andi aux, 0x0F
    lsl aux
    lsl aux
    in aux2, PORTD
    andi aux2, 0b11000011
    or aux2, aux
    out PORTD, aux2
    ret

AlarmaCheck:
    mov aux, contador
    andi aux, 0x0F
    mov aux2, contadorr2
    cp aux, aux2
    brne AlarmOff

AlarmOn:
    sbi PORTB, 5
    ret

AlarmOff:
    cbi PORTB, 5
    ret
