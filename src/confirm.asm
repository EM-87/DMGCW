; confirm.asm - Módulo de confirmación de transacción y log
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

SECTION "ConfirmModule", ROM1[$4500]

; --- Entry Point ---
Entry_Confirm:
    push af
    push bc
    push de
    push hl
    
    ; Verificar si hay datos para confirmar
    ld a, [AddressBuf]
    or a
    jr z, .noData
    
    ld a, [AmountBuf]
    or a
    jr z, .noData
    
    ; Mostrar pantalla de confirmación
    call DrawConfirmScreen
    
.inputLoop:
    ; Leer input
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .inputLoop
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Verificar botones
    bit PADB_A, a
    jr nz, .confirm
    
    bit PADB_B, a
    jr nz, .cancel
    
    jr .inputLoop
    
.confirm:
    ; Reproducir sonido de confirmación
    call PlayBeepConfirm
    
    ; Guardar transacción en el log usando SRAM API
    call SRAM_LogTransaction
    
    ; Mostrar mensaje de éxito
    call ShowSuccess
    
    ; Limpiar buffers de entrada
    call ClearInputBuffers
    
    jr .exit
    
.cancel:
    ; Reproducir sonido de cancelación
    call PlayBeepNav
    
    ; Mostrar mensaje de cancelación
    call ShowCancel
    
    jr .exit
    
.noData:
    ; Mostrar mensaje de error (no hay datos)
    call ShowNoData
    
.exit:
    ; Esperar botón para volver al menú
    call WaitButton
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; DrawConfirmScreen: Dibuja la pantalla de confirmación
DrawConfirmScreen:
    ; Limpiar pantalla
    call UI_ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call UI_DrawBox
    
    ; Dibujar título
    ld hl, ConfirmTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call UI_PrintInBox
    
    ; Mostrar dirección
    ld hl, AddressLabel
    ld d, 3   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, AddressBuf
    ld d, 4   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar monto
    ld hl, AmountLabel
    ld d, 6   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, AmountBuf
    ld d, 7   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, ConfirmInstr1
    ld d, 12  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, ConfirmInstr2
    ld d, 13  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ret

; ShowSuccess: Muestra mensaje de éxito
ShowSuccess:
    ; Mostrar mensaje de éxito
    ld hl, SuccessMsg
    ld d, 10  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ret

; ShowCancel: Muestra mensaje de cancelación
ShowCancel:
    ; Limpiar área de mensaje
    call ClearMsgArea
    
    ; Mostrar mensaje de cancelación
    ld hl, CancelMsg
    ld d, 10  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ret

; ShowNoData: Muestra mensaje de error (no hay datos)
ShowNoData:
    ; Limpiar pantalla
    call UI_ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call UI_DrawBox
    
    ; Dibujar título
    ld hl, ErrorTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call UI_PrintInBox
    
    ; Mostrar mensaje de error
    ld hl, NoDataMsg
    ld d, 6   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, BackMsg
    ld d, 12  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ret

; ClearMsgArea: Limpia el área de mensajes en la pantalla
ClearMsgArea:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    ld d, 10  ; y
    ld e, 3   ; x
    call UI_GetVRAMPosition  ; Usando la versión unificada
    
    ; Limpiar línea
    ld a, " "
    ld b, 15   ; Longitud a limpiar
    
.loop:
    ld [hl+], a
    dec b
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; ClearInputBuffers: Limpia los buffers de entrada
ClearInputBuffers:
    push af
    push hl
    
    ; Limpiar buffer de dirección
    ld hl, AddressBuf
    xor a
    ld [hl], a
    
    ; Limpiar buffer de monto
    ld hl, AmountBuf
    xor a
    ld [hl], a
    
    ; Resetear contadores en src/input.asm (si son accesibles)
    ; xor a
    ; ld [Input_AddrLen], a
    ; ld [Input_AmtLen], a
    
    pop hl
    pop af
    ret

; WaitButton: Espera hasta que se pulse cualquier botón
WaitButton:
    push af
    
    ; Guardar estado actual
    ld a, [JoyState]
    ld [JoyPrevState], a
    
.wait:
    ; Leer joypad
    call ReadJoypad
    
    ; Verificar cambios
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .wait
    
    ; Verificar si se pulsó algún botón
    ld a, b
    and %11110000   ; Máscara para botones A, B, Select, Start
    jr z, .wait
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    pop af
    ret

; --- Datos y Mensajes ---
SECTION "ConfirmData", ROM1
ConfirmTitle:   DB "CONFIRMAR TX", 0
AddressLabel:   DB "Direccion:", 0
AmountLabel:    DB "Monto:", 0
ConfirmInstr1:  DB "A: Confirmar", 0
ConfirmInstr2:  DB "B: Cancelar", 0
SuccessMsg:     DB "TX Confirmada!", 0
CancelMsg:      DB "TX Cancelada", 0
ErrorTitle:     DB "ERROR", 0
NoDataMsg:      DB "No hay datos", 0
BackMsg:        DB "B: Volver", 0
