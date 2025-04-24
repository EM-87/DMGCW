; debug.asm - Utilidades de depuración para DMG Cold Wallet
; Solo se incluyen en compilaciones de debug (cuando DEBUG=1)
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

IF DEF(DEBUG)

; --- Constantes para depuración ---
DEBUG_X          EQU 1    ; Posición X para mensajes de depuración
DEBUG_Y          EQU 16   ; Posición Y para mensajes de depuración
DEBUG_WIDTH      EQU 18   ; Ancho de la ventana de depuración
DEBUG_HEIGHT     EQU 2    ; Alto de la ventana de depuración

; --- Macro para mostrar valor en pantalla ---
; SHOW_VALUE: Macro para mostrar un valor en pantalla
; Uso: SHOW_VALUE etiqueta, valor
SHOW_VALUE: MACRO
    push af
    push bc
    push de
    push hl
    
    ld hl, \1
    ld d, DEBUG_Y
    ld e, DEBUG_X
    call Debug_PrintStringAtXY
    
    ld a, \2
    call Debug_PrintHexByte
    
    pop hl
    pop de
    pop bc
    pop af
ENDM

; --- Funciones de depuración ---

; Debug_Init: Inicializa el sistema de depuración
Debug_Init:
    ; Limpiar área de depuración
    call Debug_ClearArea
    
    ; Mostrar mensaje de depuración inicial
    ld hl, DebugReadyMsg
    ld d, DEBUG_Y
    ld e, DEBUG_X
    call Debug_PrintStringAtXY
    
    ret

; Debug_ClearArea: Limpia el área de depuración
Debug_ClearArea:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    ld h, 0
    ld l, DEBUG_Y
    ld bc, SCRN_VX_B
    call Multiply      ; HL = DEBUG_Y * SCRN_VX_B
    
    ld bc, _SCRN0
    add hl, bc         ; HL = _SCRN0 + (DEBUG_Y * SCRN_VX_B)
    
    ld bc, DEBUG_X
    add hl, bc         ; HL += DEBUG_X
    
    ; Limpiar área de DEBUG_WIDTH x DEBUG_HEIGHT
    ld d, DEBUG_HEIGHT
.row_loop:
    push hl
    
    ld bc, DEBUG_WIDTH
    ld a, " "
.col_loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .col_loop
    
    pop hl
    
    ; Avanzar a la siguiente fila
    ld bc, SCRN_VX_B
    add hl, bc
    
    dec d
    jr nz, .row_loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; Debug_PrintStringAtXY: Imprime una cadena en la posición especificada
; Entrada: HL = puntero a cadena, D = Y, E = X
Debug_PrintStringAtXY:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    ld a, d
    ld b, a
    ld a, e
    ld c, a
    call GetVRAMPosition
    
    ; HL = posición en VRAM
    ; Guardar HL en DE
    ld d, h
    ld e, l
    
    ; Recuperar puntero a cadena
    pop hl
    push hl
    
.loop:
    ; Leer carácter
    ld a, [hl+]
    
    ; Verificar fin de cadena
    or a
    jr z, .done
    
    ; Escribir carácter en VRAM
    ld [de], a
    inc de
    
    jr .loop
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; Debug_PrintHexByte: Imprime un byte en formato hexadecimal
; Entrada: A = byte a imprimir
Debug_PrintHexByte:
    push af
    push bc
    push de
    push hl
    
    ; Convertir a hexadecimal
    ld b, a
    
    ; Nibble alto
    ld a, b
    swap a
    and $0F
    call .hex_digit
    ld c, a
    
    ; Calcular posición en VRAM
    ld a, DEBUG_Y
    ld h, a
    ld a, DEBUG_X + 10  ; Posición fija después de etiqueta
    ld l, a
    call GetVRAMPosition
    
    ; Escribir nibble alto
    ld a, c
    ld [hl+], a
    
    ; Nibble bajo
    ld a, b
    and $0F
    call .hex_digit
    
    ; Escribir nibble bajo
    ld [hl], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret
    
.hex_digit:
    ; Convierte un valor de 0-F a carácter ASCII
    cp 10
    jr c, .is_digit
    
    ; Es A-F
    add "A" - 10
    ret
    
.is_digit:
    ; Es 0-9
    add "0"
    ret

; Debug_PrintNumber: Imprime un número decimal
; Entrada: A = número a imprimir
Debug_PrintNumber:
    push af
    push bc
    push de
    push hl
    
    ; Convertir a decimal (máximo 3 dígitos, 0-255)
    ld b, a
    
    ; Centenas
    ld a, b
    ld c, 100
    call .div
    add "0"
    ld [hl+], a
    
    ; Decenas
    ld a, b
    ld c, 10
    call .div
    add "0"
    ld [hl+], a
    
    ; Unidades
    ld a, b
    add "0"
    ld [hl], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret
    
.div:
    ; Divide A/C, guarda el cociente en A y el resto en B
    ld b, 0
.div_loop:
    cp c
    jr c, .div_done
    sub c
    inc b
    jr .div_loop
.div_done:
    ld a, b
    ret

; Debug_PrintRegisters: Imprime los valores de los registros
; Entrada: Se deben guardar los registros en el stack previamente
Debug_PrintRegisters:
    ; Esta función se usa con CALL Debug_PrintRegisters y requiere guardar registros
    ; en cierto orden antes de llamarla
    ret

; Debug_GetVRAMPosition: Calcula dirección VRAM para coordenadas X,Y
; Entrada: H = y, L = x
; Salida: HL = dirección en VRAM
GetVRAMPosition:
    push af
    push bc
    push de
    
    ; Calcular offset: y * 32 + x
    ld a, h
    ld h, 0
    ld d, 0
    ld e, a
    
    ; DE = y
    ld bc, SCRN_VX_B
    ; DE * BC = DE * 32
    call Multiply16  ; HL = y * 32
    
    ; Añadir X
    ld b, 0
    ld c, l
    add hl, bc
    
    ; Añadir base de VRAM
    ld bc, _SCRN0
    add hl, bc
    
    pop de
    pop bc
    pop af
    ret

; Multiply: Multiplica A por C
; Entrada: A, C = factores
; Salida: A = resultado
Multiply:
    push bc
    push de
    
    ld b, a
    ld d, 0
    ld e, 0
    
.multiply_loop:
    ld a, b
    or a
    jr z, .multiply_done
    
    dec b
    ld a, e
    add c
    ld e, a
    ld a, d
    adc 0
    ld d, a
    
    jr .multiply_loop
    
.multiply_done:
    ld a, e
    
    pop de
    pop bc
    ret

; Multiply16: Multiplica BC por DE
; Entrada: BC, DE = factores
; Salida: HL = resultado
Multiply16:
    push af
    
    ld hl, 0
    ld a, 16
    
.multiply16_loop:
    add hl, hl
    rl e
    rl d
    jr nc, .skip_add
    
    add hl, bc
    
.skip_add:
    dec a
    jr nz, .multiply16_loop
    
    pop af
    ret

; --- Mensajes de depuración ---
SECTION "DebugStrings", ROM0
DebugReadyMsg:    DB "DEBUG READY", 0
DebugValMsg:      DB "VAL: ", 0
DebugRegMsg:      DB "REG: ", 0

ENDC  ; IF DEF(DEBUG)
