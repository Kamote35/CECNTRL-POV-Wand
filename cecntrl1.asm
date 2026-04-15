; Device: PIC16F628A
; Function: POV Display - 20 Character Message ("YOU PASSED THE COURS")
; Inputs: Pin 17 (RA0) Left Piezo, Pin 18 (RA1) Right Piezo
; Outputs: PORTB (Pins 6-13) - 8 LEDs

    list      p=16f628a
    #include <p16f628a.inc>

    __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

    ; Variables
    CBLOCK 0x20
        SPEED_VAL     ; Timer0 value used to scale display delay
        DIRECTION     ; 0 = Forward, 1 = Reverse
        COL_INDEX     ; Current column being displayed (0 to 99)
        DELAY_CNT1    ; Outer delay loop counter (Speed scaled)
        DELAY_CNT2    ; Inner delay loop counter
    ENDC

    ORG     0x000

; Macros
INIT:
    MOVLW   0x07        ; Turn off analog comparators
    MOVWF   CMCON

    BSF     STATUS, RP0 ; Bank 1
    MOVLW   b'00000011' ; RA0, RA1 as inputs
    MOVWF   TRISA
    CLRF    TRISB       ; PORTB all outputs for LEDs
    
    ; Setup TIMER0 Prescaler 1:256
    MOVLW   b'11010111'
    MOVWF   OPTION_REG  
    BCF     STATUS, RP0 ; Bank 0
    CLRF    PORTB

; ========================================================
; SENSOR POLLING 
; ========================================================
WAIT_SWIPE:
    CLRF    PORTB       ; Ensure LEDs are off while waiting
    BTFSC   PORTA, 0    
    GOTO    LEFT_HIT    ; Left piezo triggered
    BTFSC   PORTA, 1    
    GOTO    RIGHT_HIT   ; Right piezo triggered
    GOTO    WAIT_SWIPE

LEFT_HIT:
    CLRF    DIRECTION   ; Set forward direction
    CLRF    TMR0        ; Start timing
WAIT_R:
    BTFSC   PORTA, 1    ; Wait for right piezo
    GOTO    START_DISPLAY
    GOTO    WAIT_R

RIGHT_HIT:
    MOVLW   0x01
    MOVWF   DIRECTION   ; Set reverse direction
    CLRF    TMR0        ; Start timing
WAIT_L:
    BTFSC   PORTA, 0    ; Wait for left piezo
    GOTO    START_DISPLAY
    GOTO    WAIT_L

; ========================================================
; DISPLAY PREP
; ========================================================
START_DISPLAY:
    ; Save the speed. (If Timer0 is 0, default it to 1 to prevent infinite loop)
    MOVF    TMR0, W
    BTFSC   STATUS, Z
    MOVLW   0x01
    MOVWF   SPEED_VAL

    ; Check direction to set starting index
    BTFSS   DIRECTION, 0
    GOTO    SETUP_FORWARD
    GOTO    SETUP_REVERSE

SETUP_FORWARD:
    CLRF    COL_INDEX   ; Start at index 0
    GOTO    DISPLAY_LOOP

SETUP_REVERSE:
    MOVLW   d'99'       ; 20 chars * 5 cols = 100. Max index is 99.
    MOVWF   COL_INDEX

; ========================================================
; MAIN DISPLAY LOOP
; ========================================================
DISPLAY_LOOP:
    ; 1. Fetch the column data from the table
    MOVF    COL_INDEX, W
    CALL    MESSAGE_TABLE
    MOVWF   PORTB       ; Output column pattern to LEDs

    ; 2. Call Variable Delay (Scales with SPEED_VAL)
    CALL    VAR_DELAY

    ; 3. Turn LEDs off briefly to create space between columns
    CLRF    PORTB
    CALL    TINY_DELAY

    ; 4. Update the Index based on Direction
    BTFSS   DIRECTION, 0
    GOTO    INC_INDEX
    GOTO    DEC_INDEX

INC_INDEX:
    INCF    COL_INDEX, F
    MOVLW   d'100'      ; Did we reach 100?
    SUBWF   COL_INDEX, W
    BTFSC   STATUS, Z
    GOTO    WAIT_SWIPE  ; Message done, wait for next swipe
    GOTO    DISPLAY_LOOP

DEC_INDEX:
    MOVF    COL_INDEX, W ; Check if index is already 0
    BTFSC   STATUS, Z
    GOTO    WAIT_SWIPE   ; Message done
    DECF    COL_INDEX, F
    GOTO    DISPLAY_LOOP

; ========================================================
; VARIABLE DELAY ROUTINE (SCALED BY SPEED)
; ========================================================
VAR_DELAY:
    ; This delay dynamically scales based on the timer value captured
    MOVF    SPEED_VAL, W
    MOVWF   DELAY_CNT1
OUTER_LOOP:
    MOVLW   d'20'       ; Adjust this constant to tune the baseline width of letters
    MOVWF   DELAY_CNT2
INNER_LOOP:
    NOP
    DECFSZ  DELAY_CNT2, F
    GOTO    INNER_LOOP
    DECFSZ  DELAY_CNT1, F
    GOTO    OUTER_LOOP
    RETURN

TINY_DELAY:
    ; A very short static delay to separate individual columns slightly
    MOVLW   d'15'
    MOVWF   DELAY_CNT2
TINY_LOOP:
    DECFSZ  DELAY_CNT2, F
    GOTO    TINY_LOOP
    RETURN

; ========================================================
; 5x8 CHARACTER LOOKUP TABLE (105 BYTES)
; Message: "YOU PASSED THE COURS"
; ========================================================
MESSAGE_TABLE:
    ; NOTE: Must be placed in the first 256 bytes of memory (Page 0) 
    ; or PCLATH must be managed.
    ADDWF   PCL, F

    ; Character 1: 'Y'
    RETLW   b'00000011' 
    RETLW   b'00000100' 
    RETLW   b'01111000' 
    RETLW   b'00000100' 
    RETLW   b'00000011' 

    ; Character 2: 'O'
    RETLW   b'00111110'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'00111110'

    ; Character 3: 'U'
    RETLW   b'00111111'
    RETLW   b'01000000'
    RETLW   b'01000000'
    RETLW   b'01000000'
    RETLW   b'00111111'

    ; Character 4: ' ' (Space)
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'

    ; Character 5: 'P'
    RETLW   b'01111111'
    RETLW   b'00001001'
    RETLW   b'00001001'
    RETLW   b'00001001'
    RETLW   b'00000110'

    ; Character 6: 'A'
    RETLW   b'01111110'
    RETLW   b'00001001'
    RETLW   b'00001001'
    RETLW   b'00001001'
    RETLW   b'01111110'

    ; Character 7: 'S'
    RETLW   b'00100110'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'00110010'

    ; Character 8: 'S'
    RETLW   b'00100110'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'00110010'

    ; Character 9: 'E'
    RETLW   b'01111111'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01000001'

    ; Character 10: 'D'
    RETLW   b'01111111'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'00111110'

    ; Character 11: ' ' (Space)
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'

    ; Character 12: 'T'
    RETLW   b'00000001'
    RETLW   b'00000001'
    RETLW   b'01111111'
    RETLW   b'00000001'
    RETLW   b'00000001'

    ; Character 13: 'H'
    RETLW   b'01111111'
    RETLW   b'00001000'
    RETLW   b'00001000'
    RETLW   b'00001000'
    RETLW   b'01111111'

    ; Character 14: 'E'
    RETLW   b'01111111'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01000001'

    ; Character 15: ' ' (Space)
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'
    RETLW   b'00000000'

    ; Character 16: 'C'
    RETLW   b'00111110'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'00100010'

    ; Character 17: 'O'
    RETLW   b'00111110'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'01000001'
    RETLW   b'00111110'

    ; Character 18: 'U'
    RETLW   b'00111111'
    RETLW   b'01000000'
    RETLW   b'01000000'
    RETLW   b'01000000'
    RETLW   b'00111111'

    ; Character 19: 'R'
    RETLW   b'01111111'
    RETLW   b'00001001'
    RETLW   b'00011001'
    RETLW   b'00101001'
    RETLW   b'01100110'

    ; Character 20: 'S'
    RETLW   b'00100110'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'01001001'
    RETLW   b'00110010'

    ; End Padding
    RETLW   b'00000000' 
    RETURN

    END
