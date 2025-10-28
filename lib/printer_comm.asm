; ====================================================================
; printer_comm.asm - Game Boy Printer Communication Protocol
; ====================================================================
; Implements the Game Boy Printer communication protocol for printing
; graphics data. The GB Printer uses serial communication similar to
; Link Cable but with a specific packet-based protocol.
;
; Protocol Overview:
;   - Uses standard Game Boy serial port (SIO)
;   - Packet format: [SYNC1][SYNC2][CMD][COMPRESS][LEN_LO][LEN_HI][DATA...][CHKSUM_LO][CHKSUM_HI][ALIVE][STATUS]
;   - Commands: INIT ($01), PRINT ($02), DATA ($04), STATUS ($0F)
;
; Public API:
;   Printer_Init         - Initialize printer communication
;   Printer_SendCommand  - Send command packet to printer
;   Printer_SendData     - Send data packet (640 bytes max)
;   Printer_GetStatus    - Get printer status
;   Printer_Print        - Execute print command
;   Printer_WaitReady    - Wait for printer to be ready
;   Printer_BuildPacket  - Build packet with header and checksum
;
; ====================================================================

INCLUDE "hardware.inc"
INCLUDE "constants.inc"

; --- Printer Protocol Constants ---
PRINTER_MAGIC_1        EQU $88  ; Sync byte 1
PRINTER_MAGIC_2        EQU $33  ; Sync byte 2

; Commands
PRINTER_CMD_INIT       EQU $01  ; Initialize
PRINTER_CMD_PRINT      EQU $02  ; Print
PRINTER_CMD_DATA       EQU $04  ; Send data
PRINTER_CMD_BREAK      EQU $08  ; Break/Cancel
PRINTER_CMD_STATUS     EQU $0F  ; Query status

; Status byte flags (received in response)
PRINTER_STATUS_LOWBAT  EQU %10000000  ; Low battery
PRINTER_STATUS_ERR2    EQU %01000000  ; Other error
PRINTER_STATUS_ERR1    EQU %00100000  ; Paper jam
PRINTER_STATUS_ERR0    EQU %00010000  ; Other error
PRINTER_STATUS_UNTRAN  EQU %00001000  ; Unprocessed data
PRINTER_STATUS_FULL    EQU %00000100  ; Image data full
PRINTER_STATUS_PRINT   EQU %00000010  ; Currently printing
PRINTER_STATUS_CHKSUM  EQU %00000001  ; Checksum error

; Packet sizes
PRINTER_HEADER_SIZE    EQU 6    ; Magic(2) + Cmd(1) + Compress(1) + Length(2)
PRINTER_FOOTER_SIZE    EQU 4    ; Checksum(2) + Alive(1) + Status(1)
PRINTER_MAX_DATA       EQU 640  ; Maximum data payload
PRINTER_PACKET_MAX     EQU PRINTER_HEADER_SIZE + PRINTER_MAX_DATA + PRINTER_FOOTER_SIZE

; Print parameters (for PRINT command)
PRINTER_PAL_NORMAL     EQU %00000000  ; Normal palette
PRINTER_PAL_DARKER     EQU %00100000  ; Darker palette
PRINTER_PAL_DARK       EQU %01000000  ; Dark palette
PRINTER_PAL_DARKEST    EQU %01100000  ; Darkest palette

PRINTER_MARGIN_NONE    EQU 0    ; No margins
PRINTER_MARGIN_SMALL   EQU 1    ; Small margins
PRINTER_MARGIN_MEDIUM  EQU 2    ; Medium margins
PRINTER_MARGIN_LARGE   EQU 3    ; Large margins

; Timeouts
PRINTER_TIMEOUT_SHORT  EQU 5000   ; Short timeout (~5000 cycles)
PRINTER_TIMEOUT_LONG   EQU 30000  ; Long timeout for printing

; --- External dependencies ---

SECTION "PrinterComm", ROM0

; ====================================================================
; Printer_Init - Initialize printer and verify connectivity
; ====================================================================
; Input:  None
; Output: Carry set on error, clear on success
;         A = status byte if successful
; Modifies: AF, BC, DE, HL
; ====================================================================
Printer_Init:
    ; Reset serial port
    xor a
    ld [rSB], a
    ld a, $80  ; External clock mode
    ld [rSC], a

    ; Small delay
    ld a, 5
    call DelayFrames

    ; Send INIT command
    ld a, PRINTER_CMD_INIT
    xor a  ; No data
    ld bc, 0
    call Printer_SendCommand

    ret

; ====================================================================
; Printer_SendCommand - Send command packet with optional data
; ====================================================================
; Input:  A = command byte
;         BC = data length (0 for no data)
;         HL = data pointer (if BC > 0)
; Output: Carry set on error
;         DE = response status
; Modifies: AF, BC, DE, HL
; ====================================================================
Printer_SendCommand:
    push hl
    push bc
    push af

    ; Build packet in temporary buffer
    ld de, PrinterTempPacket

    ; Write magic bytes
    ld a, PRINTER_MAGIC_1
    ld [de], a
    inc de
    ld a, PRINTER_MAGIC_2
    ld [de], a
    inc de

    ; Write command
    pop af
    ld [de], a
    inc de

    ; Write compression flag (always 0 = no compression)
    xor a
    ld [de], a
    inc de

    ; Write length (little-endian)
    pop hl  ; Get length into HL
    ld a, l
    ld [de], a
    inc de
    ld a, h
    ld [de], a
    inc de

    ; Save length for later
    push hl

    ; Copy data if any
    pop bc  ; Length
    pop hl  ; Data pointer

    ld a, b
    or c
    jr z, .no_data

    push de
.copy_data:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copy_data
    pop de

.no_data:
    ; Calculate checksum (sum of command + compress + length + data)
    ld hl, PrinterTempPacket + 2  ; Start at command byte
    ld bc, 4  ; Cmd + Compress + Len(2)
    ; Add data length if any
    push de
    pop bc
    ld de, PrinterTempPacket + 6
    ; BC = data length already set
    call .CalculateChecksum

    ; Write checksum (little-endian)
    ld [PrinterTempPacket + 6], a  ; Low byte
    ld a, b
    ld [PrinterTempPacket + 7], a  ; High byte

    ; Write alive byte (always $00)
    xor a
    ld [PrinterTempPacket + 8], a

    ; Status byte will be filled by printer
    ld [PrinterTempPacket + 9], a

    ; Send entire packet
    ld hl, PrinterTempPacket
    ld bc, 10  ; Minimum packet size
    call .SendBytes

    ret c  ; Return if send failed

    ; Receive response (should be echo + status)
    ld hl, PrinterResponseBuf
    ld bc, 10
    call .ReceiveBytes

    ret c  ; Return if receive failed

    ; Verify magic bytes in response
    ld a, [PrinterResponseBuf]
    cp PRINTER_MAGIC_1
    jr nz, .bad_response
    ld a, [PrinterResponseBuf + 1]
    cp PRINTER_MAGIC_2
    jr nz, .bad_response

    ; Get status byte
    ld a, [PrinterResponseBuf + 9]
    ld d, a

    ; Check for errors
    and PRINTER_STATUS_CHKSUM | PRINTER_STATUS_ERR0 | PRINTER_STATUS_ERR1 | PRINTER_STATUS_ERR2
    jr nz, .error_status

    ; Success
    ld a, d  ; Return status in A
    or a  ; Clear carry
    ret

.bad_response:
.error_status:
    scf
    ret

; ====================================================================
; Helper: Calculate checksum
; Input:  HL = data pointer, BC = length
; Output: BC = checksum (16-bit little-endian)
; ====================================================================
.CalculateChecksum:
    ld de, 0
.chk_loop:
    ld a, b
    or c
    jr z, .chk_done
    ld a, [hl+]
    add e
    ld e, a
    ld a, d
    adc 0
    ld d, a
    dec bc
    jr .chk_loop
.chk_done:
    ld b, d
    ld c, e
    ret

; ====================================================================
; Helper: Send bytes to printer
; Input:  HL = data pointer, BC = count
; Output: Carry set on timeout
; ====================================================================
.SendBytes:
    ld a, b
    or c
    ret z

.send_loop:
    ld a, [hl+]
    push hl
    push bc

    ; Send byte
    ld [rSB], a
    ld a, $81  ; Start transfer
    ld [rSC], a

    ; Wait for completion
    ld bc, PRINTER_TIMEOUT_SHORT
.wait_send:
    ld a, [rSC]
    bit 7, a
    jr z, .send_ok

    dec bc
    ld a, b
    or c
    jr nz, .wait_send

    ; Timeout
    pop bc
    pop hl
    scf
    ret

.send_ok:
    pop bc
    pop hl
    dec bc
    ld a, b
    or c
    jr nz, .send_loop

    or a  ; Clear carry
    ret

; ====================================================================
; Helper: Receive bytes from printer
; Input:  HL = buffer pointer, BC = count
; Output: Carry set on timeout
; ====================================================================
.ReceiveBytes:
    ld a, b
    or c
    ret z

.recv_loop:
    push hl
    push bc

    ; Send dummy byte to clock in response
    xor a
    ld [rSB], a
    ld a, $81
    ld [rSC], a

    ; Wait for completion
    ld bc, PRINTER_TIMEOUT_LONG
.wait_recv:
    ld a, [rSC]
    bit 7, a
    jr z, .recv_ok

    dec bc
    ld a, b
    or c
    jr nz, .wait_recv

    ; Timeout
    pop bc
    pop hl
    scf
    ret

.recv_ok:
    ld a, [rSB]
    pop bc
    pop hl
    ld [hl+], a

    dec bc
    ld a, b
    or c
    jr nz, .recv_loop

    or a  ; Clear carry
    ret

; ====================================================================
; Printer_SendData - Send data packet (image data)
; ====================================================================
; Input:  HL = data pointer (must be 640 bytes)
; Output: Carry set on error
; Modifies: AF, BC, DE, HL
; ====================================================================
Printer_SendData:
    ld a, PRINTER_CMD_DATA
    ld bc, PRINTER_MAX_DATA
    call Printer_SendCommand
    ret

; ====================================================================
; Printer_Print - Execute print command
; ====================================================================
; Input:  A = palette and margins settings
;         B = number of lines to print (0 = all)
;         C = exposure value ($00-$7F, default $40)
; Output: Carry set on error
; Modifies: AF, BC, DE, HL
; ====================================================================
Printer_Print:
    push af
    push bc

    ; Build print data (4 bytes)
    ld hl, PrinterPrintData
    pop bc
    pop af

    ld [hl+], a  ; Palette/margins
    ld a, b
    ld [hl+], a  ; Lines to print
    ld a, c
    ld [hl+], a  ; Exposure
    xor a
    ld [hl], a   ; Reserved

    ; Send print command
    ld a, PRINTER_CMD_PRINT
    ld bc, 4
    ld hl, PrinterPrintData
    call Printer_SendCommand

    ret

; ====================================================================
; Printer_GetStatus - Query printer status
; ====================================================================
; Input:  None
; Output: A = status byte, Carry set on error
; Modifies: AF, BC, DE, HL
; ====================================================================
Printer_GetStatus:
    ld a, PRINTER_CMD_STATUS
    ld bc, 0
    call Printer_SendCommand
    ret

; ====================================================================
; Printer_WaitReady - Wait for printer to be ready
; ====================================================================
; Input:  B = max attempts (0 = infinite)
; Output: Carry set on timeout, A = last status
; Modifies: AF, BC, DE, HL
; ====================================================================
Printer_WaitReady:
    ld c, b  ; Save max attempts

.wait_loop:
    call Printer_GetStatus
    ret c  ; Return if error getting status

    ; Check if busy
    bit 1, a  ; PRINTER_STATUS_PRINT bit
    jr z, .ready

    ; Still printing, wait a bit
    push af
    ld a, 10
    call DelayFrames
    pop af

    ; Decrement counter if not infinite
    ld a, c
    or a
    jr z, .wait_loop  ; Infinite wait

    dec c
    jr nz, .wait_loop

    ; Timeout
    scf
    ret

.ready:
    or a  ; Clear carry
    ret

; ====================================================================
; Printer_ConvertTileMap - Convert 8x8 tile map to printer format
; ====================================================================
; Input:  HL = tile map source (20x18 = 360 bytes)
;         DE = tile data source (tiles in 2bpp format)
;         BC = output buffer
; Output: None
; Modifies: AF, BC, DE, HL
;
; Converts Game Boy tilemap + tile data to printer-ready format
; ====================================================================
Printer_ConvertTileMap:
    ; This is a complex conversion
    ; Game Boy: 8x8 tiles, 2bpp
    ; Printer: 160 dots wide, 2bpp strips
    ; Would need ~640 bytes per strip

    ; Simplified stub - real implementation would:
    ; 1. Read tile indices from map
    ; 2. Fetch corresponding tile data
    ; 3. Arrange into 160-dot-wide strips
    ; 4. Pack into printer format

    ret

; ====================================================================
; Data Section
; ====================================================================
SECTION "PrinterCommData", WRAM0

PrinterTempPacket:    DS PRINTER_PACKET_MAX
PrinterResponseBuf:   DS 10
PrinterPrintData:     DS 4
