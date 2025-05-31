; link.asm v6 - Comunicación por cable Link para DMG Cold Wallet
; Protocolo robusto con CRC-8, verificación bidireccional y anti-ruido
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

SECTION "LinkModule", ROM1[$5200]

; --- Constantes locales ---
LINK_STATE_IDLE        EQU 0
LINK_STATE_DETECTING   EQU 1
LINK_STATE_HANDSHAKE   EQU 2
LINK_STATE_CONNECTED   EQU 3
LINK_STATE_SENDING     EQU 4
LINK_STATE_VERIFYING   EQU 5
LINK_STATE_SUCCESS     EQU 6
LINK_STATE_ERROR       EQU 7

LINK_MAGIC_REQ         EQU $42
LINK_MAGIC_ACK         EQU $24
LINK_PROTO_VERSION     EQU $01
LINK_VERSION_ACK       EQU $69

LINK_START_BYTE        EQU $A5
LINK_END_BYTE          EQU $5A
LINK_FRAME_ACK         EQU $06
LINK_FRAME_NACK        EQU $15
LINK_VERIFY_REQ        EQU $33
LINK_VERIFY_ACK        EQU $CC

LINK_DELAY_BYTE        EQU 3
LINK_DELAY_RETRY       EQU 15
LINK_DELAY_HANDSHAKE   EQU 30
LINK_DELAY_NOISE       EQU 5

TIMEOUT_VERIFY         EQU $0400

LINK_MAX_PAYLOAD       EQU 60
LINK_SEPARATOR_SIZE    EQU 1
LINK_BUFFER_SIZE       EQU 70
LINK_NOISE_THRESHOLD   EQU 3

; Tamaño mínimo para el monto en el payload
MINIMUM_AMOUNT_SPACE   EQU LINK_SEPARATOR_SIZE + 10 + 1  ; "|" + 10 dígitos + null

; --- Entry Point ---
Entry_LinkTest:
    push af
    push bc
    push de
    push hl
    xor a
    ld [LinkState], a
    ld [LinkError], a
    ld [LinkNoiseCount], a

    ld a, [AddressBuf]
    or a
    jr z, .noData

    call DrawLinkScreen
    call LinkInitWithFilter
    call LinkDetectConnectionRobust
    or a
    jr nz, .connectionError

    call LinkHandshake
    or a
    jr nz, .handshakeError

    ld a, 20
    call DelayFrames

    call LinkTransmitTransactionVerified
    or a
    jr nz, .transmitError

    ld a, LINK_STATE_SUCCESS
    ld [LinkState], a
    call ShowLinkSuccess
    jr .waitExit

.connectionError:
    ld a, LINK_ERR_TIMEOUT
    ld [LinkError], a
    call ShowConnectionError
    jr .waitExit

.handshakeError:
    call ShowHandshakeError
    jr .waitExit

.transmitError:
    call ShowTransmitError
    jr .waitExit

.noData:
    call ShowNoDataError

.waitExit:
    call WaitButtonB
    call LinkClose
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Low-level with noise filtering ---

LinkInitWithFilter:
    push af
    push bc
    xor a
    ld [rSB], a
    ld a, $80
    ld [rSC], a
    ld a, LINK_DELAY_NOISE
    call DelayFrames
    ld b, 3
.flushLoop:
    ld a, $00
    call LinkSendByteNoWait
    ld a, LINK_DELAY_BYTE
    call DelayFrames
    dec b
    jr nz, .flushLoop
    pop bc
    pop af
    ret

LinkSendByteNoWait:
    ld [rSB], a
    ld a, $81
    ld [rSC], a
    push bc
    ld b, 255
.waitNW:
    ld a, [rSC]
    bit 7, a
    jr z, .doneNW
    dec b
    jr nz, .waitNW
.doneNW:
    pop bc
    ret

; --- REFINADO: NO falsa la sesión ante ceros aislados ---
LinkSendByte:
    push bc
    push de
    ld e, a               ; byte original
    ld [rSB], a
    ld a, $81
    ld [rSC], a
    ld bc, TIMEOUT_SHORT

.waitLoop:
    ld a, [rSC]
    bit 7, a
    jr z, .done
    dec bc
    ld a, b
    or c
    jr nz, .waitLoop
    scf
    jr .exit

.done:
    ld a, [rSB]
    cp $FF
    jr z, .checkFF
    cp $00
    jr z, .checkZero
    or a
    jr .exit

.checkFF:
    ld a, e
    cp $FF
    jr z, .valid
    inc [LinkNoiseCount]
    scf
    jr .exit

.checkZero:
    ld a, e
    or a
    jr z, .valid
    inc [LinkNoiseCount]
    ld a, [LinkNoiseCount]
    cp LINK_NOISE_THRESHOLD
    jr nc, .tooMuchNoise
    xor a
    jr .exit

.tooMuchNoise:
    scf

.valid:
    xor a

.exit:
    push af
    ld a, LINK_DELAY_BYTE
    call DelayFrames
    pop af
    pop de
    pop bc
    ret

; (LinkReceiveByteTimeout preserva BC y HL, DE consumido tal cual)
LinkReceiveByteTimeout:
    push bc
    push hl
    ; ... mismo código de v6 ...
.exitRT:
    pop hl
    pop bc
    ret

; --- FRAME send con CRC-8 y reset inteligente ---
LinkSendFrameWithCRC:
    push bc
    push de
    push hl
    ld a, b
    cp LINK_MAX_PAYLOAD
    jr c, .lenOK
    jr z, .lenOK
    ld a, LINK_ERR_LENGTH
    jr .exitLF

.lenOK:
    ld [FrameLength], a
    push bc
    push hl
    call CalculateCRC8
    ld [FrameCRC], a
    pop hl
    pop bc
    ld a, LINK_START_BYTE
    call LinkSendByte
    jr c, .sendError
    ld a, [FrameLength]
    call LinkSendByte
    jr c, .sendError

.dataLoopLF:
    ld a, b
    or a
    jr z, .dataDoneLF
    ld a, [hl+]
    call LinkSendByte
    jr c, .sendError
    dec b
    jr .dataLoopLF

.dataDoneLF:
    ld a, [FrameCRC]
    call LinkSendByte
    jr c, .sendError
    ld a, LINK_END_BYTE
    call LinkSendByte
    jr c, .sendError
    call LinkReceiveByte
    jr c, .sendError
    cp LINK_FRAME_ACK
    jr z, .successLF
    ld a, LINK_ERR_CHECKSUM
    jr .exitLF

.successLF:
    xor a
    ld [LinkNoiseCount], a  ; Reset tras OK
    jr .exitLF

.sendError:
    ld a, LINK_ERR_TIMEOUT  ; Mantener historial de ruido

.exitLF:
    pop hl
    pop de
    pop bc
    ret

; --- Payload builder usa la constante global ---
BuildTransactionPayload:
    push bc
    push de
    push hl
    ld hl, LinkTxBuffer
    ld de, hl
    ld hl, AddressBuf
    ld bc, WALLET_ADDR_LEN
    call CopyStringWithLimit
    push de
    ld hl, LinkTxBuffer
    call StringLength
    ld b, a
    pop de
    ld a, LINK_MAX_PAYLOAD
    sub b
    cp MINIMUM_AMOUNT_SPACE
    jr c, .overflowBP
    ld a, '|'
    ld [de], a
    inc de
    ld hl, AmountBuf
    ld a, LINK_MAX_PAYLOAD
    sub b
    sub LINK_SEPARATOR_SIZE
    ld c, a
    xor b
    call CopyStringWithLimit
    ld hl, LinkTxBuffer
    call StringLength
    cp LINK_MAX_PAYLOAD
    jr c, .successBP
    jr z, .successBP

.overflowBP:
    scf
    jr .endBP

.successBP:
    xor a

.endBP:
    pop hl
    pop de
    pop bc
    ret

; --- CRC-8 refinado ---
CalculateCRC8:
    push bc
    push de
    push hl
    ld e, $00
.byteLoop:
    ld a, b
    or a
    jr z, .doneCRC
    ld a, [hl+]
    xor e
    ld d, 8
.bitLoop:
    add a, a
    jr nc, .noX
    xor $07
.noX:
    dec d
    jr nz, .bitLoop
    ld e, a
    dec b
    jr .byteLoop
.doneCRC:
    ld a, e
    pop hl
    pop de
    pop bc
    ret

; --- Conclusión de funciones y UI (idénticas a v5/v6) ---

SECTION "LinkVars", WRAM0[$CD00]
LinkState:        DS 1
LinkError:        DS 1
LinkNoiseCount:   DS 1
LinkTxBuffer:     DS LINK_BUFFER_SIZE
FrameLength:      DS 1
FrameCRC:         DS 1
