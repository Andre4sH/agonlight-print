;
; Title:        print - Send a text file to a printer via ZiModem UART
; Author:	Andreas Henningsson
; Created:      2026-05-04
;
; Usage: print <filepath>
;   Reads AT+PRINT command from /.printer.cfg,
;   opens the UART, sends the AT command, then streams the file.
;

                        .ASSUME ADL = 1

                        INCLUDE "mos_api.inc"

                        ORG     $b0000                  ; moslet load address

                        MACRO   PROGNAME
                        ASCIZ   "print.bin"
                        ENDMACRO

                        INCLUDE "init.inc"
                        INCLUDE "uart.inc"

                        ; Print a zero-terminated string literal to screen
                        MACRO   PRINT str
                        PUSH    HL
                        PUSH    BC
                        LD      HL, str
                        LD      BC, 0
                        LD      A, 0
                        RST.LIL $18
                        POP     BC
                        POP     HL
                        ENDMACRO

;
; _main
; IX: argv pointer array (3 bytes per entry in ADL mode)
;  C: argc
; Returns:
; HL: error code (0 = success)
;
_main:
                        ; Need exactly 2 arguments: program name + filepath to print
                        LD      A, C
                        CP      2
                        JR      Z, main_start
                        LD      HL, s_USAGE
                        CALL    PRSTR
                        LD      HL, 1
                        RET

main_start:
                        ; Save argv[1] (the print filepath) before uart_open clobbers IX
                        LD      HL, (IX+3)
                        LD      (print_filepath), HL

                        ; -----------------------------------------------
                        ; Step 1: Read AT command line from /.printer.cfg
                        ; -----------------------------------------------
                        PRINT   s_OPEN_CONFIG

                        LD      HL, s_CONFIG_FILE       ; filename
                        LD      C, fa_read              ; open for reading
                        MOSCALL mos_fopen
                        OR      A                       ; A=0 means open failed
                        JR      NZ, cfg_opened
                        LD      HL, s_ERR_NO_CONFIG
                        CALL    PRSTR
                        LD      HL, 2
                        RET

cfg_opened:
                        LD      D, A                    ; D = config file handle

                        ; Read bytes into at_cmd_buf until CR, LF, null, or EOF
                        LD      IX, at_cmd_buf

cfg_read_loop:
                        LD      C, D
                        MOSCALL mos_feof
                        CP      1
                        JR      Z, cfg_read_done
                        LD      C, D
                        MOSCALL mos_fgetc
                        CP      13                      ; CR
                        JR      Z, cfg_read_done
                        CP      10                      ; LF
                        JR      Z, cfg_read_done
                        OR      A                       ; null byte
                        JR      Z, cfg_read_done
                        LD      (IX+0), A               ; store character
                        INC     IX
                        JR      cfg_read_loop

cfg_read_done:
                        LD      (IX+0), 0               ; null-terminate the AT command

                        LD      C, D
                        MOSCALL mos_fclose

                        ; Show what we read
                        PRINT   s_CONFIG_READ
                        LD      HL, at_cmd_buf
                        CALL    PRSTR
                        LD      A, 13
                        RST.LIL $10
                        LD      A, 10
                        RST.LIL $10

                        ; -----------------------------------------------
                        ; Step 2: Open UART
                        ; -----------------------------------------------
                        PRINT   s_OPEN_UART
                        CALL    uart_open               ; IX -> uartstruct after this

                        ; -----------------------------------------------
                        ; Step 3: Send AT command + CR to ZiModem
                        ; -----------------------------------------------
                        PRINT   s_SEND_CMD

                        LD      HL, at_cmd_buf
send_cmd_loop:
                        LD      A, (HL)
                        OR      A
                        JR      Z, send_cmd_done
                        CALL    uart_putc               ; store char in uart_send slot
                        CALL    uart_send               ; transmit via mos_uputc
                        INC     HL
                        JR      send_cmd_loop

send_cmd_done:
                        LD      A, 13                   ; CR triggers ZiModem to start IPP job
                        CALL    uart_putc
                        CALL    uart_send

                        ; -----------------------------------------------
                        ; Step 4: Open the file to print
                        ; -----------------------------------------------
                        PRINT   s_OPEN_FILE

                        LD      HL, (print_filepath)    ; restore saved argv[1]
                        LD      C, fa_read
                        MOSCALL mos_fopen
                        OR      A
                        JR      NZ, file_opened
                        LD      HL, s_ERR_NO_FILE
                        CALL    PRSTR
                        CALL    uart_close
                        LD      HL, 3
                        RET

file_opened:
                        LD      D, A                    ; D = print file handle
                        PRINT   s_SEND_FILE

send_file_loop:
                        LD      C, D
                        MOSCALL mos_feof
                        CP      1
                        JR      Z, send_file_done
                        LD      C, D
                        MOSCALL mos_fgetc
                        CP      10                      ; skip LF (0x0A) - send CR only
                        JR      Z, send_file_loop
                        CALL    uart_putc
                        CALL    uart_send
                        JR      send_file_loop

send_file_done:
                        ; Null byte terminates the ZiModem print stream
                        LD      A, 0
                        CALL    uart_putc
                        CALL    uart_send

                        LD      C, D
                        MOSCALL mos_fclose

                        ; -----------------------------------------------
                        ; Step 5: Close UART and return to MOS
                        ; -----------------------------------------------
                        CALL    uart_close

                        PRINT   s_DONE
                        LD      HL, 0
                        RET

; -------------------------------------------------------------------
; PRSTR - Print zero-terminated string to screen
; HL: pointer to string
; -------------------------------------------------------------------
PRSTR:                  LD      A, (HL)
                        OR      A
                        RET     Z
                        RST.LIL $10
                        INC     HL
                        JR      PRSTR

; -------------------------------------------------------------------
; String constants
; -------------------------------------------------------------------
s_USAGE:                DB      "Usage: print <filepath>", 13, 10, 0
s_CONFIG_FILE:          DB      "/.printer.cfg", 0
s_ERR_NO_CONFIG:        DB      "Error: cannot open /.printer.cfg", 13, 10, 0
s_ERR_NO_FILE:          DB      "Error: cannot open print file", 13, 10, 0
s_OPEN_CONFIG:          DB      "Reading config...", 13, 10, 0
s_CONFIG_READ:          DB      "Config: ", 0
s_OPEN_UART:            DB      "Opening UART...", 13, 10, 0
s_SEND_CMD:             DB      "Sending AT command...", 13, 10, 0
s_OPEN_FILE:            DB      "Opening print file...", 13, 10, 0
s_SEND_FILE:            DB      "Sending file...", 13, 10, 0
s_DONE:                 DB      "Done.", 13, 10, 0

; -------------------------------------------------------------------
; Variables
; -------------------------------------------------------------------
print_filepath:         DS      3                       ; saved 24-bit pointer to argv[1]
at_cmd_buf:             DS      256                     ; buffer for AT command read from config
