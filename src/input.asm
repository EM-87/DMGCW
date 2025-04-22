; input.asm - Keyboard virtual de charset y campos
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

SECTION "InputModule", ROM1[$4000]
Entry_Input:
    ; Initialize input state
    xor a
    ld [Input_CharIndex], a
    ld [Input_EditingField], a  ; 0=Address,1=Amount
    ld [Input_AddrLen], a
    ld [Input_AmtLen], a
    
    ; Clear buffers if Start was used to enter
    ld a, [EntryReason]
    cp ENTRY_NEW
    jr nz, .skipClear
    
    ; Clear address buffer
    ld hl, AddressBuf
    xor a
    ld [hl], a
    
    ; Clear amount buffer
    ld hl, AmountBuf
    xor a
    ld [hl], a
    
.skipClear:
    ; Main input loop
InputLoop:
    ; Draw input screen
    call DrawInputScreen
    ; Handle input
    call ReadInputJoypad
    ld a, [JoyState]
    ld b, a            ; Store current state
    ld a, [JoyPrevState]
    cp b               ; Compare with previous
    jr z, InputLoop    ; If no change, keep polling
    
    ; Store new state
    ld a, b
    ld [JoyPrevState], a
    
    ; Check exit buttons
    bit BUTTON_B_BIT, a
    jr nz, .exitCancel
    bit BUTTON_START_BIT, a
    jr nz, .exitConfirm
    
    ; Check navigation
    bit BUTTON_LEFT_BIT, a
    jr nz, .left
    bit BUTTON_RIGHT_BIT, a
    jr nz, .right
    bit BUTTON_SELECT_BIT, a
    jr nz, .toggleField
    bit BUTTON_A_BIT, a
    jr nz, .addChar
    
    jp InputLoop
    
.left:
    call DecrCharIndex
    jp InputLoop
    
.right:
    call IncrCharIndex
    jp InputLoop
    
.toggleField:
    call ToggleField
    jp InputLoop
    
.addChar:
    call AddChar
    jp InputLoop
    
.exitCancel:
    ; Salir sin guardar cambios
    ld a, EXIT_CANCEL
    ld [ExitReason], a
    ret
    
.exitConfirm:
    ; Confirmar y pasar a pantalla de confirmación
    ; Primero verificar si hay datos válidos
    ld a, [Input_AddrLen]
    or a
    jr z, .exitCancel  ; Si no hay dirección, cancelar
    
    ld a, [Input_AmtLen]
    or a
    jr z, .exitCancel  ; Si no hay cantidad, cancelar
    
    ; Datos válidos, ir a confirmación
    ld a, EXIT_CONFIRM
    ld [ExitReason], a
    ret

; DrawInputScreen: muestra campos y selector
DrawInputScreen:
    call UI_ClearScreen
    
    ; Dibuja caja completa (x=1,y=1,w=28,h=16)
    ld a, 1  ; x
    ld b, 1  ; y
    ld c, 28 ; width
    ld d, 16 ; height
    call UI_DrawBox
    
    ; Título centrado
    ld hl, InputTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 28  ; box_w
    call UI_PrintInBox
    
    ; Mostrar "Dir:" y buffer
    ld hl, DirLabel
    ld d, 3   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, AddressBuf
    ld d, 4   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar "Monto:" y buffer
    ld hl, MontoLabel
    ld d, 6   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, AmountBuf
    ld d, 7   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar "Char:" y caracter actual
    ld hl, CharLabel
    ld d, 9   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Obtener caracter actual
    ld a, [Input_CharIndex]
    call GetCharsetChar
    
    ; Mostrar caracter actual
    ld d, 9   ; y
    ld e, 10  ; x
    call UI_PrintAtXY
    
    ; Mostrar "Campo:" y campo actual
    ld hl, FieldLabel
    ld d, 11  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar campo actual
    ld a, [Input_EditingField]
    or a
    jr nz, .showAmtField
    
    ; Mostrar "Dirección"
    ld hl, FieldAddrName
    jr .showField
    
.showAmtField:
    ; Mostrar "Monto"
    ld hl, FieldAmtName
    
.showField:
    ld d, 11  ; y
    ld e, 10  ; x
    call UI_PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, Inst1
    ld d, 13  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, Inst2
    ld d, 14  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ret

; ReadInputJoypad: maneja entrada de joypad con debouncing
ReadInputJoypad:
    ; Leer joypad
    call ReadJoypad
    ret

; DecrCharIndex: Decrementa índice de caracter
DecrCharIndex:
    ld a, [Input_CharIndex]
    or a
    jr nz, .notZero
    
    ; Si es cero, ir al último caracter
    ld a, CharsetLen-1
    jr .updateIndex
    
.notZero:
    ; Decrementar normalmente
    dec a
    
.updateIndex:
    ld [Input_CharIndex], a
    call PlayBeepNav
    ret

; IncrCharIndex: Incrementa índice de caracter
IncrCharIndex:
    ld a, [Input_CharIndex]
    inc a
    cp CharsetLen
    jr c, .notOverflow
    
    ; Si excede el tamaño, volver a cero
    xor a
    
.notOverflow:
    ld [Input_CharIndex], a
    call PlayBeepNav
    ret

; ToggleField: Alterna entre campos
ToggleField:
    ld a, [Input_EditingField]
    xor 1
    ld [Input_EditingField], a
    call PlayBeepConfirm
    ret

; AddChar: Añade caracter al campo actual
AddChar:
    ; Verificar qué campo está siendo editado
    ld a, [Input_EditingField]
    or a
    jr nz, .editAmount
    
    ; Editar dirección
    ld a, [Input_AddrLen]
    cp MaxAddrLen
    jr nc, .fieldFull
    
    ; Obtener caracter actual
    ld a, [Input_CharIndex]
    call GetCharsetChar
    
    ; Añadir a buffer de dirección
    ld hl, AddressBuf
    ld c, [Input_AddrLen]
    ld b, 0
    add hl, bc
    ld [hl], a
    
    ; Agregar terminador nulo
    inc hl
    ld [hl], 0
    
    ; Incrementar longitud
    ld a, [Input_AddrLen]
    inc a
    ld [Input_AddrLen], a
    
    jr .charAdded
    
.editAmount:
    ; Editar monto
    ld a, [Input_AmtLen]
    cp MaxAmtLen
    jr nc, .fieldFull
    
    ; Obtener caracter actual
    ld a, [Input_CharIndex]
    call GetCharsetChar
    
    ; Añadir a buffer de monto
    ld hl, AmountBuf
    ld c, [Input_AmtLen]
    ld b, 0
    add hl, bc
    ld [hl], a
    
    ; Agregar terminador nulo
    inc hl
    ld [hl], 0
    
    ; Incrementar longitud
    ld a, [Input_AmtLen]
    inc a
    ld [Input_AmtLen], a
    
.charAdded:
    call PlayBeepConfirm
    ret
    
.fieldFull:
    call PlayBeepError
    ret

; GetCharsetChar: Obtiene el carácter en posición A del charset
; Entrada: A = índice en el charset
; Salida: A = carácter
GetCharsetChar:
    push hl
    push bc
    
    ; Obtener puntero al charset
    ld hl, Charset
    ld b, 0
    ld c, a
    add hl, bc    ; HL = Charset + índice
    
    ; Leer carácter
    ld a, [hl]
    
    pop bc
    pop hl
    ret

; --- Datos y constantes ---
SECTION "InputData", ROM1
InputTitle:     DB "ENVIAR TRANSACCION", 0
DirLabel:       DB "Dir:", 0
MontoLabel:     DB "Monto:", 0
CharLabel:      DB "Char:", 0
FieldLabel:     DB "Campo:", 0
FieldAddrName:  DB "DIRECCION", 0
FieldAmtName:   DB "MONTO", 0
Inst1:          DB "A:Add Sel:Campo", 0
Inst2:          DB "B:Cancel St:Confirmar", 0

Charset:        DB "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
CharsetLen:     EQU $-Charset

; Constantes
MaxAddrLen:     EQU 23
MaxAmtLen:      EQU 9

; --- Variables en WRAM ---
SECTION "InputVars", WRAM0[$C100]
Input_CharIndex:   DS 1  ; Índice del caracter actual
Input_EditingField: DS 1 ; Campo actual (0=dirección, 1=monto)
Input_AddrLen:     DS 1  ; Longitud actual de dirección
Input_AmtLen:      DS 1  ; Longitud actual de monto
ExitReason:        DS 1  ; Razón de salida (0=cancelar, 1=confirmar)