/*
 *
 * Created: 4/6/26
<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
 * Author: Jose Mart?nez
=======
 * Author: Jose Martínez
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
 * Description: Contador de 8 bits + pot (ADC) en displays + alarma
 */

/****************************************/
// Encabezado (Libraries)
#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdint.h>

/****************************************/
// Variables globales
volatile uint8_t valor_adc = 0;

/****************************************/
// Tabla de 7 segmentos
const uint8_t hex7seg[16] = {
	0x3F, // 0
	0x06, // 1
	0x5B, // 2
	0x4F, // 3
	0x66, // 4
	0x6D, // 5
	0x7D, // 6
	0x07, // 7
	0x7F, // 8
	0x6F, // 9
	0x77, // A
	0x7C, // b
	0x39, // C
	0x5E, // d
	0x79, // E
	0x71  // F
};

/****************************************/
// Function prototypes
void config_inicial(void);
void config_adc(void);

uint8_t revisar_boton(uint8_t pin);

void limpiar_displays(void);
void escribir_hex_display(uint8_t digito);
void refrescar_hex(uint8_t numero);
void revisar_alarma(uint8_t cuenta);

/****************************************/
// Main Function
int main(void)
{
	uint8_t cuenta = 0;

	cli();
	config_inicial();
	config_adc();
	sei();

	PORTD = cuenta;

	while (1)
	{
		for (uint8_t rep = 0; rep < 20; rep++)
		{
			refrescar_hex(valor_adc);
			revisar_alarma(cuenta);
		}

		if (revisar_boton(PB0))
		{
			cuenta++;
			PORTD = cuenta;
			revisar_alarma(cuenta);

			while (!(PINB & (1 << PB0)))
			{
				refrescar_hex(valor_adc);
				revisar_alarma(cuenta);
			}
			_delay_ms(20);
		}

		if (revisar_boton(PB1))
		{
			cuenta--;
			PORTD = cuenta;
			revisar_alarma(cuenta);

			while (!(PINB & (1 << PB1)))
			{
				refrescar_hex(valor_adc);
				revisar_alarma(cuenta);
			}
			_delay_ms(20);
		}
	}
}

/****************************************/
<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
// CONFIGURACI?N GENERAL
=======
// CONFIGURACIÓN GENERAL
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
void config_inicial(void)
{
	// Desactivar USART
	UCSR0B = 0x00;

	// Configurar PORTD como salida para contador
	DDRD = 0xFF;
	PORTD = 0x00;

	// Configurar botones en PB0 y PB1 como entrada
	DDRB &= ~((1 << PB0) | (1 << PB1));
	PORTB |= (1 << PB0) | (1 << PB1);

	// Configurar segmentos en PB2-PB5 como salida
	DDRB |= (1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5);
	PORTB &= ~((1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5));

<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
	// Configurar segmentos y d?gitos en PORTC como salida
=======
	// Configurar segmentos y dígitos en PORTC como salida
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
	DDRC |= (1 << PC0) | (1 << PC1) | (1 << PC2) | (1 << PC3) | (1 << PC4) | (1 << PC5);

	// Apagar LED de alarma al inicio
	PORTC &= ~(1 << PC0);

	// Limpiar segmentos de PORTC
	PORTC &= ~((1 << PC1) | (1 << PC2) | (1 << PC3));

	// Apagar displays al inicio
	limpiar_displays();
}

/****************************************/
<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
// CONFIGURACI?N ADC
=======
// CONFIGURACIÓN ADC
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
void config_adc(void)
{
	ADMUX = 0;
	ADMUX |= (1 << REFS0);                  // referencia AVcc
	ADMUX |= (1 << ADLAR);                  // ajuste a la izquierda
	ADMUX |= (1 << MUX2) | (1 << MUX1);     // canal ADC6

	ADCSRA = 0;
	ADCSRA |= (1 << ADEN);                  // habilitar ADC
<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
	ADCSRA |= (1 << ADIE);                  // habilitar interrupci?n ADC
	ADCSRA |= (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); // prescaler 128

	// Iniciar primera conversi?n
=======
	ADCSRA |= (1 << ADIE);                  // habilitar interrupción ADC
	ADCSRA |= (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); // prescaler 128

	// Iniciar primera conversión
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
	ADCSRA |= (1 << ADSC);
}

/****************************************/
// LECTURA DE BOTONES CON ANTIRREBOTE
uint8_t revisar_boton(uint8_t pin)
{
	if (!(PINB & (1 << pin)))
	{
		_delay_ms(20);

		if (!(PINB & (1 << pin)))
		{
			return 1;
		}
	}
	return 0;
}

/****************************************/
// APAGAR LOS DOS DISPLAYS
void limpiar_displays(void)
{
	PORTC |= (1 << PC4) | (1 << PC5);
}

/****************************************/
<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
// CARGAR SEGMENTOS SEG?N VALOR HEXADECIMAL
=======
// CARGAR SEGMENTOS SEGÚN VALOR HEXADECIMAL
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
void escribir_hex_display(uint8_t digito)
{
	uint8_t codigo = hex7seg[digito];

	// Limpiar segmentos
	PORTB &= ~((1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5));
	PORTC &= ~((1 << PC1) | (1 << PC2) | (1 << PC3));

	// a
	if (codigo & (1 << 0)) PORTB |= (1 << PB2);

	// b
	if (codigo & (1 << 1)) PORTB |= (1 << PB3);

	// c
	if (codigo & (1 << 2)) PORTB |= (1 << PB4);

	// d
	if (codigo & (1 << 3)) PORTB |= (1 << PB5);

	// e
	if (codigo & (1 << 4)) PORTC |= (1 << PC1);

	// f
	if (codigo & (1 << 5)) PORTC |= (1 << PC2);

	// g
	if (codigo & (1 << 6)) PORTC |= (1 << PC3);
}

/****************************************/
// MOSTRAR BYTE EN DOS DISPLAYS
void refrescar_hex(uint8_t numero)
{
	uint8_t nibble_izq = (numero >> 4) & 0x0F;
	uint8_t nibble_der = numero & 0x0F;

	// Mostrar nibble alto en display izquierdo
	limpiar_displays();
	escribir_hex_display(nibble_izq);
	PORTC &= ~(1 << PC4);
	_delay_ms(1);

	// Mostrar nibble bajo en display derecho
	limpiar_displays();
	escribir_hex_display(nibble_der);
	PORTC &= ~(1 << PC5);
	_delay_ms(1);

	limpiar_displays();
}

/****************************************/
// COMPARAR ADC CON CONTADOR Y ENCENDER ALARMA
void revisar_alarma(uint8_t cuenta)
{
	if (valor_adc >= cuenta)
	{
		PORTC |= (1 << PC0);
	}
	else
	{
		PORTC &= ~(1 << PC0);
	}
}


/****************************************/
// Interrupt routines
ISR(ADC_vect)
{
	// Guardar resultado ADC de 8 bits
	valor_adc = ADCH;

<<<<<<< HEAD:laboratorio4/GccApplication1/GccApplication1/main.c
	// Iniciar siguiente conversi?n
=======
	// Iniciar siguiente conversión
>>>>>>> ef7a6c377d7e247af0714d79d76829bda9e2295d:laboratorio4/Lab4/Lab4/main.c
	ADCSRA |= (1 << ADSC);
}