# Password based Home-Security System in 8051 Assembly

## Overview
8051-based home security system implementing a 4-digit password entry with keypad interface, LCD display, and output control (relay/LEDs). Features include password verification, attempt tracking, and lockout mechanism.

## Hardware Requirements
- 8051 Microcontroller (12MHz)
- 4x3 Matrix Keypad
- 16x2 LCD Display (8-bit mode)
- Relay module
- 2 LEDs (Green/Red)
- Resistors and supporting components

## Memory Map
```
30H-33H    ACTUAL_PASS    Stored password "1234"
34H-37H    ENTERED_PASS   User input buffer
38H        N              Character counter (0-4)
39H        WRONG_ATT      Failed attempts counter
3AH        SCAN_COUNT     Keypad scan timer (10ms)
3CH        LAST_KEY       Previous key state
3DH        CURRENT_KEY    Currently detected key
20H.0      KEY_READY_FLAG Key available for processing
```

## Pin Configuration
```
P1.0-P1.3   Keypad Rows (R1-R4)
P1.4-P1.6   Keypad Columns (C1-C3)
P2          LCD Data Bus (D0-D7)
P3.0        LCD RS
P3.1        LCD RW
P3.2        LCD E
P3.4        Relay Output (RE)
P3.5        Green LED (G)
P3.6        Red LED (R)
```

## Keypad Mapping
```
Row1: 1 (31H)  2 (32H)  3 (33H)
Row2: 4 (34H)  5 (35H)  6 (36H)
Row3: 7 (37H)  8 (38H)  9 (39H)
Row4: * (2AH)  0 (30H)  # (23H)
```

## System Operation

### Initialization
- Stack pointer set to 60H
- Timer 0 configured for 1ms interrupts
- LCD initialized in 8-bit mode
- Welcome message displayed

### Password Entry
- Keys scanned every 10ms via Timer 0 ISR
- Debouncing: only processes on key state change
- Digits stored sequentially in ENTERED_PASS buffer
- Backspace (* key) removes last character
- Maximum 4 characters

### Verification
- Compares ENTERED_PASS with ACTUAL_PASS ("1234")
- Correct: Relay activated, Green LED on for 1 second
- Incorrect: Red LED on, increments WRONG_ATT counter

### Lockout
- 3 incorrect attempts trigger 5-second lockout
- Display shows "Please Wait" during lockout
- Counter resets after lockout

## Interrupts
- Timer 0 interrupt every 1ms
- Scans keypad every 10ms (10 interrupts)
- Priority: Timer 0 only

## Key Functions

**SYSTEM_INIT**: Hardware initialization
**INIT_TIMERS**: Timer 0 setup for 1ms interrupts
**SCAN_KEYPAD_MATRIX**: 4x3 matrix scanning
**VERIFY_PASSWORD**: Password comparison logic
**ACCESS_GRANTED/DENIED**: Output control and display
**SYSTEM_LOCKOUT**: 3-attempt lockout handler

## Message Strings
- "Enter Pass:"
- "Access Granted"
- "Access Denied"
- "Try Again"
- "Please Wait"
- "few Seconds"

## Timing
- Timer 0: 1ms interrupts (FC18H reload @12MHz)
- Keypad scan: 10ms intervals
- LCD delays: 2ms command execution
- Output duration: ~1 second
- Lockout: ~5 seconds

## Build Requirements
- Assembler: ASEM-51 or compatible
- Target: 8051 @12MHz
- Memory: Internal RAM only
