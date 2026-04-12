/*
* Proyecto1_Progrademicros_mar24050
* Autor : Jose Martinez
* Descripción: Proyecto 1 programacion de microcontroladores: Reloj de 24 horas + fecha + alarma + settings 
*/

; ======================== VARIABLES SRAM
.include "M328PDEF.inc"
.dseg
.org SRAM_START

msL:        .byte 1
msH:        .byte 1 ;(msL y msH hacen un contador de 16 bits que llega hasta 1000 
flag_1s:    .byte 1

blinkL:     .byte 1
blinkH:     .byte 1;500 ms 

seg:        .byte 1; contador segundos
min_u:      .byte 1
min_d:      .byte 1
hour_u:     .byte 1
hour_d:     .byte 1;reservar byte minutos y hora

day_u:      .byte 1
day_d:      .byte 1
month_u:    .byte 1
month_d:    .byte 1;reservar byte variables fecha

current:    .byte 1 ;controlar multiplexado display (que digito muestra) 

btn_flags:  .byte 1; que boton se presiona
mode:       .byte 1
edit_digit: .byte 1 ;que digito se edita

alarm_min_u:   .byte 1
alarm_min_d:   .byte 1
alarm_hour_u:  .byte 1
alarm_hour_d:  .byte 1; byte variables alarma

alarm_active:  .byte 1

.cseg
.org 0x0000
RJMP RESET

.org 0x0006
RJMP PCINT0_ISR ;interrupcion botones salta a ese vector

.org 0x001C
RJMP TIMER_ISR ;1ms

TS7:
.DB 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F; tabla display

; ========================

RESET:
    LDI R16,LOW(RAMEND)
    OUT SPL,R16
    LDI R16,HIGH(RAMEND)
    OUT SPH,R16
	; Deshabilitar USART
	LDI R16, 0x00
	STS UCSR0B, R16

    RJMP SETUP; inicializar stack

; =========================================
SETUP:
    CLR R1
; segmentos
    LDI R16,0b11111111
    OUT DDRD,R16
    CLR R16
    OUT PORTD,R16
; PC1–PC5 salida
    LDI R16,0b00111110
    OUT DDRC,R16
    CLR R16
    OUT PORTC,R16
; PB4 y PB5 salida (LED fecha + buzzer)
	LDI R16,0b00110000
	OUT DDRB,R16
; LED hora PC0
	SBI DDRC,0
; LED alarma PD7
	SBI DDRD,7
; pullups botones
	LDI R16,0b00001111
	OUT PORTB,R16
; configurar interrupciones PCINT
    LDI R16,(1<<PCIE0); habilitar
    STS PCICR,R16
    LDI R16,0b00001111
    STS PCMSK0,R16;mascara pines especificos activen interrupcion 
; limpiar RAM 
;hora (empezar en 0)
    CLR R16
    STS msL,R16
    STS msH,R16
    STS flag_1s,R16
    STS blinkL,R16
    STS blinkH,R16
    STS seg,R16
    STS min_u,R16
    STS min_d,R16
    STS hour_u,R16
    STS hour_d,R16
    STS current,R16
    STS btn_flags,R16
    STS mode,R16
    STS edit_digit,R16
; FECHA (empezar en 01/01)
	CLR R16
	STS day_u,R16
	STS day_d,R16
	STS month_u,R16
	STS month_d,R16
	LDI R16,1
	STS day_u,R16
	STS month_u,R16
;ALARMA(empezar 23:59)
	LDI R16,9
	STS alarm_min_u,R16
	LDI R16,5
	STS alarm_min_d,R16
	LDI R16,3
	STS alarm_hour_u,R16
	LDI R16,2
	STS alarm_hour_d,R16
	CLR R16
	STS alarm_active,R16
; CONFIGURACION TIMER0 (1ms)(frecuencia 16MHz)
    LDI R16,(1<<WGM01)
    OUT TCCR0A,R16; modo CTC
    LDI R16,(1<<CS01)|(1<<CS00)
    OUT TCCR0B,R16; prescaler de 64
    LDI R16,249; valor de comparacion OCR0A
    OUT OCR0A,R16
    LDI R16,(1<<OCIE0A)
    STS TIMSK0,R16; habilitar interrupcion por comparacion
	RCALL UPDATE_MODE_LEDS

    SEI; interrupciones globales

; ========================================= MAIN LOOP
MAIN:
; boton presionado?
    LDS R16,btn_flags
    CPI R16,0
    BREQ CHECK_CLOCK
; MODE (PB0)
    SBRS R16,0
    RJMP CHECK_SETTINGS; bloquear MODE si estamos editando
    LDS R17,edit_digit
    CPI R17,0
    BRNE CLEAR_BTN
    RCALL CHANGE_MODE; rutina cambiar modos
    RJMP CLEAR_BTN; limpiar flags boton 

CHECK_SETTINGS: ;(PB1)
    SBRS R16,1
    RJMP CHECK_UP; si no estoy presionando (no cambio digito) veo mi up
    RCALL NEXT_EDIT; cambiar el digito que estoy editando
    RJMP CLEAR_BTN

CHECK_UP: ; UP (PB2)
	SBRS R16,2
	RJMP CHECK_DOWN ; si no esta presionado reviso down
	LDS R17,alarm_active
	CPI R17,1 ; verificar si la alarma esta activa
	BRNE DO_UP
	LDS R18,edit_digit
	CPI R18,0 ; si no estoy editando se puede apagar la alarma
	BRNE DO_UP
	CLR R17
	STS alarm_active,R17 ; apagar alarma
	CBI PORTB,5

DO_UP:
	RCALL INC_DIGIT; rutina de incrementar 
	RJMP CLEAR_BTN

CHECK_DOWN:; DOWN (PB3)
	SBRS R16,3
	RJMP CLEAR_BTN
	LDS R17,alarm_active
	CPI R17,1
	BRNE DO_DOWN
	CLR R17
	STS alarm_active,R17
	CBI PORTB,5

DO_DOWN:
	RCALL DEC_DIGIT
	RJMP CLEAR_BTN

CLEAR_BTN:
    CLR R16
    STS btn_flags,R16

CHECK_CLOCK:
    LDS R16,flag_1s; 1000 ms (ISR)
    CPI R16,0
    BREQ MAIN; revisar si paso 1s (flag de ISR timer)
    CLR R16
    STS flag_1s,R16; poner flag en 0 (solo entra hasta que se vuelva a activar)
    LDS R17,edit_digit
    CPI R17,0
    BRNE MAIN; si estoy editando no actualizo reloj
    RCALL UPDATE_CLOCK
    RJMP MAIN

; ========================================= INTERRUPCIONES
PCINT0_ISR: ; interrupcion botones
    PUSH R16
    IN R16,SREG
    PUSH R16; leer SREG y guardar registros en la pila 
    IN R16,PINB
    COM R16; invertir lectura botones para que sea mas facil (1 presionado)
    ANDI R16,0b00001111; pines
    STS btn_flags,R16
    POP R16
    OUT SREG,R16
    POP R16
    RETI; volver de la interrupcion 

TIMER_ISR:; interrupcion timer
    PUSH R16
    PUSH R17
    IN R17,SREG
    PUSH R17
; multiplexado
    CBI PORTC,2
    CBI PORTC,3
    CBI PORTC,4
    CBI PORTC,5
    LDS R16,current; que digito muestro
    CPI R16,0
    BREQ SHOW_DH
    CPI R16,1
    BREQ SHOW_UH
    CPI R16,2
    BREQ SHOW_DM
    RJMP SHOW_UM

SHOW_DH:
    RCALL LOAD_DH
    SBI PORTC,2; activar pin dh
    RJMP NEXT_DIG; rutina actualizar digito
SHOW_UH:
    RCALL LOAD_UH
    SBI PORTC,3
    RJMP NEXT_DIG
SHOW_DM:
    RCALL LOAD_DM
    SBI PORTC,4
    RJMP NEXT_DIG
SHOW_UM:
    RCALL LOAD_UM
    SBI PORTC,5

NEXT_DIG:
    LDS R16,current; incrementa current (para variar que digito se muestra "engañar al ojo")
    INC R16
    CPI R16,4
    BRLO SAVE_CUR
    CLR R16; reiniciar en 0
SAVE_CUR:
    STS current,R16
    LDS R16,msL; cada vez que se ejecuta timer incremento low
    INC R16
    STS msL,R16
    BRNE CHECK_SECOND
    LDS R16,msH; si ya llego al maximo msL voy a high
    INC R16
    STS msH,R16

CHECK_SECOND:; comprobar 1s
    LDS R16,msH
    CPI R16,3
    BRNE CHECK_BLINK
    LDS R16,msL
    CPI R16,232
    BRNE CHECK_BLINK; revisar high y low
    CLR R16
    STS msL,R16
    STS msH,R16
    LDI R16,1
    STS flag_1s,R16; limpiar todo 

CHECK_BLINK: ; blink 500ms
    LDS R16,blinkL
    INC R16
    STS blinkL,R16
    BRNE CHECK_BLINK2; si blink no se pasa vamos a checkblink2
    LDS R16,blinkH
    INC R16
    STS blinkH,R16 ;si no sumamos a blinkH

CHECK_BLINK2:; Puntos de hora (PC1)
    LDS R16,blinkH
    CPI R16,1
    BRNE END_ISR
    LDS R16,blinkL
    CPI R16,244
    BRNE END_ISR
    CLR R16
    STS blinkL,R16
    STS blinkH,R16
    IN R16,PORTC
    LDI R17,(1<<PC1); mascara solo ese bit
    EOR R16,R17; encender o apagar (OR)
    OUT PORTC,R16; 500 ms (blinkL 244 y blinkH 1) y reiniciar

END_ISR:;restaurar registros
    POP R17;SREG
    OUT SREG,R17
    POP R17;ISR
    POP R16;ISR (current, msLH,blink)
    RETI

; ========================================= SUBRUTINAS DE MODO
CHANGE_MODE:
    LDS R16,mode; valor actual (hora,fecha o alarma)
    INC R16; siguiente modo
    CPI R16,3; 1-2-3-1
    BRLO SAVE_MODE
    CLR R16
SAVE_MODE:
    STS mode,R16
    CLR R16
    STS edit_digit,R16; reiniciar digito a editar (cada modo tiene sus digitos)
    RCALL UPDATE_MODE_LEDS
    RET

;cargar digito que se esta editando incrementar digito y pasar al siguiente
NEXT_EDIT:
	LDS R16,mode
	CPI R16,0
	BREQ NEXT_EDIT_TIME
	CPI R16,1
	BREQ NEXT_EDIT_DATE
	CPI R16,2
	BREQ NEXT_EDIT_ALARM
	RJMP EXIT_EDIT
NEXT_EDIT_ALARM:
	LDS R16,edit_digit
	INC R16
	CPI R16,5
	BRLO SAVE_EDIT_ALARM
	CLR R16
SAVE_EDIT_ALARM:
	STS edit_digit,R16
	RJMP RESET_BLINK
NEXT_EDIT_TIME:
    LDS R16,edit_digit
    INC R16
    CPI R16,5
    BRLO SAVE_EDIT_TIME
    CLR R16
SAVE_EDIT_TIME:
    STS edit_digit,R16
    RJMP RESET_BLINK
NEXT_EDIT_DATE:
    LDS R16,edit_digit
    INC R16
    CPI R16,5
    BRLO SAVE_EDIT_DATE
    CLR R16
SAVE_EDIT_DATE:
    STS edit_digit,R16

RESET_BLINK:; reiniciar que digito se esta mostrando
    LDI R17,3
    STS current,R17
    ; reiniciar blink
    CLR R17
    STS blinkL,R17
    LDI R17,1
    STS blinkH,R17
EXIT_EDIT:
    RET

UPDATE_MODE_LEDS:; LEDS INDICADORES DE MODO 
    CBI PORTC,0; apagar todos
    CBI PORTB,4
    CBI PORTD,7
    LDS R16,mode; modo actual
; modo hora
    CPI R16,0
    BRNE CHECK_LED_DATE
    SBI PORTC,0
    RET
CHECK_LED_DATE:; modo fecha
    CPI R16,1
    BRNE CHECK_LED_ALARM
    SBI PORTB,4
    RET
CHECK_LED_ALARM:; modo alarma
    CPI R16,2
    BRNE LED_EXIT
    SBI PORTD,7
LED_EXIT:
    RET

; ========================================= SUBRUTINAS DE DISPLAY

;LOAD lee el modo luego salta a la rutina que muestra cada valor de digito segun el modo
LOAD_DH:
    LDS R16,mode
    CPI R16,0
    BREQ TIME_DH
    CPI R16,1
    BREQ DATE_DH
    RJMP ALARM_DH
TIME_DH:
    LDS R16,hour_d
    RJMP DISPLAY_DIG
DATE_DH:
    LDS R16,day_d
    RJMP DISPLAY_DIG
ALARM_DH:
    LDS R16,alarm_hour_d
    RJMP DISPLAY_DIG
LOAD_UH:
    LDS R16,mode
    CPI R16,0
    BREQ TIME_UH
    CPI R16,1
    BREQ DATE_UH
    RJMP ALARM_UH
TIME_UH:
    LDS R16,hour_u
    RJMP DISPLAY_DIG
DATE_UH:
    LDS R16,day_u
    RJMP DISPLAY_DIG
ALARM_UH:
    LDS R16,alarm_hour_u
    RJMP DISPLAY_DIG
LOAD_DM:
    LDS R16,mode
    CPI R16,0
    BREQ TIME_DM
    CPI R16,1
    BREQ DATE_DM
    RJMP ALARM_DM
TIME_DM:
    LDS R16,min_d
    RJMP DISPLAY_DIG
DATE_DM:
    LDS R16,month_d
    RJMP DISPLAY_DIG
ALARM_DM:
    LDS R16,alarm_min_d
    RJMP DISPLAY_DIG
LOAD_UM:
    LDS R16,mode
    CPI R16,0
    BREQ TIME_UM
    CPI R16,1
    BREQ DATE_UM
    RJMP ALARM_UM
TIME_UM:
    LDS R16,min_u
    RJMP DISPLAY_DIG
DATE_UM:
    LDS R16,month_u
    RJMP DISPLAY_DIG
ALARM_UM:
    LDS R16,alarm_min_u
    RJMP DISPLAY_DIG

; VISUALIZACION DISPLAY NORMAL O EDITANDO (PARPADEAR)
DISPLAY_DIG:
    PUSH R17
    PUSH R18; guardar registros que voy a usar para no alterar main o ISR
    LDS R18,edit_digit
    CPI R18,0
    BREQ SHOW_NORMAL; si no estoy editando voy a mostrar el numero sin parpadear
    LDS R17,current; que digito esta activo en el multiplexado?
    INC R17
    CP R17,R18; comparar current con el digito que se esta editando
    BRNE SHOW_NORMAL; si no es el mismo numero (los demas se muestran normal)
    LDS R17,blinkH; cargar valor (500ms)
    CPI R17,0
    BREQ BLINK_OFF; si es 0 se apaga el digito en ese instante

SHOW_NORMAL:
    RCALL SEG7; convertir valor 
    POP R18
    POP R17;restaurar registros
    RET

BLINK_OFF:; apagar digito para parpadeo (enciende de nuevo en mi ISR)
    CLR R16
	IN  R17,PORTD
	ANDI R17,0b10000000; mascara apagar todos los segmentos
	OUT PORTD,R17
    POP R18
    POP R17
    RET

; ========================================= SUBRUTINAS DE RELOJ
UPDATE_CLOCK:
    LDS R16,seg
    INC R16; suma 1 seg
    CPI R16,60
    BRLO SAVE_SEC; si no llega a 60 guardo el valor y termina mi rutina
    CLR R16
;si llega a 60 se reinician, incremento minutos y guardo mis valores (sucesivamente con horas)
SAVE_SEC:
    STS seg,R16
    CPI R16,0
    BRNE EXIT_UPDATE
    LDS R16,min_u
    INC R16
    CPI R16,10
    BRLO SAVE_MU
    CLR R16
SAVE_MU:
    STS min_u,R16
    CPI R16,0
    BRNE EXIT_UPDATE
    LDS R16,min_d
    INC R16
    CPI R16,6
    BRLO SAVE_MD
    CLR R16
SAVE_MD:
    STS min_d,R16
    CPI R16,0
    BRNE EXIT_UPDATE
    LDS R16,hour_u
    INC R16
    CPI R16,10
    BRLO SAVE_HU
    CLR R16
SAVE_HU:
    STS hour_u,R16
    CPI R16,0
    BRNE CHECK_24
    LDS R16,hour_d
    INC R16
    CPI R16,3
    BRLO SAVE_HD
    CLR R16
SAVE_HD:
    STS hour_d,R16

CHECK_24: ;verificar si llego a 24:00 para reiniciar
    LDS R18,edit_digit
    CPI R18,0
    BRNE EXIT_UPDATE;no cambiar fecha si estoy editando
    LDS R16,hour_d
    CPI R16,2
    BRNE EXIT_UPDATE
    LDS R16,hour_u
    CPI R16,4
    BRNE EXIT_UPDATE
	; EXTRA PROTECCION: solo si segundos == 0
    LDS R16,seg
    CPI R16,0
    BRNE EXIT_UPDATE
    CLR R16
    STS hour_d,R16
    STS hour_u,R16
	RCALL DATE_INCREMENT_ROUTINE

EXIT_UPDATE:
    RCALL CHECK_ALARM; luego de guardar valores revisar alarma
    RET

; ========================================= SUBRUTINAS DE FECHA

DATE_INCREMENT_ROUTINE:; unidades dias y decenas icnrementar
    LDS R16,day_u
    INC R16
    CPI R16,10
    BRLO DATE_SAVE_DAYU
    CLR R16
    STS day_u,R16
    LDS R17,day_d
    INC R17
    STS day_d,R17
    RJMP DATE_CHECK_MONTH_LIMIT
DATE_SAVE_DAYU:
    STS day_u,R16

DATE_CHECK_MONTH_LIMIT:
    RCALL DATE_VERIFY_DAY_LIMIT
    RET

; VERIFICAR LIMITE DE DIAS DEL MES
DATE_VERIFY_DAY_LIMIT:
    ; NO validar si estoy editando
    LDS R20, edit_digit
    CPI R20, 0
    BRNE DATE_EXIT_NO_VALIDATE
; evitar dia = 00
	LDS R16,day_d
	LDS R17,day_u
	OR  R16,R17
	BRNE CHECK_MONTH_ZERO
	LDI R16,1
	STS day_u,R16
	CLR R16
	STS day_d,R16
; evitar mes = 00
CHECK_MONTH_ZERO:
	LDS R18,month_d
	LDS R19,month_u
	OR  R18,R19
	BRNE CALC_DAY
	LDI R19,1
	STS month_u,R19
	CLR R19
	STS month_d,R19

;calcular dia (decena y unidad junto no como digito separado)
CALC_DAY:
	LDS R16,day_d
	MOV R18,R16
	LSL R16
	LSL R16
	LSL R16
	LSL R18; LSL multiplica x2 (lo uso para llegar a decena (*10))
	ADD R16,R18 
	LDS R17,day_u
	ADD R16,R17; sumamos con unidades
	;ver en que mes estoy
	LDS R18,month_d; (decena mes 0 o 1)
	LDS R19,month_u; (unidad mes 1 a 9)

; febrero
	CPI R18,0; decena mes
	BRNE CHECK_30
	CPI R19,2; febrero (mes 2)
	BRNE CHECK_30
	LDI R20,28; 28 dias maximo
	RJMP CHECK_LIMIT
; meses de 30 dias
CHECK_30:
	CPI R18,0; decena mes es 0 (meses de un digito)
	BRNE MONTH_31
	CPI R19,4; abril
	BREQ SET_30
	CPI R19,6; junio
	BREQ SET_30
	CPI R19,9;septiembre
	BREQ SET_30
	RJMP MONTH_31; si no es alguno de esos tiene 31 dias
SET_30:
	LDI R20,30
	RJMP CHECK_LIMIT
; meses de 31 dias
MONTH_31:
	LDI R20,31

CHECK_LIMIT: ;verificar limite dependiendo de r20 cargado
    CP R16,R20
    BRLO DATE_OK; si el dia actual es menor salta a date ok
    BREQ DATE_OK
    RCALL DATE_NEXT_MONTH_ROUTINE;; si es el mismo dia no importa si no va a esta rutina
    RCALL DATE_VERIFY_DAY_LIMIT ;revalidar dia con el nuevo mes

DATE_OK:
    RET

DATE_EXIT_NO_VALIDATE:
    RET

DATE_NEXT_MONTH_ROUTINE: ;CAMBIAR DE MES
    LDI R16,1
    STS day_u,R16
    CLR R16
    STS day_d,R16; reiniciar dia a 01
    LDS R16,month_u
    INC R16
    CPI R16,10
    BRLO SAVE_MONTH_U; incrementar unidad mes
    CLR R16
    STS month_u,R16
    LDS R17,month_d
    INC R17
    STS month_d,R17; si se paso unidad mes sumar decena
    RJMP CHECK_YEAR_LIMIT

SAVE_MONTH_U:
    STS month_u,R16
    RJMP CHECK_YEAR_LIMIT

; validar que mes este entre 01 y 12
FIX_MONTH_LIMIT:
    LDS R16,month_d
    MOV R18,R16
    LSL R16
    LSL R16
    LSL R16
    LSL R18
    ADD R16,R18
    LDS R17,month_u
    ADD R16,R17   ; R16 = mes completo
    CPI R16,13
    BRLO MONTH_OK
    LDI R17,1
    STS month_u,R17
    CLR R17
    STS month_d,R17

MONTH_OK:
    RET

CHECK_YEAR_LIMIT:
    LDS R16,month_d
    CPI R16,1
    BRNE END_MONTH
    LDS R17,month_u
    CPI R17,3
    BRNE END_MONTH; si no se ha pasado de 12 termina fecha
    LDI R16,1
    STS month_u,R16
    CLR R16
    STS month_d,R16; si no empezar en enero

END_MONTH:
	RCALL FIX_MONTH_LIMIT
    RET

; ========================================= SUBRUTINAS DE ALARMA

CHECK_ALARM:
; solo revisar al inicio del minuto
	LDS R16,seg
	CPI R16,0
	BRNE ALARM_EXIT
; si ya está activa no volver a activarla
	LDS R18,alarm_active
	CPI R18,1
	BREQ ALARM_EXIT
; comparar hora
	LDS R16,hour_d
	LDS R17,alarm_hour_d
	CP R16,R17
	BRNE ALARM_EXIT
	LDS R16,hour_u
	LDS R17,alarm_hour_u
	CP R16,R17
	BRNE ALARM_EXIT
; comparar minutos
	LDS R16,min_d
	LDS R17,alarm_min_d
	CP R16,R17
	BRNE ALARM_EXIT
	LDS R16,min_u
	LDS R17,alarm_min_u
	CP R16,R17
	BRNE ALARM_EXIT
; activar alarma (BUZZER)
	LDI R16,1
	STS alarm_active,R16
	SBI PORTB,5

ALARM_EXIT:
	RET

; ========================================= SUBRUTINAS DE INCREMENTAR 
INC_DIGIT:
    LDS R16,mode; veo en que modo estoy
    CPI R16,0
    BRNE CHECK_INC_DATE
    RJMP INC_DIGIT_TIME
CHECK_INC_DATE:
    CPI R16,1
    BRNE CHECK_INC_ALARM
    RJMP INC_DIGIT_DATE
CHECK_INC_ALARM:
    CPI R16,2
    BRNE INC_EXIT
    RJMP INC_DIGIT_ALARM

INC_EXIT:
	RET

; INCREMENTAR HORA
INC_DIGIT_TIME:
	LDS R16,edit_digit; que digito se va a incrementar
	CPI R16,0
	BREQ INC_EXIT
	CPI R16,1
	BREQ INC_HOUR_D
	CPI R16,2
	BREQ INC_HOUR_U
	CPI R16,3
	BREQ INC_MIN_D
	RJMP INC_MIN_U
INC_HOUR_D:
	LDS R17,hour_d
	INC R17
	CPI R17,3;incrementar decena de hora
	BRLO INC_HD_SAVE
	CLR R17
INC_HD_SAVE:
	STS hour_d,R17
	RJMP INC_HOUR_FIX; arreglar caso especial 23 a 00
INC_HOUR_U:
	LDS R17,hour_u
	INC R17
	LDS R18,hour_d
	CPI R18,2
	BRNE INC_HU_MAX9; si no es 2 salto 
	CPI R17,4
	BRLO INC_HU_SAVE
	;si llega a 24 regresar a 00
	CLR R17
	CLR R18
	STS hour_d,R18
	RJMP INC_HU_SAVE

INC_HU_MAX9:
	CPI R17,10
	BRLO INC_HU_SAVE
	CLR R17
INC_HU_SAVE:
	STS hour_u,R17
	RET

INC_MIN_D:
	LDS R17,min_d
	INC R17
	CPI R17,6
	BRLO INC_MD_SAVE
	CLR R17
	INC_MD_SAVE:
	STS min_d,R17
	RET
INC_MIN_U:
	LDS R17,min_u
	INC R17
	CPI R17,10
	BRLO INC_MU_SAVE
	CLR R17
INC_MU_SAVE:
	STS min_u,R17
	RET

INC_HOUR_FIX:
	LDS R17,hour_d
	CPI R17,2
	BRNE FIX_EXIT

	LDS R17,hour_u
	CPI R17,4
	BRLO FIX_EXIT

	LDI R17,3
	STS hour_u,R17

FIX_EXIT:
	RET

; INCREMENTAR FECHA
INC_DIGIT_DATE:
	LDS R16,edit_digit
	CPI R16,0
	BRNE INC_DATE_CHECK1
	RJMP INC_EXIT
INC_DATE_CHECK1:
	CPI R16,1
	BRNE INC_DATE_CHECK2
	RJMP INC_DAY_D
INC_DATE_CHECK2:
	CPI R16,2
	BRNE INC_DATE_CHECK3
	RJMP INC_DAY_U
INC_DATE_CHECK3:
	CPI R16,3
	BRNE INC_DATE_CHECK4
	RJMP INC_MONTH_D
INC_DATE_CHECK4:
	RJMP INC_MONTH_U
INC_DAY_D:
    LDS R17,day_d
    INC R17
    CPI R17,4
    BRLO INC_DAY_D_SAVE
    CLR R17
INC_DAY_D_SAVE:
    STS day_d,R17
    RCALL DATE_VERIFY_DAY_LIMIT
    RET
INC_DAY_U:
    LDS R17,day_u
    INC R17
    CPI R17,10
    BRLO INC_DAY_U_SAVE
    CLR R17
INC_DAY_U_SAVE:
    STS day_u,R17
    RCALL DATE_VERIFY_DAY_LIMIT
    RET
INC_MONTH_D:
    LDS R17,month_d
    INC R17
    CPI R17,2
    BRLO INC_MONTH_D_SAVE
    CLR R17
INC_MONTH_D_SAVE:
    STS month_d,R17
	RCALL FIX_MONTH_LIMIT
    RCALL DATE_VERIFY_DAY_LIMIT
    RET
INC_MONTH_U:
    LDS R17,month_u
    INC R17
    CPI R17,10
    BRLO INC_MONTH_U_SAVE
    CLR R17
INC_MONTH_U_SAVE:
    STS month_u,R17
	RCALL FIX_MONTH_LIMIT
    RCALL DATE_VERIFY_DAY_LIMIT
    RET

; ========================================= SUBRUTINAS DECREMENTAR
DEC_DIGIT:
    LDS R16,mode
    CPI R16,0
    BRNE DEC_CHECK_DATE
    RJMP DEC_DIGIT_TIME
DEC_CHECK_DATE:
    CPI R16,1
    BRNE DEC_CHECK_ALARM
    RJMP DEC_DIGIT_DATE
DEC_CHECK_ALARM:
    CPI R16,2
    BRNE DEC_EXIT_LOCAL
    RJMP DEC_DIGIT_ALARM
DEC_EXIT_LOCAL:
    RJMP DEC_EXIT
; DECREMENTAR HORA
DEC_DIGIT_TIME:
    LDS R16,edit_digit
    CPI R16,0
    BRNE DEC_CHECK_HD
    RJMP DEC_EXIT
DEC_CHECK_HD:
    CPI R16,1
    BRNE DEC_CHECK_HU
    RJMP DEC_HOUR_D
DEC_CHECK_HU:
    CPI R16,2
    BRNE DEC_CHECK_MD
    RJMP DEC_HOUR_U
DEC_CHECK_MD:
    CPI R16,3
    BRNE DEC_MIN_U
    RJMP DEC_MIN_D
DEC_HOUR_D:
    LDS R17,hour_d
    CPI R17,0; verificar limite
    BRNE DEC_HD_STEP; decrementar el valor
    LDI R17,2
    RJMP DEC_HD_SAVE
DEC_HD_STEP:
    DEC R17
DEC_HD_SAVE:
    STS hour_d,R17
    RJMP DEC_HOUR_FIX
DEC_HOUR_U:
    LDS R17,hour_u
    CPI R17,0
    BRNE DEC_HU_STEP
    LDS R18,hour_d
    CPI R18,2
    BRNE DEC_HU_9
    LDI R17,3
    RJMP DEC_HU_SAVE
DEC_HU_9:
    LDI R17,9
    RJMP DEC_HU_SAVE
DEC_HU_STEP:
    DEC R17
DEC_HU_SAVE:
    STS hour_u,R17
    RJMP DEC_EXIT
DEC_MIN_D:
    LDS R17,min_d
    CPI R17,0
    BRNE DEC_MD_STEP
    LDI R17,5
    RJMP DEC_MD_SAVE
DEC_MD_STEP:
    DEC R17
DEC_MD_SAVE:
    STS min_d,R17
    RJMP DEC_EXIT
DEC_MIN_U:
    LDS R17,min_u
    CPI R17,0
    BRNE DEC_MU_STEP
    LDI R17,9
    RJMP DEC_MU_SAVE
DEC_MU_STEP:
    DEC R17
DEC_MU_SAVE:
    STS min_u,R17
    RJMP DEC_EXIT
DEC_HOUR_FIX:
    LDS R17,hour_d
    CPI R17,2
    BREQ CHECK_U; si =2 seguimos
    RJMP DEC_EXIT; si no, saltamos largo
CHECK_U:
    LDS R17,hour_u
    CPI R17,4
    BRLO DEC_EXIT
    LDI R17,3
    STS hour_u,R17
    RJMP DEC_EXIT

; DECREMENTAR FECHA
DEC_DIGIT_DATE:
    LDS R16,edit_digit
    CPI R16,0
    BREQ DEC_EXIT
    CPI R16,1
    BREQ DEC_DAY_D
    CPI R16,2
    BREQ DEC_DAY_U
    CPI R16,3
    BREQ DEC_MONTH_D
    RJMP DEC_MONTH_U
DEC_DAY_D:
    LDS R17,day_d
    CPI R17,0
    BRNE DEC_DAY_D_STEP
    LDI R17,3
    RJMP DEC_DAY_D_SAVE
DEC_DAY_D_STEP:
    DEC R17
DEC_DAY_D_SAVE:
    STS day_d,R17
    RCALL DATE_VERIFY_DAY_LIMIT
    RJMP DEC_EXIT
DEC_DAY_U:
    LDS R17,day_u
    CPI R17,0
    BRNE DEC_DAY_U_STEP
    LDI R17,9
    RJMP DEC_DAY_U_SAVE
DEC_DAY_U_STEP:
    DEC R17
DEC_DAY_U_SAVE:
    STS day_u,R17
    RCALL DATE_VERIFY_DAY_LIMIT
    RJMP DEC_EXIT
DEC_MONTH_D:
    LDS R17,month_d
    CPI R17,0
    BRNE DEC_MONTH_D_STEP
    LDI R17,1
    RJMP DEC_MONTH_D_SAVE
DEC_MONTH_D_STEP:
    DEC R17
DEC_MONTH_D_SAVE:
    STS month_d,R17
	RCALL FIX_MONTH_LIMIT 
    RCALL DATE_VERIFY_DAY_LIMIT
    RJMP DEC_EXIT
DEC_MONTH_U:
    LDS R17,month_u
    CPI R17,0
    BRNE DEC_MONTH_U_STEP
    LDI R17,9
    RJMP DEC_MONTH_U_SAVE
DEC_MONTH_U_STEP:
    DEC R17
DEC_MONTH_U_SAVE:
    STS month_u,R17
	RCALL FIX_MONTH_LIMIT 
    RCALL DATE_VERIFY_DAY_LIMIT
DEC_EXIT:
    RET

; ========================================= SUBRUTINAS INC Y DEC ALARMA
INC_DIGIT_ALARM:
	LDS R16,edit_digit
	CPI R16,0
	BRNE INC_ALARM_CHECK1
	RJMP INC_EXIT_2
INC_ALARM_CHECK1:
	CPI R16,1
	BRNE INC_ALARM_CHECK2
	RJMP INC_A_HD
INC_ALARM_CHECK2:
	CPI R16,2
	BRNE INC_ALARM_CHECK3
	RJMP INC_A_HU
INC_ALARM_CHECK3:
	CPI R16,3
	BRNE INC_ALARM_CHECK4
	RJMP INC_A_MD
INC_ALARM_CHECK4:
	CPI R16,4
	BRNE INC_ALARM_EXIT
	RJMP INC_A_MU
INC_ALARM_EXIT:
	RJMP INC_EXIT_2

INC_A_HD:
	LDS R17,alarm_hour_d
	INC R17
	CPI R17,3
	BRLO INC_A_HD_SAVE
	CLR R17
INC_A_HD_SAVE:
	STS alarm_hour_d,R17
	RJMP INC_A_FIX
INC_A_HU:
	LDS R17,alarm_hour_u
	INC R17
	LDS R18,alarm_hour_d
	CPI R18,2
	BRNE INC_A_HU_MAX9
	CPI R17,4
	BRLO INC_A_HU_SAVE
	CLR R17
	RJMP INC_A_HU_SAVE
INC_A_HU_MAX9:
	CPI R17,10
	BRLO INC_A_HU_SAVE
	CLR R17
INC_A_HU_SAVE:
	STS alarm_hour_u,R17
	RJMP INC_EXIT_2
INC_A_MD:
	LDS R17,alarm_min_d
	INC R17
	CPI R17,6
	BRLO INC_A_MD_SAVE
	CLR R17
INC_A_MD_SAVE:
	STS alarm_min_d,R17
	RJMP INC_EXIT_2
INC_A_MU:
	LDS R17,alarm_min_u
	INC R17
	CPI R17,10
	BRLO INC_A_MU_SAVE
	CLR R17
INC_A_MU_SAVE:
	STS alarm_min_u,R17
	RJMP INC_EXIT_2
INC_A_FIX:
	LDS R17,alarm_hour_d
	CPI R17,2
	BRNE INC_EXIT_2
	LDS R17,alarm_hour_u
	CPI R17,4
	BRLO INC_EXIT_2
	LDI R17,3
	STS alarm_hour_u,R17
INC_EXIT_2:
	RET
DEC_DIGIT_ALARM:
	LDS R16,edit_digit
	CPI R16,0
	BRNE DEC_ALARM_CHECK1
	RJMP DEC_EXIT_2
DEC_ALARM_CHECK1:
	CPI R16,1
	BRNE DEC_ALARM_CHECK2
	RJMP DEC_A_HD
DEC_ALARM_CHECK2:
	CPI R16,2
	BRNE DEC_ALARM_CHECK3
	RJMP DEC_A_HU
DEC_ALARM_CHECK3:
	CPI R16,3
	BRNE DEC_ALARM_CHECK4
	RJMP DEC_A_MD
DEC_ALARM_CHECK4:
	CPI R16,4
	BRNE DEC_ALARM_EXIT
	RJMP DEC_A_MU
DEC_ALARM_EXIT:
	RJMP DEC_EXIT_2
DEC_A_HD:
	LDS R17,alarm_hour_d
	CPI R17,0
	BRNE DEC_A_HD_STEP
	LDI R17,2
	RJMP DEC_A_HD_SAVE
DEC_A_HD_STEP:
	DEC R17
DEC_A_HD_SAVE:
	STS alarm_hour_d,R17
	RJMP DEC_A_FIX
DEC_A_HU:
	LDS R17,alarm_hour_u
	CPI R17,0
	BRNE DEC_A_HU_STEP
	LDS R18,alarm_hour_d
	CPI R18,2
	BRNE DEC_A_HU_9
	LDI R17,3
	RJMP DEC_A_HU_SAVE
DEC_A_HU_9:
	LDI R17,9
	RJMP DEC_A_HU_SAVE
DEC_A_HU_STEP:
	DEC R17
DEC_A_HU_SAVE:
	STS alarm_hour_u,R17
	RJMP DEC_EXIT_2
DEC_A_MD:
	LDS R17,alarm_min_d
	CPI R17,0
	BRNE DEC_A_MD_STEP
	LDI R17,5
	RJMP DEC_A_MD_SAVE
DEC_A_MD_STEP:
	DEC R17
DEC_A_MD_SAVE:
	STS alarm_min_d,R17
	RJMP DEC_EXIT_2
DEC_A_MU:
	LDS R17,alarm_min_u
	CPI R17,0
	BRNE DEC_A_MU_STEP
	LDI R17,9
	RJMP DEC_A_MU_SAVE
DEC_A_MU_STEP:
	DEC R17
DEC_A_MU_SAVE:
	STS alarm_min_u,R17
	RJMP DEC_EXIT_2
DEC_A_FIX:
	LDS R17,alarm_hour_d
	CPI R17,2
	BRNE DEC_EXIT_2
	LDS R17,alarm_hour_u
	CPI R17,4
	BRLO DEC_EXIT_2
	LDI R17,3
	STS alarm_hour_u,R17
DEC_EXIT_2:
	RET

; ========================================= VALORES DISPLAY
SEG7:
    PUSH ZL
    PUSH ZH
    LDI ZH,HIGH(TS7*2)
    LDI ZL,LOW(TS7*2)
    ADD ZL,R16
    ADC ZH,R1
    LPM R16,Z
    IN  R17,PORTD
	ANDI R17,0b10000000
	OR   R16,R17
	OUT  PORTD,R16
    POP ZH
    POP ZL
    RET
