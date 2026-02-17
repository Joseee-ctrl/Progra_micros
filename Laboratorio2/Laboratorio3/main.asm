;JOSE MARTINEZ
.include "M328PDEF.inc"

.cseg
.org 0x00


LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

// TABLA 7 SEG (CÁTODO)
T7S: 
.DB 0x3F, 0x06, 0x5B, 0x4F, 0X66, 0X6D, 0X7D, 0X07
.DB 0X7F, 0X6F, 0X77, 0X7C, 0X39, 0X5E, 0X79, 0X71

SETUP:
    call Timer0; llamar a mi subrutina de timer0

    ; prescaler
    ldi R16, (1 << CLKPCE)
    sts CLKPR, R16; habilitar cambio prescaler
    ldi R16, 0b0000_0111
    sts CLKPR, R16; dividir entre 128

; botones
    ldi R16, 0b0000_0110
    out PORTB, R16;pullups PB1 y PB2

    sbi DDRB, PB0;segmento g lo puse en D8 activamos la salida
    ldi R16, 0b1111_1111
    out DDRD, R16;salidas portd (LEDS)

    ldi R16, 0b0111_1111
    out DDRC, R16; Display salidas

    ldi R18, 0; poner display en 0
    ldi R21, 0
    ldi ZH, HIGH(T7S << 1)
    ldi ZL, LOW(T7S << 1)
    add ZL, R18
    lpm R18, Z; leer en la flash el valor de mi tabla (en este caso empieza en 0)

	LDI R20, 0; cuantas veces mi timer llega a 100ms
    ldi R19, 0; contador de los LEDS
    ldi R23, 0; alarma apagada 
    ldi R22, 15; limite superior del contador (00001111)
    ldi R24, 0; limite inferior

LOOP:

    out PORTC, R18; segmentos del portc 

    sbrc R18, 6; si el bit 6 de r18 esta en 0 salta la siguiente isntruccion
    sbi PORTB, PB0; pone en 1 el pb0
    sbrs R18, 6
    cbi PORTB, PB0; copia el estado del bit6 de r18

    in R16, PINB ;leer mis botones
    sbrs R16, PB2
    rjmp ANTIREBOTE1

    in R17, PINB
    sbrs R17, PB1
    rjmp ANTIREBOTE2

    in R16, TIFR0; registro de banderas del timer0
    sbrs R16, OCF0A; si la bandera es 0 voy a loop
    rjmp LOOP

    sbi TIFR0, OCF0A; limpiar la bandera con 1
    inc R20; cuantas veces lleva el timer
    cpi R20, 1; si no es 1 vuelvo al loop
    brne LOOP

    clr R20; reiniciar contador

    sbi PINB, PB3; toggle (alternar estado 0 y 1 o y 1 0)
    cpse R19, R22; si no son iguales voy a LEDS
    call LEDS

    ldi R19, 0
    out PORTD, R19; apagar los leds 
    cpse R23, R24
    sbi PORTD, PD6; encender alarma si no son iguales 
    rjmp LOOP

	
INCREMENTAR:
    cpse R21, R22
    inc R21
    mov R18, R21
    ldi ZH, HIGH(T7S << 1)
    ldi ZL, LOW(T7S << 1); cargar direccion de mi tabla 
    add ZL, R18
    lpm R18, Z
    rjmp LOOP

DECREMENTAR:
    cpse R21, R24
    dec R21
    mov R18, R21
    ldi ZH, HIGH(T7S << 1)
    ldi ZL, LOW(T7S << 1)
    add ZL, R18
    lpm R18, Z
    rjmp LOOP

LEDS: 
    inc R19; incrementar contador binario
    lsl R19
    lsl R19; mover a la izquierda 2 veces
    out PORTD, R19

    cpse R23, R24
    sbi PORTD, PD6; encender si la alarma esta activa
    lsr R19
    lsr R19; derecha
    cpse R19, R21; si no coinciden vuelvo al loop
    rjmp LOOP
    call ALARMA

Timer0: 
    LDI R16, 0
    OUT TCNT0, R16; el contador empieza en 0

    LDI R16, 156
    OUT OCR0A, R16; el compare A tiene el valor 156

    LDI R16, (1 << WGM01)
    OUT TCCR0A, R16; modo CTC para poder igualar TCNT0=OCR0A

    LDI R16, (1 << CS02)|(1 << CS00);(1 << 2) = 00000100, (1 << 0) = 00000001
    OUT TCCR0B, R16; configurar prescaler del timer0 (1024)
    RET

ALARMA:
    cpse R23, R24; si estaba activa la apago
    call APAGAR_ALARMA
    ldi R23, 15; alarma activa marcada
    sbi PORTD, PD6; encender led
    ldi R19, 15; contador a 15 obligatorio
    rjmp LOOP

APAGAR_ALARMA:
    ldi R23, 0
    ldi R19, 15; apagar estado de mi alarma y volver al loop
    rjmp LOOP

	ANTIREBOTE1:
    ldi R16, 100
delay:
    dec R16
    brne delay
    sbis PINB, PB2
    rjmp ANTIREBOTE1
    call INCREMENTAR

ANTIREBOTE2:
    ldi R17, 100
delay2:
    dec R17
    brne delay2
    sbis PINB, PB1
    rjmp ANTIREBOTE2
    call DECREMENTAR
