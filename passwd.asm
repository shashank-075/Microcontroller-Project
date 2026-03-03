$NOMOD51
$INCLUDE (REG51.INC)

CSEG AT 0000H
    LJMP MAIN

; Interrupt Vector Table
CSEG AT 000BH        ; Timer 0 Interrupt Vector
    LJMP TIMER0_ISR

CSEG AT 0030H

ACTUAL_PASS    DATA    30H      ; Stores "1234" 
ENTERED_PASS   DATA    34H      ; User input buffer (4 bytes)
N              DATA    38H      ; Character counter
WRONG_ATT      DATA    39H      ; Wrong password attempts

; System Flags
KEY_READY_FLAG BIT     20H.0    ; Key ready for processing

; Timing Counters
SCAN_COUNT     DATA    3AH      ; Keypad scan counter (10ms)

; Key States
LAST_KEY       DATA    3CH      ; Last detected key
CURRENT_KEY    DATA    3DH      ; Current key

MAIN:
    MOV SP, #60H         ; Initialize stack pointer
    LCALL INIT_TIMERS    ; Setup timer interrupts first
    LCALL SYSTEM_INIT    ; Initialize hardware
    LCALL INIT_VARIABLES ; Initialize variables
    
MAIN_LOOP:
    ; Check for keypad events
    JB KEY_READY_FLAG, PROCESS_KEY
    SJMP MAIN_LOOP

PROCESS_KEY:
    CLR KEY_READY_FLAG
    MOV A, CURRENT_KEY
    
    ; Process key based on type
    CJNE A, #2AH, CHECK_DIGIT_KEY  ; '*' = 2AH
    LCALL HANDLE_BACKSPACE
    SJMP MAIN_LOOP
    
CHECK_DIGIT_KEY:
    ; Check if digit 0-9
    CLR C
    SUBB A, #30H          ; '0' = 30H
    JC MAIN_LOOP          ; Not a digit
    CJNE A, #0AH, STORE_DIGIT
    SJMP MAIN_LOOP        ; Not 0-9
    
STORE_DIGIT:
    ; Convert back to ASCII and store
    ADD A, #30H           ; Convert to ASCII
    LCALL LCD_DATA_WRITE
    
    ; Store in password buffer
    MOV R0, #ENTERED_PASS
    MOV A, N
    ADD A, R0
    MOV R0, A
    MOV @R0, A
    
    INC N
    
    ; Check if password complete
    MOV A, N
    CJNE A, #4, MAIN_LOOP
    LCALL VERIFY_PASSWORD
    SJMP MAIN_LOOP

SYSTEM_INIT:
    ; Initialize outputs to OFF
    CLR P3.4    ; RE - Relay
    CLR P3.5    ; G  - Green LED  
    CLR P3.6    ; R  - Red LED
    
    ; Initialize LCD with PROPER BLOCKING DELAYS
    LCALL LCD_INIT
    
    ; Display welcome message
    MOV DPTR, #MSG_ENTER_PASS
    LCALL LCD_DISPLAY_MSG
    MOV A, #0C0H        ; Move to second line
    LCALL LCD_CMD
    
    ; Store actual password "1234"
    MOV ACTUAL_PASS, #31H    ; '1'
    MOV ACTUAL_PASS+1, #32H  ; '2'
    MOV ACTUAL_PASS+2, #33H  ; '3' 
    MOV ACTUAL_PASS+3, #34H  ; '4'
    RET

INIT_VARIABLES:
    MOV N, #0
    MOV WRONG_ATT, #0
    MOV SCAN_COUNT, #10      ; Scan every 10ms
    MOV LAST_KEY, #0FFH      ; No key pressed
    MOV CURRENT_KEY, #0FFH
    CLR KEY_READY_FLAG
    RET

INIT_TIMERS:
    ; Timer 0 for system tick (1ms interrupts)
    MOV TMOD, #01H           ; Timer 0, mode 1 (16-bit)
    MOV TH0, #0FCH           ; Reload value for 1ms @ 12MHz
    MOV TL0, #018H
    MOV IE, #82H             ; Enable Timer 0 interrupt
    SETB TR0                 ; Start Timer 0
    RET

; TIMER 0 INTERRUPT SERVICE ROUTINE 
TIMER0_ISR:
    CLR TR0                  ; Stop timer
    PUSH ACC                 ; Save registers
    PUSH PSW
    
    ; Reload timer for next interrupt (1ms)
    MOV TH0, #0FCH
    MOV TL0, #018H
    SETB TR0                 ; Restart timer
    
    ; Update keypad scan counter
    DEC SCAN_COUNT
    MOV A, SCAN_COUNT
    JNZ ISR_END
    
    ; 10ms elapsed - scan keypad
    MOV SCAN_COUNT, #10
    LCALL SCAN_KEYPAD_MATRIX
    
ISR_END:
    POP PSW                  ; Restore registers
    POP ACC
    RETI

; KEYPAD SCANNING 
SCAN_KEYPAD_MATRIX:
    MOV CURRENT_KEY, #0FFH   ; Assume no key
    
    ; Scan Row 1 (Keys 1,2,3)
    MOV P1, #0FEH            ; R1=0 (11111110)
    LCALL READ_COLUMNS
    CJNE A, #70H, KEY_FOUND_ROW1
    
    ; Scan Row 2 (Keys 4,5,6)
    MOV P1, #0FDH            ; R2=0 (11111101)
    LCALL READ_COLUMNS
    CJNE A, #70H, KEY_FOUND_ROW2
    
    ; Scan Row 3 (Keys 7,8,9)
    MOV P1, #0FBH            ; R3=0 (11111011)
    LCALL READ_COLUMNS
    CJNE A, #70H, KEY_FOUND_ROW3
    
    ; Scan Row 4 (Keys *,0,#)
    MOV P1, #0F7H            ; R4=0 (11110111)
    LCALL READ_COLUMNS
    CJNE A, #70H, KEY_FOUND_ROW4
    
    ; No key pressed
    MOV LAST_KEY, #0FFH
    RET

READ_COLUMNS:
    MOV A, P1
    ANL A, #70H              ; Mask columns only (01110000)
    RET

KEY_FOUND_ROW1:
    ; Determine which key in row 1
    CJNE A, #30H, R1_C2      ; C1 pressed (00110000)
    MOV CURRENT_KEY, #31H    ; '1'
    SJMP KEY_VALIDATED
R1_C2:
    CJNE A, #50H, R1_C3      ; C2 pressed (01010000)
    MOV CURRENT_KEY, #32H    ; '2'
    SJMP KEY_VALIDATED
R1_C3:
    CJNE A, #60H, KEY_SCAN_DONE ; C3 pressed (01100000)
    MOV CURRENT_KEY, #33H    ; '3'
    SJMP KEY_VALIDATED

KEY_FOUND_ROW2:
    CJNE A, #30H, R2_C2
    MOV CURRENT_KEY, #34H    ; '4'
    SJMP KEY_VALIDATED
R2_C2:
    CJNE A, #50H, R2_C3
    MOV CURRENT_KEY, #35H    ; '5'
    SJMP KEY_VALIDATED
R2_C3:
    CJNE A, #60H, KEY_SCAN_DONE
    MOV CURRENT_KEY, #36H    ; '6'
    SJMP KEY_VALIDATED

KEY_FOUND_ROW3:
    CJNE A, #30H, R3_C2
    MOV CURRENT_KEY, #37H    ; '7'
    SJMP KEY_VALIDATED
R3_C2:
    CJNE A, #50H, R3_C3
    MOV CURRENT_KEY, #38H    ; '8'
    SJMP KEY_VALIDATED
R3_C3:
    CJNE A, #60H, KEY_SCAN_DONE
    MOV CURRENT_KEY, #39H    ; '9'
    SJMP KEY_VALIDATED

KEY_FOUND_ROW4:
    CJNE A, #30H, R4_C2
    MOV CURRENT_KEY, #2AH    ; '*' = 2AH
    SJMP KEY_VALIDATED
R4_C2:
    CJNE A, #50H, R4_C3
    MOV CURRENT_KEY, #30H    ; '0'
    SJMP KEY_VALIDATED
R4_C3:
    CJNE A, #60H, KEY_SCAN_DONE
    MOV CURRENT_KEY, #23H    ; '#' = 23H
    ; Don't validate # key

KEY_VALIDATED:
    ; Simple debounce - only process if key changed
    MOV A, CURRENT_KEY
    CJNE A, LAST_KEY, NEW_KEY
    SJMP KEY_SCAN_DONE

NEW_KEY:
    MOV LAST_KEY, CURRENT_KEY
    SETB KEY_READY_FLAG

KEY_SCAN_DONE:
    RET

; LCD FUNCTIONS WITH DELAYS 
LCD_INIT:
    ; Give LCD time to power up
    MOV R7, #100
    LCALL DELAY_MS_BLOCKING
    
    ; Initialization sequence
    MOV A, #38H        ; 8-bit, 2-line, 5x7
    LCALL LCD_CMD
    MOV A, #0CH        ; Display ON, cursor OFF
    LCALL LCD_CMD
    MOV A, #01H        ; Clear display
    LCALL LCD_CMD
    MOV A, #06H        ; Entry mode increment
    LCALL LCD_CMD
    RET

LCD_CMD:
    MOV P2, A          ; Send command to LCD
    CLR P3.0           ; RS=0 for command
    CLR P3.1           ; RW=0 for write
    SETB P3.2          ; E=1
    LCALL DELAY_SHORT  ; Short pulse width delay
    CLR P3.2           ; E=0
    MOV R7, #2         ; Command execution delay
    LCALL DELAY_MS_BLOCKING
    RET

LCD_DATA_WRITE:
    MOV P2, A          ; Send data to LCD
    SETB P3.0          ; RS=1 for data
    CLR P3.1           ; RW=0 for write
    SETB P3.2          ; E=1
    LCALL DELAY_SHORT  ; Short pulse width delay
    CLR P3.2           ; E=0
    MOV R7, #2         ; Data execution delay
    LCALL DELAY_MS_BLOCKING
    RET

LCD_DISPLAY_MSG:
    CLR A
    MOVC A, @A+DPTR
    JZ LCD_MSG_END
    LCALL LCD_DATA_WRITE
    INC DPTR
    SJMP LCD_DISPLAY_MSG
LCD_MSG_END:
    RET

; DELAY FUNCTIONS
DELAY_MS_BLOCKING:
    MOV R6, #250
DELAY_MS_LOOP1:
    MOV R5, #2
DELAY_MS_LOOP2:
    DJNZ R5, DELAY_MS_LOOP2
    DJNZ R6, DELAY_MS_LOOP1
    DJNZ R7, DELAY_MS_BLOCKING
    RET

DELAY_SHORT:
    MOV R5, #50
    DJNZ R5, $
    RET

; PASSWORD HANDLING
HANDLE_BACKSPACE:
    MOV A, N
    JZ BACKSPACE_DONE
    
    DEC N
    MOV A, #0C0H
    ADD A, N
    LCALL LCD_CMD
    MOV A, #20H        ; Space character
    LCALL LCD_DATA_WRITE
    MOV A, #0C0H
    ADD A, N
    LCALL LCD_CMD
    
BACKSPACE_DONE:
    RET

VERIFY_PASSWORD:
    MOV R0, #ENTERED_PASS
    
    ; Check password "1234"
    MOV A, @R0
    CJNE A, #31H, PASSWORD_WRONG  ; '1'
    INC R0
    
    MOV A, @R0  
    CJNE A, #32H, PASSWORD_WRONG  ; '2'
    INC R0
    
    MOV A, @R0
    CJNE A, #33H, PASSWORD_WRONG  ; '3'
    INC R0
    
    MOV A, @R0
    CJNE A, #34H, PASSWORD_WRONG  ; '4'
    
    ; Password correct
    LCALL ACCESS_GRANTED
    RET

PASSWORD_WRONG:
    LCALL ACCESS_DENIED
    RET

ACCESS_GRANTED:
    SETB P3.4    ; RE - Relay
    SETB P3.5    ; G  - Green LED
    CLR P3.6     ; R  - Red LED
    
    MOV A, #01H  ; Clear display
    LCALL LCD_CMD
    MOV DPTR, #MSG_GRANTED
    LCALL LCD_DISPLAY_MSG
    
    MOV R7, #200 ; 1 second delay (approx)
    LCALL DELAY_MS_BLOCKING
    
    ; Reset display
    MOV A, #01H
    LCALL LCD_CMD
    MOV DPTR, #MSG_ENTER_PASS
    LCALL LCD_DISPLAY_MSG
    MOV A, #0C0H
    LCALL LCD_CMD
    
    ; Reset system
    CLR P3.4
    CLR P3.5
    MOV WRONG_ATT, #0
    MOV N, #0
    RET

ACCESS_DENIED:
    CLR P3.4
    CLR P3.5  
    SETB P3.6
    
    MOV A, WRONG_ATT
    INC A
    MOV WRONG_ATT, A
    
    MOV A, #01H  ; Clear display
    LCALL LCD_CMD
    MOV DPTR, #MSG_DENIED
    LCALL LCD_DISPLAY_MSG
    
    MOV R7, #200 ; 1 second delay
    LCALL DELAY_MS_BLOCKING
    
    MOV A, WRONG_ATT
    CJNE A, #3, SHOW_TRY_AGAIN
    
    ; Lockout after 3 attempts
    LCALL SYSTEM_LOCKOUT
    SJMP RESET_DISPLAY

SHOW_TRY_AGAIN:
    MOV A, #01H
    LCALL LCD_CMD
    MOV DPTR, #MSG_TRY_AGAIN
    LCALL LCD_DISPLAY_MSG
    
    MOV R7, #200
    LCALL DELAY_MS_BLOCKING

RESET_DISPLAY:
    MOV A, #01H
    LCALL LCD_CMD
    MOV DPTR, #MSG_ENTER_PASS
    LCALL LCD_DISPLAY_MSG
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV N, #0
    RET

SYSTEM_LOCKOUT:
    MOV A, #01H
    LCALL LCD_CMD
    MOV DPTR, #MSG_PLEASE_WAIT
    LCALL LCD_DISPLAY_MSG
    MOV A, #0C0H
    LCALL LCD_CMD
    MOV DPTR, #MSG_FEW_SECONDS
    LCALL LCD_DISPLAY_MSG
    
    MOV R7, #100 ; 5 second lockout (approx)
    LCALL DELAY_MS_BLOCKING
    
    MOV WRONG_ATT, #0
    RET

MSG_ENTER_PASS:   DB 'Enter Pass:', 0
MSG_GRANTED:      DB 'Access Granted', 0  
MSG_DENIED:       DB 'Access Denied', 0
MSG_TRY_AGAIN:    DB 'Try Again', 0
MSG_PLEASE_WAIT:  DB 'Please Wait', 0
MSG_FEW_SECONDS:  DB 'few Seconds', 0

END
