uart_open:       
      ld ix, uartstruct               ; address of the uart struct
      ld a, $15
      rst.lil $08                         ; mos_uopen
      ret

uart_close:
      ld a, $16
      rst.lil $08                         ; mos_uclose
      ret

uart_putc:
      ld (uart_send+1), a      
      ret

uart_send:      
      ld c, 65                        ; char to send is stored here
      ld a, $18
      rst.lil $08                         ; mos_uputc      
      ret


;0x17: mos_ugetc
;Read a character from UART1 (Requires MOS 1.03 or above)
;
;Returns:
;
;A: The character read
;F: C if successful, NC if the UART is closed

uart_getc:
      ld a, $17
      rst.lil $08
      ret

uartstruct:
      defb $80                        ; LONG (3 bytes) to store baud rate (9600)
      defb $25
      defb $00
      defb 8                          ; data bits
      defb 1                          ; stop bits
      defb 0                          ; parity bits
      defb 0                          ; flow control
      defb 0                          ; interrupt bits
uartstruct_end:   