; ====================================================================
; File: src/confirm.asm - Confirmación de Transacciones (Refactorizado Final)
; ====================================================================

INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"

; --- Declaraciones Externas ---
EXTERN JoyState
EXTERN WaitButton, ReadJoypadWithDebounce
EXTERN PlayBeepConfirm, PlayBeepNav
EXTERN UI_ClearScreen, UI_DrawBox, UI_PrintInBox, UI_PrintStringAtXY
EXTERN SRAM_LogTransaction
EXTERN AddressBuf, AmountBuf

; --- Datos y Mensajes ---
SECTION "ConfirmData", ROM1
ConfirmTitle:       DB "CONFIRMAR TX",0
AddressLabel:       DB "Direccion:",0
AmountLabel:        DB "Monto:",0
ConfirmInstr1:      DB "A: Confirmar",0
ConfirmInstr2:      DB "B: Cancelar",0
NoDataMsg:          DB "No hay datos para confirmar.",0
SuccessMsg:         DB "TX Confirmada!",0
CancelMsg:          DB "TX Cancelada",0

; ====================================================================
; Punto de Entrada y Lógica Principal
; ====================================================================
SECTION "ConfirmModule", ROM1[$4500]

Entry_Confirm:
    ; Verificar que haya datos en los buffers de entrada
    ld hl, AddressBuf, ld a, [hl], or a, jr z, .no_data
    ld hl, AmountBuf,  ld a, [hl], or a, jr z, .no_data

    call DrawConfirmScreen
.wait_input:
    call ReadJoypadWithDebounce
    ld a, [JoyState]
    bit BUTTON_A_BIT, a, jr nz, .confirm
    bit BUTTON_B_BIT, a, jr nz, .cancel
    jr .wait_input

.confirm:
    call PlayBeepConfirm
    call SRAM_LogTransaction
    call ClearInputBuffers ; Limpiar buffers para la siguiente transacción
    call ShowMessage, SuccessMsg
    ret

.cancel:
    call PlayBeepNav
    call ShowMessage, CancelMsg
    ret

.no_data:
    call ShowMessage, NoDataMsg
    ret

; ====================================================================
; Subrutinas de UI y Ayuda
; ====================================================================
DrawConfirmScreen:
    call UI_ClearScreen
    ld a, 1, ld b, 1, ld c, 18, ld d, 16, call UI_DrawBox
    ld hl, ConfirmTitle, ld c, 1, ld d, 1, ld e, 18, call UI_PrintInBox
    ld hl, AddressLabel, ld d, 3, ld e, 2, call UI_PrintStringAtXY
    ld hl, AddressBuf,   ld d, 4, ld e, 2, call UI_PrintStringAtXY
    ld hl, AmountLabel,  ld d, 6, ld e, 2, call UI_PrintStringAtXY
    ld hl, AmountBuf,    ld d, 7, ld e, 2, call UI_PrintStringAtXY
    ld hl, ConfirmInstr1, ld d, 12, ld e, 2, call UI_PrintStringAtXY
    ld hl, ConfirmInstr2, ld d, 13, ld e, 2, call UI_PrintStringAtXY
    ret

ShowMessage:
    ; Entrada: HL = puntero al mensaje (pasado por pila)
    call UI_ClearScreen
    ld d, 8, ld e, 2
    call UI_PrintStringAtXY
    ld a, (1 << BUTTON_A_BIT) | (1 << BUTTON_B_BIT)
    call WaitButton
    ret

ClearInputBuffers:
    ld hl, AddressBuf, xor a, ld [hl], a
    ld hl, AmountBuf,  xor a, ld [hl], a
    ret
