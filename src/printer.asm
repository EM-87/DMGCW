; ====================================================================
; File: src/printer.asm - Orquestador de Impresión (Refactorizado Final)
; ====================================================================

INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"
INCLUDE "lib/utils.asm"      ; <<<--- UTILIDADES CENTRALIZADAS

; --- Dependencias Externas ---
EXTERN UI_ClearScreen, UI_DrawBox, UI_PrintInBox, UI_PrintStringAtXY
EXTERN PlayBeepNav, PlayBeepError, PlayBeepConfirm
EXTERN AddressBuf, QR_Matrix ; Buffers de datos globales

; --- Constantes del Módulo ---
PRINTER_INIT        EQU $01, PRINTER_PRINT EQU $02, PRINTER_DATA EQU $04, PRINTER_STATUS EQU $0F
PRINTER_READY       EQU $00, PRINTER_BUSY   EQU $01, PRINTER_ERROR EQU $FF
HEADER_SIZE         EQU 4,   FOOTER_SIZE  EQU 2,   DATA_PACKET_SIZE EQU 640
PRINTER_SYNC_1      EQU $88, PRINTER_SYNC_2 EQU $33
QR_TILES_WIDTH      EQU 8,   QR_TILES_HEIGHT EQU 8, PRINTER_MARGINS EQU $00
PRINTER_TIMEOUT     EQU 1000

; --- Strings ---
SECTION "PrinterStrings", ROM1
PrinterTitle:       DB "IMPRESORA GB",0, PrinterPreparing: DB "Preparando...",0, PrinterWait: DB "Espere...",0
PrinterSuccess:     DB "QR impreso!",0, PrinterError:     DB "Error impresora.",0
NoDataMsg:          DB "No hay datos para imprimir.",0

; --- Variables WRAM ---
SECTION "PrinterVars", WRAM0[$CC00]
PrinterPacket:      DS DATA_PACKET_SIZE + HEADER_SIZE + FOOTER_SIZE
PrinterResponse:    DS 16, PrintBuffer: DS QR_TILES_WIDTH * QR_TILES_HEIGHT * 16

; ====================================================================
; Entry Point y Flujo Principal
; ====================================================================
SECTION "PrinterModule", ROM1[$5800]

Entry_Printer:
    ld hl, AddressBuf
    ld a, [hl]
    or a
    jr z, .no_data
    ld hl, .preparing
    call DrawPrinterScreen
    call InitPrinterComm
    jr c, .comm_error
    call PrepareQRPrintBuffer
    call PrinterSendInit
    jr c, .comm_error
    call PrinterSendData
    jr c, .comm_error
    call PrinterSendPrint
    jr c, .comm_error
    ld hl, .success_msg
    call DrawPrinterScreen
    call PlayBeepConfirm
    jr .wait_exit
.comm_error:
    ld hl, .error_msg
    call DrawPrinterScreen
    call PlayBeepError
.wait_exit:
    ld a, (1 << BUTTON_B_BIT)
    call WaitButton
    ret
.no_data:
    ld hl, .no_data_msg
    call DrawPrinterScreen
    ld a, (1 << BUTTON_B_BIT)
    call WaitButton
    ret

; ====================================================================
; Lógica del Protocolo (Conceptualizado como una librería interna)
; ====================================================================
InitPrinterComm:
    xor a
    ld [rSB], a
    ld a, $80
    ld [rSC], a
    call GetPrinterStatus
    cp PRINTER_READY
    ret
GetPrinterStatus:
    ld hl, PrinterPacket
    ld a, PRINTER_SYNC_1
    ld [hl+], a
    ld a, PRINTER_SYNC_2
    ld [hl+], a
    ld a, PRINTER_STATUS
    ld [hl+], a
    xor a
    ld [hl+], a
    ld [hl+], a
    ld [hl+], a
    ld hl, PrinterPacket + 2
    ld bc, 4
    call CalculateChecksum
    ld hl, PrinterPacket + 6
    ld [hl+], c
    ld [hl], b
    ld hl, PrinterPacket
    ld bc, 8
    call SendToPrinter
    jr c, .status_error
    ld bc, 6
    ld de, PrinterResponse
    call ReceiveFromPrinter
    jr c, .status_error
    ld a, [PrinterResponse]
    cp PRINTER_SYNC_1
    jr nz, .status_error
    ld a, [PrinterResponse+1]
    cp PRINTER_SYNC_2
    jr nz, .status_error
    ld a, [PrinterResponse+4]
    and $F0
    jr nz, .status_error
    ld a, PRINTER_READY
    or a
    ret
.status_error:
    ld a, PRINTER_ERROR
    scf
    ret

SendToPrinter:
.loop:
    ld a, b
    or c
    ret z
    ld a, [hl+]
    call SendByte
    jr c, .error
    dec bc
    jr .loop
.error:
    scf
    ret

ReceiveFromPrinter:
    ld h, d
    ld l, e
.loop_r:
    ld a, b
    or c
    ret z
    call ReceiveByte
    jr c, .error_r
    ld [hl+], a
    dec bc
    jr .loop_r
.error_r:
    scf
    ret

SendByte:
    ld [rSB], a
    ld a, $81
    ld [rSC], a
    ld bc, PRINTER_TIMEOUT
.wait_s:
    ld a, [rSC]
    bit 7, a
    jr z, .ok_s
    dec bc
    ld a, b
    or c
    jr nz, .wait_s
    scf
    ret
.ok_s:
    xor a
    ret

ReceiveByte:
    ld bc, PRINTER_TIMEOUT
.wait_r:
    ld a, [rSC]
    bit 7, a
    jr z, .ok_r
    dec bc
    ld a, b
    or c
    jr nz, .wait_r
    scf
    ret
.ok_r:
    ld a, [rSB]
    or a
    ret

CalculateChecksum:
    ld de, 0
.loop_c:
    ld a, b
    or c
    jr z, .done_c
    ld a, [hl+]
    add e
    ld e, a
    ld a, d
    adc 0
    ld d, a
    dec bc
    jr .loop_c
.done_c:
    ld b, d
    ld c, e
    ret

PrinterSendInit:
    ; ... (Lógica de construcción de paquete Init, idéntica a GetPrinterStatus pero con comando PRINTER_INIT)
    ; Por brevedad, se omite el código idéntico. Retorna carry en error.

PrepareQRPrintBuffer:
    ld hl, PrintBuffer
    ld bc, QR_TILES_WIDTH * QR_TILES_HEIGHT * 16
    xor a
    call FillMemory
    call ConvertQRToTiles
    ret
ConvertQRToTiles:
    ld b, 0
.row_loop:
    ld c, 0
.col_loop:
    push bc
    ld h, 0
    ld l, b
    ld de, QR_SIZE
    call MultiplyHLByDE
    ld a, l
    add c
    ld l, a
    ld a, h
    adc 0
    ld h, a
    ld de, QR_Matrix
    add hl, de
    ld a, [hl]
    pop bc
    or a
    jr z, .skip_pixel
    push bc
    call DrawQRPixelBlock
    pop bc
.skip_pixel:
    inc c
    ld a, c
    cp QR_SIZE
    jr c, .col_loop
    inc b
    ld a, b
    cp QR_SIZE
    jr c, .row_loop
    ret
DrawQRPixelBlock:
    ; ... (sin cambios)
PrinterSendData:
    ; ... (sin cambios, es lógica compleja específica del protocolo)
PrinterSendPrint:
    ; ... (sin cambios, es lógica compleja específica del protocolo)

MultiplyHLByDE:
    ld b, h
    ld c, l
    ld hl, 0
.mult_loop:
    ld a, d
    or e
    ret z
    add hl, bc
    dec de
    jr .mult_loop

; ====================================================================
; UI
; ====================================================================
DrawPrinterScreen:
    call UI_ClearScreen
    ld a, 1
    ld b, 1
    ld c, 18
    ld d, 16
    call UI_DrawBox
    ld hl, PrinterTitle
    ld c, 1
    ld d, 1
    ld e, 18
    call UI_PrintInBox
    ld d, 8
    ld e, 3
    call UI_PrintStringAtXY
    ret
