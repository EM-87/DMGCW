; ====================================================================
; File: src/link.asm - Orquestador de Comunicación Link Cable (Refactorizado)
; ====================================================================

INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"
INCLUDE "lib/utils.asm"      ; <<<--- INCLUIR LAS UTILIDADES CENTRALIZADAS

; --- Dependencias Externas ---
EXTERN UI_ClearScreen, UI_DrawBox, UI_PrintInBox, UI_PrintStringAtXY
EXTERN PlayBeepConfirm, PlayBeepError
EXTERN AddressBuf, AmountBuf

; ====================================================================
; Punto de Entrada y Lógica Principal
; ====================================================================
SECTION "LinkModule", ROM1[$5200]

Entry_LinkTest:
    ld hl, AddressBuf
    ld a, [hl]
    or a
    jr z, .no_data

    ; --- Flujo de Comunicación ---
    call LinkInit
    ld hl, .connecting_msg
    call DrawLinkScreen
    call LinkDetect
    jr c, .connection_error

    ld hl, .handshake_msg
    call DrawLinkScreen
    call LinkHandshake
    jr c, .handshake_error
    ld a, 20
    call DelayFrames

    ld hl, .transmitting_msg
    call DrawLinkScreen
    call LinkTransmit
    jr c, .transmit_error

    ld hl, .verifying_msg
    call DrawLinkScreen
    call LinkVerify
    jr c, .verify_error

    ; --- Éxito ---
    ld hl, .success_msg
    call DrawLinkScreen
    call PlayBeepConfirm
    jr .wait_exit

    ; --- Manejo de Errores ---
.connection_error:
    ld hl, .error_msg_conn
    call DrawLinkScreen
    jr .error_common
.handshake_error:
    ld hl, .error_msg_hand
    call DrawLinkScreen
    jr .error_common
.transmit_error:
    ld hl, .error_msg_tx
    call DrawLinkScreen
    jr .error_common
.verify_error:
    ld hl, .error_msg_verify
    call DrawLinkScreen
    jr .error_common
.error_common:
    call PlayBeepError
    jr .wait_exit
.no_data:
    ld hl, .no_data_msg
    call DrawLinkScreen

.wait_exit:
    ld a, (1 << BUTTON_A_BIT) | (1 << BUTTON_B_BIT)
    call WaitButton
    call LinkClose
    ret

; ====================================================================
; Lógica del Protocolo Link (Conceptualizado como una librería interna)
; ====================================================================

LinkInit:
    xor a
    ld [rSB], a
    ld a, $80
    ld [rSC], a
    ld a, 5
    call DelayFrames
    ld b, 3
.flush_loop:
    ld a, $00
    call LinkSendByte
    ld a, 3
    call DelayFrames
    dec b
    jr nz, .flush_loop
    ret

LinkDetect:
    ld b, MAX_RETRIES
.detect_loop:
    ld a, LINK_MAGIC_REQ
    call LinkSendByte
    jr c, .next_try
    call LinkReceiveByte
    jr c, .next_try
    cp LINK_MAGIC_ACK
    jr z, .success
    dec b
    jr nz, .detect_loop
.next_try:
    dec b
    jr nz, .detect_loop
.error:
    scf
    ret
.success:
    xor a
    ret

LinkHandshake:
    ld a, LINK_PROTO_VERSION
    call LinkSendByte
    jr c, .error
    call LinkReceiveByte
    jr c, .error
    cp LINK_VERSION_ACK
    jr z, .success
.error:
    scf
    ret
.success:
    xor a
    ret

LinkTransmit:
    call BuildTransactionPayload
    jr c, .error
    ld hl, LinkTxBuffer
    call StringLength
    ld b, a
    ld hl, LinkTxBuffer
    call LinkSendFrameWithCRC
    jr c, .error
    xor a
    ret
.error:
    scf
    ret

LinkVerify:
    call LinkReceiveByte
    jr c, .error
    cp LINK_VERIFY_REQ
    jr nz, .error
    ld a, LINK_VERIFY_ACK
    call LinkSendByte
    jr c, .error
    xor a
    ret
.error:
    scf
    ret

LinkClose:
    xor a
    ld [rSB], a
    ld [rSC], a
    ret

; --- Lógica de Frames y Bajo Nivel ---
LinkSendFrameWithCRC:
    push bc
    ld a, b
    call CalculateCRC8
    ld [FrameCRC], a
    pop bc
    ld a, LINK_START_BYTE
    call LinkSendByte
    jr c, .send_error
    ld a, b
    call LinkSendByte
    jr c, .send_error
.data_loop:
    or b
    jr z, .data_done
    ld a, [hl+]
    call LinkSendByte
    jr c, .send_error
    dec b
    jr .data_loop
.data_done:
    ld a, [FrameCRC]
    call LinkSendByte
    jr c, .send_error
    ld a, LINK_END_BYTE
    call LinkSendByte
    jr c, .send_error
    call LinkReceiveByte
    jr c, .send_error
    cp LINK_FRAME_ACK
    jr z, .success_frame
    scf
    ret
.success_frame:
    xor a
    ret
.send_error:
    scf
    ret

BuildTransactionPayload:
    ld hl, AddressBuf
    ld de, LinkTxBuffer
    ld bc, WALLET_ADDR_LEN
    call CopyString
    ld hl, LinkTxBuffer
    call StringLength
    ld c, a
    ld a, '|'
    ld [de+], a
    ld hl, AmountBuf
    ld a, LINK_MAX_PAYLOAD
    sub c
    dec a
    ld b, 0
    ld c, a
    call CopyString
    jr c, .build_error
    xor a
    ret
.build_error:
    scf
    ret

CalculateCRC8:
    ld c, 0
    ld d, b
.byte_loop:
    ld a, d
    or a
    jr z, .crc_done
    ld a, [hl+]
    xor c
    ld c, a
    ld e, 8
.bit_loop:
    sla c
    jr nc, .no_xor
    ld a, c
    xor $07
    ld c, a
.no_xor:
    dec e
    jr nz, .bit_loop
    dec d
    jr .byte_loop
.crc_done:
    ld a, c
    ret

LinkSendByte:
    ld [rSB], a
    ld a, $81
    ld [rSC], a
    ld bc, TIMEOUT_SHORT
.wait_send:
    ld a, [rSC]
    bit 7, a
    jr z, .send_ok
    dec bc
    ld a, b
    or c
    jr nz, .wait_send
    scf
    ret
.send_ok:
    xor a
    ret

LinkReceiveByte:
    ld bc, TIMEOUT_LONG
.wait_recv:
    ld a, [rSC]
    bit 7, a
    jr z, .recv_ok
    dec bc
    ld a, b
    or c
    jr nz, .wait_recv
    scf
    ret
.recv_ok:
    ld a, [rSB]
    or a
    ret

; ====================================================================
; UI y Strings
; ====================================================================
SECTION "LinkStrings", ROM1
LinkTitle:         DB "CABLE LINK",0
.connecting_msg:   DB "Conectando...",0
.handshake_msg:    DB "Estableciendo protocolo...",0
.transmitting_msg: DB "Transmitiendo datos...",0
.verifying_msg:    DB "Verificando envio...",0
.success_msg:      DB "Transmision completada!",0
.error_msg_conn:   DB "Error: No se detecta conexion.",0
.error_msg_hand:   DB "Error: Protocolo incompatible.",0
.error_msg_tx:     DB "Error: Falla de transmision.",0
.error_msg_verify: DB "Error: El receptor no verifico.",0
.no_data_msg:      DB "No hay datos para enviar.",0

DrawLinkScreen:
    call UI_ClearScreen
    ld a, 1
    ld b, 1
    ld c, 18
    ld d, 16
    call UI_DrawBox
    ld hl, LinkTitle
    ld c, 1
    ld d, 1
    ld e, 18
    call UI_PrintInBox
    ld d, 8
    ld e, 2
    call UI_PrintStringAtXY
    ret

; --- Variables WRAM ---
SECTION "LinkVars", WRAM0[$CD00]
FrameCRC:     DS 1
LinkTxBuffer: DS LINK_MAX_PAYLOAD + 1
