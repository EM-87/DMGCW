; confirm.asm - Módulo de confirmación de transacción y log
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

SECTION "ConfirmModule", ROM1[$4500]

; --- Constants ---
MAX_LOG_ENTRIES:    EQU 5   ; Número máximo de entradas en el log
TX_LOG_LEN:         EQU 32  ; Longitud máxima de cada entrada en el log

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
    
    ; Guardar transacción en el log
    call LogTransaction
    
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
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, ConfirmTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Mostrar dirección
    ld hl, AddressLabel
    ld d, 3   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ld hl, AddressBuf
    ld d, 4   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Mostrar monto
    ld hl, AmountLabel
    ld d, 6   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ld hl, AmountBuf
    ld d, 7   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, ConfirmInstr1
    ld d, 12  ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ld hl, ConfirmInstr2
    ld d, 13  ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; LogTransaction: Guarda la transacción actual en el log
LogTransaction:
    push af
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar si el log está lleno
    ld a, [TxCount]
    cp MAX_LOG_ENTRIES
    jr c, .notFull
    
    ; Si está lleno, desplazar entradas (eliminar la más antigua)
    ld hl, TxLog + TX_LOG_LEN  ; Segunda entrada
    ld de, TxLog              ; Primera entrada
    ld bc, (MAX_LOG_ENTRIES - 1) * TX_LOG_LEN
    call CopyMemory
    
    ; Ahora TxCount = MAX_LOG_ENTRIES (no cambia)
    jr .prepareEntry
    
.notFull:
    ; Incrementar contador de transacciones
    inc a
    ld [TxCount], a
    
.prepareEntry:
    ; Calcular posición para la nueva entrada
    ; Si desplazamos, va en la última posición
    ; Si no, va en la posición TxCount-1
    ld a, [TxCount]
    dec a
    ld b, a
    ld c, TX_LOG_LEN
    call Multiply  ; HL = (TxCount-1) * TX_LOG_LEN
    
    ; HL = offset en el log
    ld de, TxLog
    add hl, de
    
    ; Construir entrada en el formato "XXXXX a YYYYY"
    ; donde XXXXX es el monto y YYYYY es la dirección
    
    ; Comenzar con el símbolo "-" (envío)
    ld a, "-"
    ld [hl+], a
    
    ; Copiar monto con límite
    ld de, AmountBuf
    ld bc, 8  ; Límite máximo para monto
    call CopyString
    
    ; Agregar " a "
    ld a, " "
    ld [hl+], a
    ld a, "a"
    ld [hl+], a
    ld a, " "
    ld [hl+], a
    
    ; Copiar dirección (limitado al espacio disponible)
    ld de, AddressBuf
    ld bc, TX_LOG_LEN - 12  ; Espacio restante
    call CopyString
    
    ; Terminar con 0
    xor a
    ld [hl], a
    
    ; Calcular y guardar nuevo checksum
    call CalcChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    ; Desactivar SRAM
    xor a
    ld [$0000], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; CopyString: Copia una cadena con límite de longitud
; Entrada: DE = origen, HL = destino, BC = longitud máxima
; Salida: HL apunta después del último byte copiado
CopyString:
    push af
    
.loop:
    ; Verificar si quedan bytes en el límite
    ld a, b
    or c
    jr z, .limit_reached
    
    ; Leer byte de origen
    ld a, [de]
    
    ; Comprobar fin de cadena
    or a
    jr z, .done
    
    ; Copiar byte
    ld [hl+], a
    inc de
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.limit_reached:
    ; Asegurar terminación
    xor a
    ld [hl], a
    
.done:
    pop af
    ret

; ShowSuccess: Muestra mensaje de éxito
ShowSuccess:
    ; Mostrar mensaje de éxito
    ld hl, SuccessMsg
    ld d, 10  ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; ShowCancel: Muestra mensaje de cancelación
ShowCancel:
    ; Limpiar área de mensaje
    call ClearMsgArea
    
    ; Mostrar mensaje de cancelación
    ld hl, CancelMsg
    ld d, 10  ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; ShowNoData: Muestra mensaje de error (no hay datos)
ShowNoData:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, ErrorTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Mostrar mensaje de error
    ld hl, NoDataMsg
    ld d, 6   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, BackMsg
    ld d, 12  ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; ClearMsgArea: Limpia el área de mensajes en la pantalla
ClearMsgArea:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    ld hl, _SCRN0 + (10 * 32) + 3
    
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
    
    ; Resetear contadores
    xor a
    ld [Input_AddrLen], a
    ld [Input_AmtLen], a
    
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
