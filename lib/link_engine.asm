; ====================================================================
; link_engine.asm - Game Boy Link Cable Communication Engine
; ====================================================================
; Provides low-level utilities and helper functions for Link Cable
; serial communication. Used by src/link.asm for protocol implementation.
;
; Public API:
;   DelayFrames       - Wait for specified number of VBlank frames
;   Link_FlushSerial  - Flush serial port buffers
;   Link_WaitReady    - Wait for serial port to be ready
;
; ====================================================================

INCLUDE "hardware.inc"
INCLUDE "constants.inc"

SECTION "Link_engineCode", ROM0


; --- External dependencies ---

SECTION "LinkEngine", ROM0

; ====================================================================
; DelayFrames - Wait for specified number of VBlank frames
; ====================================================================
; Input:  A = number of frames to wait
; Output: None
; Modifies: AF, B
; ====================================================================
DelayFrames::
    or a
    ret z  ; Return if 0 frames

    ld b, a
    ld a, [FrameCounter]

.wait_loop:
    push af
    ld a, [FrameCounter]
    ld c, a
    pop af

    ; Check if frame has changed
    cp c
    jr z, .wait_loop  ; Still same frame, keep waiting

    ; Frame changed, update reference
    ld a, c
    dec b
    jr nz, .wait_loop

    ret

; ====================================================================
; Link_FlushSerial - Flush serial port buffers
; ====================================================================
; Input:  None
; Output: None
; Modifies: AF, B
;
; Sends several null bytes to clear any pending data in the serial buffer
; ====================================================================
Link_FlushSerial::
    push bc

    ; Reset serial control
    xor a
    ld [rSB], a
    ld a, $80
    ld [rSC], a

    ; Short delay
    ld a, 2
    call DelayFrames

    ; Send 3 null bytes to flush
    ld b, 3
.flush_loop:
    xor a
    ld [rSB], a
    ld a, $81  ; Start transfer (external clock)
    ld [rSC], a

    ; Wait for transfer complete or timeout
    push bc
    ld bc, TIMEOUT_SHORT
.wait_transfer:
    ld a, [rSC]
    bit 7, a
    jr z, .transfer_done
    dec bc
    ld a, b
    or c
    jr nz, .wait_transfer

.transfer_done:
    pop bc

    ; Small delay between flushes
    ld a, 1
    call DelayFrames

    dec b
    jr nz, .flush_loop

    pop bc
    ret

; ====================================================================
; Link_WaitReady - Wait for serial port to be ready
; ====================================================================
; Input:  None
; Output: Carry set if timeout, clear if ready
; Modifies: AF, BC
; ====================================================================
Link_WaitReady::
    ld bc, TIMEOUT_LONG

.wait_loop:
    ld a, [rSC]
    bit 7, a
    jr z, .ready  ; Bit 7 clear = transfer complete

    ; Check timeout
    dec bc
    ld a, b
    or c
    jr nz, .wait_loop

    ; Timeout
    scf
    ret

.ready:
    xor a  ; Clear carry
    ret

; ====================================================================
; Link_SendByteRaw - Send single byte with timeout (raw, no error handling)
; ====================================================================
; Input:  A = byte to send
; Output: A = received byte, Carry set on timeout
; Modifies: AF, BC
; ====================================================================
Link_SendByteRaw::
    ld [rSB], a
    ld a, $81  ; Start transfer with external clock
    ld [rSC], a

    ld bc, TIMEOUT_SHORT
.wait_send:
    ld a, [rSC]
    bit 7, a
    jr z, .send_complete

    dec bc
    ld a, b
    or c
    jr nz, .wait_send

    ; Timeout
    scf
    ld a, $FF
    ret

.send_complete:
    ld a, [rSB]  ; Get received byte
    or a  ; Clear carry
    ret

; ====================================================================
; Link_ReceiveByteRaw - Receive single byte with timeout
; ====================================================================
; Input:  None
; Output: A = received byte, Carry set on timeout
; Modifies: AF, BC
; ====================================================================
Link_ReceiveByteRaw::
    ; Send dummy byte to initiate transfer
    xor a
    ld [rSB], a
    ld a, $81
    ld [rSC], a

    ld bc, TIMEOUT_LONG
.wait_recv:
    ld a, [rSC]
    bit 7, a
    jr z, .recv_complete

    dec bc
    ld a, b
    or c
    jr nz, .wait_recv

    ; Timeout
    scf
    ld a, $FF
    ret

.recv_complete:
    ld a, [rSB]
    or a  ; Clear carry
    ret

; ====================================================================
; Link_ComputeCRC16 - Compute CRC-16 checksum
; ====================================================================
; Input:  HL = data pointer, BC = length
; Output: DE = CRC-16 value
; Modifies: AF, BC, DE, HL
;
; Uses CRC-16-CCITT polynomial: 0x1021
; ====================================================================
Link_ComputeCRC16::
    ld d, 0
    ld e, 0  ; Initialize CRC to 0

.byte_loop:
    ld a, b
    or c
    ret z  ; Return if no more bytes

    ; XOR byte with high byte of CRC
    ld a, [hl+]
    xor d
    ld d, a

    ; Process 8 bits
    push bc
    ld b, 8
.bit_loop:
    ; Shift CRC left
    sla e
    rl d
    jr nc, .no_xor

    ; XOR with polynomial 0x1021
    ld a, d
    xor $10
    ld d, a
    ld a, e
    xor $21
    ld e, a

.no_xor:
    dec b
    jr nz, .bit_loop

    pop bc
    dec bc
    jr .byte_loop

; ====================================================================
; Link_VerifyCRC16 - Verify data against CRC-16
; ====================================================================
; Input:  HL = data pointer, BC = length, DE = expected CRC
; Output: Zero flag set if CRC matches
; Modifies: AF, BC, DE, HL
; ====================================================================
Link_VerifyCRC16::
    push de  ; Save expected CRC
    call Link_ComputeCRC16

    ; Compare
    pop bc  ; Get expected CRC into BC
    ld a, d
    cp b
    jr nz, .not_equal
    ld a, e
    cp c
    ret  ; Z flag set if equal

.not_equal:
    or 1  ; Clear Z flag
    ret

; ====================================================================
; Link_InitPort - Initialize serial port for Link Cable communication
; ====================================================================
; Input:  None
; Output: None
; Modifies: AF
; ====================================================================
Link_InitPort::
    ; Disable serial interrupts
    ld a, [rIE]
    and ~(1 << 3)  ; Clear bit 3 (serial interrupt)
    ld [rIE], a

    ; Reset serial port
    xor a
    ld [rSB], a
    ld a, $80  ; External clock mode
    ld [rSC], a

    ; Flush any pending data
    call Link_FlushSerial

    ret

; ====================================================================
; Link_ClosePort - Close serial port
; ====================================================================
; Input:  None
; Output: None
; Modifies: AF
; ====================================================================
Link_ClosePort::
    xor a
    ld [rSB], a
    ld [rSC], a
    ret

; ====================================================================
; Link_Exchange - Exchange byte with timeout and retry
; ====================================================================
; Input:  A = byte to send, B = retry count
; Output: A = received byte, Carry set on failure
; Modifies: AF, BC
; ====================================================================
Link_Exchange::
    push bc

.retry_loop:
    ld c, a  ; Save byte to send

    ld [rSB], a
    ld a, $81
    ld [rSC], a

    push bc
    ld bc, TIMEOUT_SHORT
.wait_transfer:
    ld a, [rSC]
    bit 7, a
    jr z, .transfer_ok

    dec bc
    ld a, b
    or c
    jr nz, .wait_transfer

    ; Timeout on this attempt
    pop bc
    ld a, c  ; Restore byte
    dec b
    jr nz, .retry_loop

    ; All retries failed
    pop bc
    scf
    ret

.transfer_ok:
    pop bc
    ld a, [rSB]
    pop bc
    or a  ; Clear carry
    ret

; ====================================================================
; Data Section
; ====================================================================
SECTION "LinkEngineData", ROM0

Link_ErrorStrings::
    DB "OK",0
    DB "Timeout",0
    DB "Retry exceeded",0
    DB "Invalid length",0
    DB "Checksum error",0
