A Password login system using Atmega32 AVR, Infrared Remote Control and IR Receiver Module Kit
Using only Assembly.

It takes input from the user and compares the input with the saved password in EEPROM memory (since it is non-volatile).
If the password is correct, it lights up a green LED.
If not, it lights up a red LED.

The project implements:

1. Stack initialization routine
2. Define registers to add readability
3. Implement routines to initialize Timer1 and External Interrupt 0
4. Implement routines to read and write bytes to EEPROM
5. Allocate SRAM, EEPROM, Interrupt, and ROM memory
6. Enter the main routine and initialize Stack, Timer1, INT0, and SRAM
7. Enable the interrupt flag in the Status Register
8. Implement the main loop to check for the input completion flag
9. Implement the password verification routine to compare input with EEPROM
10. Implement feedback routines for LEDs and Buzzer (Success/Fail)
11. Implement the Interrupt Service Routine (ISR) to decode IR data using Timer1