.include "m32def.inc"

;=================== macros and definitions ============================
.MACRO init_stack
    ldi r16,HIGH(RAMEND)
    out SPH,r16
    ldi r16,Low(RAMEND)
    out SPL,r16
.ENDMACRO

.def timeL = r24
.def timeH = r25
.def bitcnt = r18
.def data = r19
.def state = r17   ; 0=idle, 1=receiving
;=======================================================================

;====================== initalizations =================================
INIT_TIMER1:                ; Timer 1 intializior
    ldi r16, (1<<CS11)      ; prescaler = 8
    out TCCR1B, r16

    clr r16
    out TCNT1H, r16
    out TCNT1L, r16
ret

INIT_INT0:                  ; External Interrupt 0 intializior
    cbi DDRD,2              ; set INT0 as an interrupt input 
    sbi PORTD,2             ; enable internal pull-up (not required but preferred)

    ldi r16, (1<<ISC01)     ; falling edge
    out MCUCR, r16

    ldi r16, (1<<INT0)
    out GICR, r16           ; enable INT0
ret
;=======================================================================

;===========================EEPROM routines==============================
WRITE_EEPROM_BYTE:
    sbis EECR, EEWE
    rjmp WRITE_EEPROM_BYTE      ; check EEWE to see if last write is finished

    ; make r20 an address input register to the EEPROM Address Low Register
    out EEARL,r20

    ; make r21 an data input register to the EEPROM Data REgister
    out EEDR,r21

    sbi EECR,EEMWE
    sbi EECR,EEWE

    RET

READ_EEPROM_BYTE:
    sbic EECR, EEWE
    rjmp READ_EEPROM_BYTE ; check EEWE to see if last write is finished
    
    ; make r20 an address input register to the EEPROM Address Low Register
    out EEARL,r20

    sbi EECR,EERE ; set Read Enable to one

    ; make r21 an data output register from the EEPROM Data REgister
    in r21,EEDR

    RET
;========================================================================

;======================== memory allocations ===========================
.DSEG                       ; store input in SRAM
    INPUT_BUF: .BYTE 6
    INDEX:     .BYTE 1
    FLAG_DONE: .BYTE 1

.ESEG                       ; store password in EEPROM
    .ORG 0x00
    PASSWORD:
        .DB 0x46, 0x47, 0x43, 0x46, 0x44, 0x44

.CSEG                       
    .ORG 0x00               ; wake-up ROM reset location
    jmp MAIN                ; bypass interrupt vector table
    
    .ORG 0x02               
    jmp INT0_ISR            ; redirect the vector number to it's handler

.ORG $100
;=======================================================================

MAIN:                       ; enable interrupt flags
    init_stack
    rcall INIT_TIMER1
    rcall INIT_INT0
    
    clr r16
    sts INDEX, r16
    sts FLAG_DONE, r16

    SEI                     ; enable interrupt flag in SREG
    
    MAIN_LOOP: 
        lds r16, FLAG_DONE
        cpi r16, 1
        BRNE MAIN_LOOP

        rcall CHECK_PASSWORD

        clr r16
        sts FLAG_DONE, r16
        sts INDEX, r16
        
        rjmp MAIN_LOOP

    CHECK_PASSWORD:
        ldi r16, 0

        CHECK_LOOP:
            cpi r16, 6
            breq PASSWORD_OK
            clr r1

            ; read input
            ldi ZL, LOW(INPUT_BUF)
            ldi ZH, HIGH(INPUT_BUF)
            add ZL, r16
            adc ZH, r1
            ld r17, Z

            ; read EEPROM
            mov r20, r16
            rcall READ_EEPROM_BYTE
            mov r18, r21

            cp r17, r18
            brne PASSWORD_FAIL

            inc r16
            rjmp CHECK_LOOP

    PASSWORD_OK:
        ldi r16, 0x07      ; PB0=LED_G, PB1=LED_R, PB2=Buzzer
        out DDRB, r16

        sbi PORTB, 0     ; LED GREEN
        cbi PORTB, 1
        ret

    PASSWORD_FAIL:
        sbi PORTB, 1     ; LED RED
        cbi PORTB, 0
        sbi PORTB, 2     ; BUZZER
        ret

;======================Interrupt service routine===========================
INT0_ISR:
    push r16
    push r17
    push r18
    push r19
    push r20
    push r24
    push r25

    in timeL, TCNT1L
    in timeH, TCNT1H

    clr r16
    out TCNT1H, r16
    out TCNT1L, r16

    cpi timeH,HIGH(8000)
    BRSH START_INT
    cpi state,1
    BRNE EXIT_ISR

    cpi timeH,HIGH(1000)
    BRSH BIT_ONE

    BIT_ZERO:
        lsl data
        inc bitcnt
        rjmp CHECK_DONE

    BIT_ONE:
        lsl data
        ori data,1
        inc bitcnt
    
    CHECK_DONE:
        cpi bitcnt, 8
        brne EXIT_ISR
    
        mov r20,data
        lds r21, INDEX
        cpi r21,6
        BRSH EXIT_ISR

        ldi ZL, LOW(INPUT_BUF)
        ldi ZH, HIGH(INPUT_BUF)

        add ZL, r21
        adc ZH, r1
        st Z, r20

        inc r21
        sts INDEX, r21

        cpi r21, 6
        brne EXIT_ISR

        ldi r16, 1
        sts FLAG_DONE, r16

        clr state
        clr bitcnt
        rjmp EXIT_ISR

    START_INT:
        ldi state,1
        clr bitcnt
        clr data
        rjmp EXIT_ISR

    EXIT_ISR:
        pop r25
        pop r24
        pop r20
        pop r19
        pop r18
        pop r17
        pop r16
        RETI
;========================================================================