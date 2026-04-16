; Device: PIC16F628A
; Function: POV Display
; Inputs: Pin 17 (RA0) Left Piezo, Pin 18 (RA1) Right Piezo
; Outputs: PORTB (Pins 6-13) - 8 LEDs

    list      p=16f628a
    #include <p16f628a.inc>

    __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

    ; Variables
    CBLOCK 0x20
        SPEED_VAL     ; Timer0 value used to scale display delay
        DIRECTION     ; 0 = Forward, 1 = Reverse
        COL_INDEX     ; Current column being displayed
        DELAY_CNT1    ; Outer delay loop counter (Speed scaled)
        DELAY_CNT2    ; Inner delay loop counter
    ENDC

    ORG     0x000

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
; SENSOR POLLING (WAIT FOR SWIPE)
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
; DISPLAY PREPARATION
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
    MOVLW   d'24'       ; 5 chars * 5 cols = 25. Max index is 24.
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
    MOVLW   d'25'       ; Did we reach end of table? (25 bytes total)
    SUBWF   COL_INDEX, W
    BTFSC   STATUS, Z
    GOTO    END_SWIPE   
    GOTO    DISPLAY_LOOP

DEC_INDEX:
    MOVF    COL_INDEX, W ; Check if index is already 0
    BTFSC   STATUS, Z
    GOTO    END_SWIPE    
    DECF    COL_INDEX, F
    GOTO    DISPLAY_LOOP

; ========================================================
; DEBOUNCE / LOCKOUT ROUTINE
; ========================================================
END_SWIPE:
    ; Stage 1: Blind lockout delay (~100ms at 4MHz)
    MOVLW   d'130'
    MOVWF   DELAY_CNT1
LOCKOUT_OUTER:
    CLRF    DELAY_CNT2      ; 256 loops
LOCKOUT_INNER:
    NOP
    DECFSZ  DELAY_CNT2, F
    GOTO    LOCKOUT_INNER
    DECFSZ  DELAY_CNT1, F
    GOTO    LOCKOUT_OUTER

    ; Stage 2: Wait until both sensors are definitively LOW
WAIT_RELEASE:
    BTFSC   PORTA, 0
    GOTO    WAIT_RELEASE    ; RA0 is still bouncing/high, keep waiting
    BTFSC   PORTA, 1
    GOTO    WAIT_RELEASE    ; RA1 is still bouncing/high, keep waiting

    ; It is now safe to look for a completely new swipe
    GOTO    WAIT_SWIPE

; ========================================================
; VARIABLE DELAY ROUTINE (SCALED BY SPEED)
; ========================================================
VAR_DELAY:
    MOVF    SPEED_VAL, W
    MOVWF   DELAY_CNT1
OUTER_LOOP:
    MOVLW   d'2'        ; <--- FIXED! A value of 2-5 is usually good for POV width
    MOVWF   DELAY_CNT2
INNER_LOOP:
    NOP
    DECFSZ  DELAY_CNT2, F
    GOTO    INNER_LOOP
    DECFSZ  DELAY_CNT1, F
    GOTO    OUTER_LOOP
    RETURN

TINY_DELAY:
    MOVLW   d'10'       ; <--- FIXED! Short static gap between LED columns
    MOVWF   DELAY_CNT2
TINY_LOOP:
    DECFSZ  DELAY_CNT2, F
    GOTO    TINY_LOOP   ; <--- FIXED: Uncommented!
    RETURN

; ========================================================
; 5x8 CHARACTER LOOKUP TABLE (25 BYTES)
; Message: "YOU  "
; ========================================================
MESSAGE_TABLE:
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

    ; End Padding
    RETLW   b'00000000' 
    RETLW   b'00000000' 
    RETLW   b'00000000' 
    RETLW   b'00000000' 
    RETLW   b'00000000'
