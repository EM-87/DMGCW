; ====================================================================
; File: src/input.asm - Módulo de Entrada de Texto Genérico (Refactorizado)
; ====================================================================

INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"

; --- Declaraciones Externas ---
EXTERN ReadJoypad, WaitButton, WaitVBlank, CopyString, StringLength, FillMemory
EXTERN UI_ClearScreen, UI_PrintStringAtXY, UI_PrintAtXY, UI_DrawBox
EXTERN JoyState, PlayBeepNav, PlayBeepConfirm, PlayBeepError

; ====================================================================
; Punto de Entrada y Lógica Principal
; ====================================================================
SECTION "InputModule", ROM1

; Entry_Input: Un teclado virtual genérico.
; Entradas (a través de variables globales WRAM para evitar registros):
;   - InputPromptAddr: Puntero a la cadena de prompt.
;   - InputDestBufAddr: Puntero al buffer de destino.
;   - InputMaxLen: Longitud máxima del buffer.
Entry_Input:
    call Input_Init
.input_loop:
    call Input_DrawUI
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b, jr z, .input_loop
    ld a, b, ld [JoyPrevState], a

    bit BUTTON_LEFT_BIT, b
    jr nz, .handle_left
    bit BUTTON_RIGHT_BIT, b
    jr nz, .handle_right
    bit BUTTON_A_BIT, b
    jr nz, .handle_a
    bit BUTTON_B_BIT, b
    jr nz, .handle_b
    bit BUTTON_START_BIT, b
    jr nz, .handle_start
    jr .input_loop

.handle_left:
    ld a, [InputCursorPos]
    or a
    jr z, .wrap_right
    dec a
    jr .update_cursor
.wrap_right: ld a, CharsetLen - 1
.update_cursor:
    ld [InputCursorPos], a
    call PlayBeepNav
    jr .input_loop

.handle_right:
    ld a, [InputCursorPos]
    inc a
    cp CharsetLen
    jr c, .update_cursor
    xor a
    jr .update_cursor

.handle_a: ; Añadir caracter
    ld a, [InputLen]
    ld b, a
    ld a, [InputMaxLen]
    cp b
    jr z, .buffer_full
    ld a, [InputCursorPos]
    call GetCharsetFromIndex
    call Input_AddChar
    call PlayBeepConfirm
    jr .input_loop
.buffer_full:
    call PlayBeepError
    jr .input_loop

.handle_b: ; Borrar caracter
    call Input_Backspace
    call PlayBeepNav
    jr .input_loop

.handle_start: ; Confirmar y salir
    call PlayBeepConfirm
    ret

; --- Subrutinas de Lógica ---
Input_Init:
    xor a
    ld [InputCursorPos], a
    ld [InputLen], a
    ld a, [InputDestBufAddr]
    ld l, a
    ld a, [InputDestBufAddr+1]
    ld h, a
    ld [hl], 0 ; Asegurar que el buffer de destino empieza vacío
    ret

Input_AddChar: ; Entrada: A = caracter a añadir
    ld hl, [InputDestBufAddr]
    ld a, [InputLen]
    ld c, a
    ld b, 0
    add hl, bc
    ld a, [sp+2]
    ld [hl+], a
    xor a
    ld [hl], a
    ld hl, InputLen
    inc [hl]
    ret

Input_Backspace:
    ld a, [InputLen]
    or a
    ret z
    dec [InputLen]
    ld a, [InputLen]
    ld c, a
    ld b, 0
    ld hl, [InputDestBufAddr]
    add hl, bc
    xor a
    ld [hl], a
    ret

GetCharsetFromIndex: ; Entrada: A = índice, Salida: A = caracter
    push hl, bc
    ld hl, Charset
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl]
    pop bc, hl
    ret

; --- Rutina de Dibujo ---
Input_DrawUI:
    call UI_ClearScreen
    ld a, 1
    ld b, 1
    ld c, 18
    ld d, 16
    call UI_DrawBox
    ; Prompt
    ld hl, [InputPromptAddr]
    ld d, 3
    ld e, 2
    call UI_PrintStringAtXY
    ; Buffer de entrada
    ld hl, [InputDestBufAddr]
    ld d, 5
    ld e, 2
    call UI_PrintStringAtXY
    ; Selector de caracteres
    ld a, [InputCursorPos]
    call GetCharsetFromIndex
    ld d, 8
    ld e, 9
    call UI_PrintAtXY
    ld a, '<'
    ld d, 8
    ld e, 8
    call UI_PrintAtXY
    ld a, '>'
    ld d, 8
    ld e, 10
    call UI_PrintAtXY
    ; Instrucciones
    ld hl, InputInstructions
    ld d, 12
    ld e, 2
    call UI_PrintStringAtXY
    ret

; ====================================================================
; Datos y Variables
; ====================================================================
SECTION "InputData", ROM1
Charset: DB "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.", CharsetLen EQU $-Charset
InputInstructions: DB "A:Anadir B:Borrar",0, "Start:Confirmar",0

SECTION "InputVars", WRAM0[$C200]
InputCursorPos:   DS 1
InputLen:         DS 1
InputPromptAddr:  DW 1 ; Puntero a la cadena de prompt
InputDestBufAddr: DW 1 ; Puntero al buffer de destino
InputMaxLen:      DB 1 ; Longitud máxima del buffer
