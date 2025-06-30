; ====================================================================
; File: src/qr.asm - Generación de QR Dinámico (Refactorizado)
; ====================================================================

INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"

; --- Declaraciones Externas ---
EXTERN UI_ClearScreen, UI_PrintStringAtXY, UI_PrintAtXY
EXTERN PlayBeepNav
EXTERN AddressBuf, AmountBuf ; Buffers globales
EXTERN RS_GenerateECC, EncodeAlphaNumeric, BuildMatrix, ApplyMask, GetModule ; <<<--- Lógica QR delegada
EXTERN CopyMemory, CopyString, StringLength, WaitButton, WaitVBlank

; --- Constantes QR (específicas del módulo) ---
QR_MODULES EQU QR_SIZE * QR_SIZE

; --- Datos (Strings) ---
SECTION "QRData", ROM1
QRGeneratingMsg: DB "Generando QR...",0
QRTitle:         DB "CODIGO QR",0
QRPartialMsg:    DB "(Vista parcial)",0
QRInstructions:  DB "Pulsa para volver",0
QRNoDataMsg:     DB "No hay datos para QR!",0
QRTooLongMsg:    DB "Datos exceden capacidad QR!",0

; --- Variables WRAM ---
SECTION "QRVars", WRAM0[$CA00]
QR_InputBuf:     DS QR_CAPACITY + 1
QR_BitBuf:       DS QR_CAPACITY + QR_EC_SIZE
QR_Matrix:       DS QR_MODULES

; ====================================================================
; Punto de Entrada y Flujo Principal
; ====================================================================
SECTION "QRModule", ROM1[$5000]

Entry_QR_Gen:
    call UI_ClearScreen
    ld hl, QRGeneratingMsg, ld d, 8, ld e, 5, call UI_PrintStringAtXY
    call WaitVBlank

    call PrepareInputData, jr c, .no_data ; Prepara los datos y verifica si existen

    ; Codificar datos alfanuméricos
    ld hl, QR_InputBuf
    call EncodeAlphaNumeric, jr c, .data_exceeds_capacity ; Devuelve carry en error

    ; Añadir padding y calcular ECC
    call PadToByte, call PadDataBytes
    ld hl, QR_BitBuf, ld b, QR_CAPACITY
    call RS_GenerateECC ; Entrada: HL=datos, B=longitud. Salida: DE=puntero a ECC
    ex de, hl
    ld de, QR_BitBuf + QR_CAPACITY
    ld bc, QR_EC_SIZE
    call CopyMemory ; Copia el resultado de ECC al final del buffer de bits

    ; Construir la matriz, aplicar máscara y dibujar
    call BuildMatrix
    ld a, 0 ; Máscara 0
    call ApplyMask
    call DrawQRScreen

    ; Esperar salida
    ld a, (1 << BUTTON_A_BIT) | (1 << BUTTON_B_BIT), call WaitButton, ret

.no_data:
    call ShowMessage, QRNoDataMsg, ret
.data_exceeds_capacity:
    call ShowMessage, QRTooLongMsg, ret

; ====================================================================
; Subrutinas
; ====================================================================

PrepareInputData:
    ld hl, AddressBuf, ld a, [hl], or a, jr z, .error ; No hay dirección
    ld de, QR_InputBuf, ld bc, QR_CAPACITY, call CopyString
    ld hl, QR_InputBuf, call StringLength, ld b, a, add hl, bc
    ld a, '|', ld [hl+], a
    ld de, hl, ld hl, AmountBuf
    ld a, [hl], or a, jr z, .error ; No hay monto
    ld a, QR_CAPACITY, sub b, dec a, ld c, a, ld b, 0
    call CopyString
    xor a, ret ; Éxito
.error:
    scf, ret ; Error (carry set)

DrawQRScreen:
    call UI_ClearScreen
    ld hl, QRTitle, ld d, 0, ld e, 6, call UI_PrintStringAtXY
    ld hl, QRPartialMsg, ld d, 1, ld e, 2, call UI_PrintStringAtXY
    ld b, 0 ; y_qr
.row_loop:
    ld a, b, cp 16, jr z, .draw_done ; Limitar a 16 filas para que quepan
    push bc, ld c, 0 ; x_qr
.col_loop:
    ld a, c, cp 18, jr z, .row_done ; Limitar a 18 columnas
    push bc, ld d, b, ld e, c, call GetModule
    or a, jr z, .white_module
    ld a, '#', jr .draw_module
.white_module:
    ld a, ' '
.draw_module:
    pop bc, ld d, b, add 2, ld e, c, add 1, call UI_PrintAtXY
    inc c, jr .col_loop
.row_done:
    pop bc, inc b, jr .row_loop
.draw_done:
    ld hl, QRInstructions, ld d, 18, ld e, 2, call UI_PrintStringAtXY, ret

ShowMessage:
    ; HL = puntero al mensaje (pasado por pila)
    call UI_ClearScreen, ld d, 8, ld e, 3, call UI_PrintStringAtXY
    ld a, (1 << BUTTON_A_BIT) | (1 << BUTTON_B_BIT), call WaitButton, ret

; ====================================================================
; --- Lógica Delegada ---
; Las siguientes funciones se mueven a librerías:
; - InitQRBuffers, PadToByte, PadDataBytes -> lógica de codificación en lib/rs_ecc.asm
; - GetAlphaValue, WriteBits -> lógica de codificación en lib/rs_ecc.asm
; - Place*, SetModule, IsModuleAvailable -> lógica de construcción en lib/rs_ecc.asm
; ====================================================================
