;autor: Jose Martinez
;descripcion: 2 contadores+sumador+overflow led

.include "m328pdef.inc"

.dseg
.org sram_start

.cseg
.org 0x0000

ldi r16, low(ramend)
out spl, r16
ldi r16, high(ramend)
out sph, r16

SETUP:
	cbi ddrd, ddd6;PD6 boton 1 (contador 1)
	cbi ddrd, ddd7;PD7 boton 2(contador 1)
	cbi ddrc, ddc4;PC4 boton 3(contador 2)
	cbi ddrc, ddc5;PC5 boton 4(contador 2)
	cbi ddrb, ddb4; PB4 boton suma

	sbi ddrb, ddb0; pb0-pb3 leds contador 1
	sbi ddrb, ddb1
	sbi ddrb, ddb2
	sbi ddrb, ddb3

	sbi ddrd, ddd2 ;pd2-pd5 leds contador 2
	sbi ddrd, ddd3
	sbi ddrd, ddd4
	sbi ddrd, ddd5

	sbi ddrc, ddc0 ;pc0-pc3 leds sumador
	sbi ddrc, ddc1
	sbi ddrc, ddc2
	sbi ddrc, ddc3

	sbi ddrb, ddb5 ;led overflow en PB5

	clr r16 ;empezar con todo apagado
	out portb, r16
	out portc, r16
	out portd, r16

	sbi portd, portd6 ; activacion pull up en todos los botones
	sbi portd, portd7
	sbi portc, portc4
	sbi portc, portc5
	sbi portb, portb4

	ldi r16, (1<<clkpce) ;cambiar prescaler reloj (division entre 16)
	sts clkpr, r16
	ldi r16, 0b00000100
	sts clkpr, r16 ;nuevo valor del clock

	clr r20; contador 1 (setear en 0)
	clr r21 ;contador 2 (setear en 0)
	clr r22 ;sumador (setear en 0)

MAIN_LOOP:
	rcall CONTADOR1
	rcall CONTADOR2
	rcall SUMADOR
	rjmp MAIN_LOOP

CONTADOR1:
	in r16, pind ;leer puerto d
	andi r16, 0b11000000 ;solo bits de pd6 y pd7
	cpi r16, 0b11000000 ; mascara para ver si mis botones estan presionados
	breq out_contador1; si no hay boton salta 

	rcall delay ;antirrebote

	in r17, pind; vuelve a leer el puerto D
	andi r17, 0b11000000
	cp r17, r16 ;comparar la lectura de ahorita con la de antes
	brne out_contador1 ; si no cambia no hace nada

	sbrs r17, 6 ;pd6 presionado
	rcall incrementar_contador1; contador +1
	sbrs r17, 7 ;pd7 presionado
	rcall restar_contador1; contador -1
	rjmp out_contador1

CONTADOR2:
	in r16, pinc ; puerto c botones 
	andi r16, 0b00110000
	cpi r16, 0b00110000
	breq out_contador2

	rcall delay

	in r17, pinc
	andi r17, 0b00110000
	cp r17, r16
	brne out_contador2
	sbrs r17, 4
	rcall sumar_contador2
	sbrs r17, 5
	rcall restar_contador2
	rjmp out_contador2

out_contador1:
	in r18, portb ;leer portb
	andi r18, 0b11110000 ;solo mis 4 bits significativos 
	mov r19, r20 ;valor contador 1
	andi r19, 0b00001111
	or r18, r19 ;valor del contador con mi puerto y bits que quiero
	out portb, r18
	ret

out_contador2:
	in r18, portd
	andi r18, 0b11000011
	mov r19, r21
	andi r19, 0b00001111
	lsl r19
	lsl r19
	or r18, r19
	out portd, r18
	ret

SUMADOR:
	in r16, pinb; leer boton suma 
	sbrc r16, 4 ; no presionado
	ret

	rcall delay; antirrebote

	in r16, pinb;leer otra vez
	sbrc r16, 4;se suelta el boton? si salgo
	ret

	mov r22, r20; valor contador 1 copiado
	add r22, r21; sumar con contador 2

	mov r19, r22; copiar suma
	andi r19, 0b11110000; revisar bits mas significativos
	cpi r19, 0b00000000;ver si hay overflow
	breq sin_overflow; si no hay overflow salto

	sbi portb, portb5; se enciende la led overflow
	rjmp out_suma; no se apaga 

sin_overflow:
	cbi portb, portb5; no hay overflow la apago

out_suma:
	in r18, portc; leer puerto C
	andi r18, 0b11110000
	mov r19, r22;copiar valor suma
	andi r19, 0b00001111
	or r18, r19 ; mostrar en el puerto los bits que quiero
	out portc, r18;mostrar suma

antirrebote_suma:
	sbis pinb, 4        ; esperar que se suelte el boton
	rjmp antirrebote_suma
	rcall delay         ; pequeño retardo
	ret                 ; volver al main



delay:
	ldi r23, 0x0f 
delay_a:
	ldi r24, 0x0f
delay_b:
	ldi r25, 0x0f 
delay_c:
	dec r25 ;restar en cada uno asi se vuelve un delay mas grande como tipo loop
	brne delay_c
	dec r24
	brne delay_b
	dec r23
	brne delay_a
	ret


incrementar_contador1:
	inc r20; sumo 
	andi r20, 0b00001111; 4 bits
	rjmp antirrebote1

restar_contador1:
	dec r20
	andi r20, 0b00001111
	rjmp antirrebote2

antirrebote1:
	sbis pind, 6; se solto el boton pd6? solo salta si el bit esta en 1
	rjmp antirrebote1
	rcall delay
	ret

antirrebote2:
	sbis pind, 7
	rjmp antirrebote2
	rcall delay
	ret

sumar_contador2:
	inc r21
	andi r21, 0b00001111
	rjmp antirrebote3

restar_contador2:
	dec r21
	andi r21, 0b00001111
	rjmp antirrebote4

antirrebote3:
	sbis pinc, 4
	rjmp antirrebote3
	rcall delay
	ret

antirrebote4:
	sbis pinc, 5
	rjmp antirrebote4
	rcall delay
	ret