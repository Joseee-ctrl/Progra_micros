
.include "M328PDEF.inc"
.cseg
.org 0x00
//***************************************************************************
// Stack
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17
//***************************************************************************
// CONFIGURACION
//***************************************************************************

	T7S: .DB 0x3F, 0x06, 0x5B, 0x4F, 0X66, 0X6D, 0X7D, 0X07, 0X7F, 0X6F, 0X77, 0X7C, 0X39, 0X5E, 0X79, 0X71
SETUP:
	ldi R16, (1 << CLKPCE)
	sts CLKPR, R16				;	prescaler
	ldi R16, 0b0000_1000		; 1000
	sts CLKPR, R16				;	definido a 8 fcpu = 2MHz			
;*********************************************************	   INPUTS
	ldi R16, 0b0000_0110
	out PORTB, R16				;input pullup
	ldi R16, 0b1111_1111
	out DDRD, R16				; OUTPUT
	ldi R16, 0b0111_1111
	out DDRC, R16				; output display
	ldi R18, 0					; T7S
	ldi R19, 0					; valor inicial
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R18
	lpm R18, Z
	
LOOP:
	sbrc R18, PC6
	sbi PIND, PD7
	out PORTC, R18
	cbi PORTD, PD7
	in R16, PINB
	sbrs R16, PB2				;	if bit = 1 ==> salta
	rjmp DB_1					;	verifica antirebote
	in R17, PINB
	sbrs R17, PB1
	rjmp DB_2
	rjmp LOOP

//**********************************************************		
DB_1:
	ldi R16, 100				;	espera el tiempo
	delay:
		dec R16
		brne delay
	;	lee el estado del bot?n despues del antirebote
	sbis PINB, PB2				;	salta si el bit es 1
	rjmp DB_1			;	repite verificaci?n
	call AUMENTAR

DB_2:
	ldi R17, 100				;	espera el tiempo
	delay2:
		dec R17
		brne delay2
	;	lee el estado del bot?n despues del antirebote
	sbis PINB, PB1				;	salta si el bit es 1
	rjmp DB_2			;	repite verificaci?n
	call DECREMENTAR
	
AUMENTAR:
	inc R19						; T7S
	mov R18, R19
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R18
	lpm R18, Z
	rjmp LOOP

DECREMENTAR:
	dec R19						; T7S
	mov R18, R19
	ldi ZH, HIGH(T7S << 1)
	ldi ZL, LOW(T7S << 1)
	add ZL, R18
	lpm R18, Z
	rjmp LOOP