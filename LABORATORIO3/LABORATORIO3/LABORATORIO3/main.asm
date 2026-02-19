
;JOSE MARTINEZ
;LABORATORIO_3

.include "M328PDEF.inc"

.dseg
.org SRAM_START
d_10:   .byte 1 ; reservar 1 byte en RAM para guardar las interupciones de 10ms
units:  .byte 1 ; guardar las unidades de segundos (0-9)
tens:   .byte 1 ; guardar las decenas de segundos (0-5)


.cseg
.org 0x0000
RJMP RESET

.org 0x001C ; vector de interrupcion Compare Match A del Timer0
RJMP TMR0 ; cuando OCF0A se activa y OCIE0A esta habilitado, el micro salta aqui automaticamente


RESET: ;inicializar stack obligatorio porque usamos PUSH, POP y subrutinas
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

    RJMP SETUP

; Deshabilitar USART (no se usa comunicacion serial en este laboratorio)
LDI R16, 0x00
STS UCSR0B, R16


; Tabla de patrones para display 7 segmentos (0-F)
; Cada byte representa abcdefg (bit0=a ... bit6=g)
TS7:
 .DB 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71


SETUP:
    CLR R1 ; siempre mantener R1 en 0 para operaciones ADC

    LDI R16, 0b11111110 ; PD1–PD7 salidas
    OUT DDRD, R16

    LDI R16, 0b11111110 ; el display es de anodo comun entonces para empezar apagado los pongo en 1
    OUT PORTD, R16

    ;Digito 1 (unidades)
    SBI DDRC, DDC0 ; Digito 1 de mi display en PC0
    SBI PORTC, PC0 ; activar digito 1 en HIGH

    ;Digito 2 (decenas)
    SBI DDRC, DDC1 ; Digito 2 conectado en PC1
    CBI PORTC, PC1 ; empezar apagado el segundo display

    CLR R16
    STS d_10, R16 ; empezar el timer en 0
    STS units, R16 ; empezar unidades en 0
    STS tens, R16 ; empezar decenas en 0

    ;TIMER0 CTC 10ms 
    LDI R16, (1<<WGM01) ; activar modo CTC (Clear Timer on Compare Match)
    OUT TCCR0A, R16

    LDI R16, (1<<CS02)|(1<<CS00) ; prescaler /1024
    OUT TCCR0B, R16

    LDI R16, 155 ; cuando llegue a 155 TCNT0 (9.9ms aprox)
    OUT OCR0A, R16 ; valor limite del contador en modo CTC, cuando TCNT0 = OCR0A se activa OCF0A y el contador se reinicia automaticamente
 

    CLR R16 ; reiniciar contador
    OUT TCNT0, R16 ; limpiar contador del timer0

    LDI R16, (1<<OCF0A) ; limpiar bandera de compare match A
    OUT TIFR0, R16

    LDI R16, (1<<OCIE0A) ; habilitar interrupción por Compare Match A del Timer0
	STS TIMSK0, R16 ; ahora cuando OCF0A se active, el micro saltara al vector 0x001C


    SEI ; NO OLVIDAR INTERRUPCIONES GLOBALES


MAIN_LOOP:
    RJMP MAIN_LOOP ; todo ocurre en la interrupcion (el main loop no hace nada)


TMR0:
    PUSH R16 ; guardar registros usados
    PUSH R17
    IN   R17, SREG ; copiar el registro de estado en r17 (banderas)
    PUSH R17

    ;contar 10ms
    LDS R16, d_10 ; cargar desde la SRAM d_10
    INC R16
    CPI R16, 100 ; comparar con 100 (100 * 10ms = 1 segundo)
    BRLO GUARDAR_10 ; si es menor que 100 salto a guardar

    ;1 segundo completo alcanzado
    CLR R16
    STS d_10, R16 ; reiniciar contador de 10ms

    ;incrementar unidades (0-9)
    LDS R16, units ; cargar unidades actuales
    INC R16
    CPI R16, 10 ; verificar si llego a 10
    BRLO Guardar_unidades ; si es menor que 10 solo guardar

    ;si llego a 10 reiniciar unidades
    CLR R16
    STS units, R16

    ;incrementar decenas (0-5)
    LDS R16, tens
    INC R16
    CPI R16, 6 ; si llega a 6 significa que llegamos a 60 segundos
    BRLO Guardar_decenas ; si es menor que 6 solo guardar

    ;si llego a 60 segundos reiniciar todo
    CLR R16
    STS tens, R16
    RJMP MOSTRAR

Guardar_decenas:
    STS tens, R16
    RJMP MOSTRAR

Guardar_unidades:
    STS units, R16
    RJMP MOSTRAR

GUARDAR_10:
    STS d_10, R16 ; si no llego a 100 solo guardo mi valor


MOSTRAR:
    ;primero mostrar unidades y luego decenas muy rapido
    ;ambos comparten PORTD (activar con PC0 y PC1)

    ;mostrar unidades
    SBI PORTC, PC0 ; activar display unidades
    CBI PORTC, PC1 ; apagar display decenas

    LDS R16, units
    RCALL SEG7_DECODE ; convertir numero a patron
    RCALL Mostrar_display ; enviar patron al puerto
    RCALL SMALL_DELAY ; pequeno tiempo visible

    ;mostrar decenas
    CBI PORTC, PC0 ; apagar unidades
    SBI PORTC, PC1 ; activar decenas

    LDS R16, tens
    RCALL SEG7_DECODE
    RCALL Mostrar_display
    RCALL SMALL_DELAY

    POP R17 ; recuperar mi SREG que tenia guardado
    OUT SREG, R17 ; restaurar banderas
    POP R17
    POP R16 ; restaurar registros
    RETI ; regresar de interrupciones


MOSTRAR_DISPLAY: ; R16 = patron abcdefg 

    LSL R16 ;Mover uno a la izquierda (porque usamos PD1-PD7 no PD0)
    COM R16 ; invertir (anodo comun cambiar 0 a 1, 1 a 0)

    ANDI R16, 0b11111110 ; proteger PD0 (no lo uso)
    OUT PORTD, R16 ; mostrar en el puerto D

    RET

SEG7_DECODE:; cargar en z la direccion base de la TS7
    PUSH ZL
    PUSH ZH

    LDI ZH, HIGH(TS7*2) ; cargar mi direccion de la tabla (flash)
    LDI ZL, LOW(TS7*2)

    ADD ZL, R16 ; sumar el indice (numero a mostrar)
    ADC ZH, R1 ; sumar si hubo overflow (R1 es 0)

    LPM R16, Z ; Leer desde mi flash el patron correcto 

    POP ZH
    POP ZL ; restaurar direccion de Z
    RET


SMALL_DELAY:
    ; pequeno retardo para que el ojo humano alcance a ver el display
    ; esto permite el multiplexado sin que parezca que parpadea
    LDI R18, 30
D1:
    LDI R19, 200
D2:
    DEC R19
    BRNE D2
    DEC R18
    BRNE D1
    RET