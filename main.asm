;
; Flex Page ASM.asm
;
; Created: 2018-04-30 7:59:48 PM
; Author : Ethan Peterson
;
#include "prescalers.h"
#define F_CPU 8000000UL ; Define CPU frequency

.cseg
	.org 0x0000
		rjmp reset
	.org 0x0020
		rjmp TIM0_OVF
	.org 0x002A
		rjmp ADC_Complete

.org 0x0040 ; start past interrupt vector table

.equ data = 3 ; PORTB
.equ latch = 2
.equ clk = 1

.equ strobe = 0 ; PORTB
.equ resetPin = 7 ; PORTD 

.def cols = r16
.def rows = r17
.def reading = r18
.def working = r19
.def currentBand = r25
.def currentCol = r24

reset:
	cli ; disable interrupts while they are being set up
	ldi currentCol, 1
	rcall initPins
	rcall ADCInit
	rcall T0Init
	rcall initMSG
	sei ; enable interrupts after they have been configured
	rjmp wait ; jump into the main code

; Replace with your application code
.MACRO shiftOut ; MSBFIRST Shiftout function handling both row and column registers (16 pins)
	cbi PORTB, latch
	; handle shifting data

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 7 ; skip if bit in register passed to macro is cleared
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 6 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 5
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 4 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 3 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 2 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 1
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @0, 0 
	sbi PORTB, data
	sbi PORTB, clk

	; shift data for second shift register
	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 7 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 6
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 5 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 4 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 3 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 2 
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 1
	sbi PORTB, data
	sbi PORTB, clk

	cbi PORTB, clk
	cbi PORTB, data
	sbrc @1, 0
	sbi PORTB, data
	sbi PORTB, clk

	sbi PORTB, latch
.ENDMACRO

wait: ; full equalizer code takes place within interrupt service routines
	rjmp wait


initPins: ; set I/O pins being used to output
	sbi DDRB, data
	sbi DDRB, latch
	sbi DDRB, clk
	sbi DDRB, strobe
	sbi DDRD, resetPin
	ret

showBand: ; takes mapped MSGEQ7 reading and places it in the right column of LED matrix
	clr rows

	cpi reading, 5 ; test the reading value and branch to a label to enable that many LEDs in the corresponding column on the matrix
	breq rows_5

	cpi reading, 4
	breq rows_4

	cpi reading, 3
	breq rows_3

	cpi reading, 2
	breq rows_2

	cpi reading, 1
	breq rows_1

	cpi reading, 0
	breq rows_0
	ser rows
	rjmp end

	rows_5:
		sbr rows, 1 << 5
		sbr rows, 1 << 4
		sbr rows, 1 << 3
		sbr rows, 1 << 2
		sbr rows, 1 << 1
		sbr rows, 1 << 0
		rjmp end
	rows_4:
		sbr rows, 1 << 4
		sbr rows, 1 << 3
		sbr rows, 1 << 2
		sbr rows, 1 << 1
		sbr rows, 1 << 0
		rjmp end
	rows_3:
		sbr rows, 1 << 3
		sbr rows, 1 << 2
		sbr rows, 1 << 1
		sbr rows, 1 << 0
		rjmp end
	rows_2:
		sbr rows, 1 << 2
		sbr rows, 1 << 1
		sbr rows, 1 << 0
		rjmp end
	rows_1:
		sbr rows, 1 << 1
		sbr rows, 1 << 0
		rjmp end
	rows_0:
		sbr rows, 1 << 0
		rjmp end
	end:
	com rows
	shiftOut rows, currentCol
	ret

ADCInit:
	ser r16 ; set all bits in r16
	ldi r16, (1 << REFS0) | (1 << ADLAR)
	sts ADMUX, r16
	; Enable, start dummy conversion, enable timer as trigger, prescaler
	ldi r16, (1 << ADEN) | (1 << ADSC) | (1 << ADATE) | (1 << ADIE) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
	sts ADCSRA, r16
	ldi r16, 1 << ADTS2
	sts ADCSRB, r16
dummy:
	lds r16, ADCSRA
	andi r16,  1 << ADIF
	breq dummy
	ret

T0Init: ; initialize T0 interrupt to schedule ADC conversions
	clr r16
	out TCCR0A, r16 ; normal mode OC0A/B disconnected
	ldi r16, T0ps8 ; 
	out TCCR0B, r16
	ldi r16, 1 << TOIE0 ; Timer interrupt enable
	sts TIMSK0, r16 ; output to mask register to
	ret

TIM0_OVF:
	cbi PORTB, strobe ; make strobe low to grab a frequency band
	rcall delay ; let MSG output settle
	lds r16, ADCSRA ; start an ADC conversion
	sbr r16, 1 << ADSC ; set the required bit
	sts ADCSRA, r16
	reti

ADC_Complete: ; ISR for when a Analog to Digital Conversion completes
	lds reading, ADCH ; grab ADC reading and place in gp reg
	; map reading value to a value from 0 - 5
	ldi r20, 6
	mul r20, reading
	mov reading, r1 ; load mapped value back into reading register
	rcall showBand ; show the frequency band at the relevant column on the LED Matrix using the updated reading value
	sbi PORTB, strobe ; pulse strobe pin to grab new frequency band
	inc currentBand
	lsl currentCol ; shift the column bit left to move to the next column

	cpi currentBand, 7 ; check if all the bands have been shown and reset the loop if so
	breq clear
	reti

	clear: ; reset MSG after reading all 7 frequency bands
	sbi PORTD, resetPin
	cbi PORTD, resetPin
	ldi currentCol, 1 ; reset col so shifting to the correct column on the matrix can continue
	clr currentBand
	reti

initMSG: ; prep MSGEQ7 to have to give audio readings in the ADC ISR
	cbi PORTD, resetPin
	sbi PORTB, strobe
	ret

delay: ; 22 uS delay for reading from the MSGEQ7
	ldi  r21, 117
L1: dec  r21
    brne L1
    nop
	ret