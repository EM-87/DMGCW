
; debug.asm - Utilidades de depuración para DMG Cold Wallet
; Solo se incluyen en compilaciones de debug (cuando DEBUG=1)
INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"

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
    
    ; Usar UI_GetVRAMPosition de lib/ui.asm
    ld d, DEBUG_Y
    ld e, DEBUG_X
    call UI_GetVRAMPosition
    
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
    
    ; Usar UI_GetVRAMPosition para calcular posición
    push hl         ; Guardar puntero a cadena
    call UI_GetVRAMPosition
    ld d, h
    ld e, l         ; DE = posición en VRAM
    pop hl          ; Recuperar puntero a cadena
    
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
    ld d, DEBUG_Y
    ld e, DEBUG_X + 10  ; Posición fija después de etiqueta
    call UI_GetVRAMPosition
    
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
    
    ; Calcular posición inicial
    ld d, DEBUG_Y
    ld e, DEBUG_X + 10
    call UI_GetVRAMPosition
    
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
    ; Divide A/C, devuelve cociente en A y actualiza B con el resto
    push de
    ld d, 0         ; Contador del cociente
    
.div_loop:
    ld a, b
    cp c
    jr c, .div_done
    
    sub c
    ld b, a         ; B = resto
    inc d           ; Incrementar cociente
    jr .div_loop
    
.div_done:
    ld a, d         ; A = cociente
    pop de
    ret

; Debug_PrintRegisters: Imprime los valores de los registros
; Nota: Esta función requiere que los registros se guarden en el stack
; en un orden específico antes de llamarla
Debug_PrintRegisters:
    push af
    push bc
    push de
    push hl
    
    ; Mostrar AF
    ld hl, DebugRegAF
    ld d, DEBUG_Y
    ld e, DEBUG_X
    call Debug_PrintStringAtXY
    
    pop hl          ; Recuperar HL original
    push hl         ; Guardarlo de nuevo
    ld a, h
    call Debug_PrintHexByte
    ld a, l
    call Debug_PrintHexByte
    
    ; Aquí podrías continuar con otros registros...
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; Debug_BreakPoint: Punto de ruptura para depuración
; Detiene la ejecución hasta que se presione un botón
Debug_BreakPoint:
    push af
    push hl
    
    ; Mostrar mensaje de breakpoint
    ld hl, DebugBreakMsg
    ld d, DEBUG_Y
    ld e, DEBUG_X
    call Debug_PrintStringAtXY
    
    ; Esperar botón
.wait:
    call ReadJoypad
    ld a, [JoyState]
    and $F0         ; Cualquier botón
    jr z, .wait
    
    ; Esperar que se suelte
.release:
    call ReadJoypad
    ld a, [JoyState]
    and $F0
    jr nz, .release
    
    ; Limpiar mensaje
    call Debug_ClearArea
    
    pop hl
    pop af
    ret

; Debug_Assert: Verifica una condición y detiene si falla
; Entrada: A = valor a verificar (0 = falla)
;          HL = mensaje de error
Debug_Assert:
    or a
    ret nz          ; Si no es cero, todo bien
    
    push hl
    push de
    
    ; Mostrar mensaje de assert
    ld d, DEBUG_Y
    ld e, DEBUG_X
    call Debug_PrintStringAtXY
    
    ; Detener ejecución
.halt:
    halt
    jr .halt
    
    pop de
    pop hl
    ret

; Debug_MemDump: Muestra contenido de memoria
; Entrada: HL = dirección inicial, B = número de bytes
Debug_MemDump:
    push af
    push bc
    push de
    push hl
    
    ld d, DEBUG_Y
    ld e, DEBUG_X
    
.dump_loop:
    push bc
    
    ; Mostrar dirección
    ld a, h
    call Debug_PrintHexByte
    ld a, l
    call Debug_PrintHexByte
    
    ; Espacio
    ld a, " "
    push hl
    push de
    call UI_GetVRAMPosition
    ld a, " "
    ld [hl], a
    pop de
    pop hl
    
    ; Mostrar valor
    ld a, [hl+]
    call Debug_PrintHexByte
    
    ; Nueva línea
    inc d
    ld e, DEBUG_X
    
    pop bc
    dec b
    jr nz, .dump_loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Mensajes de depuración ---
SECTION "DebugStrings", ROM0
DebugReadyMsg:    DB "DEBUG ON", 0
DebugValMsg:      DB "VAL: ", 0
DebugRegAF:       DB "AF: ", 0
DebugRegBC:       DB "BC: ", 0
DebugRegDE:       DB "DE: ", 0
DebugRegHL:       DB "HL: ", 0
DebugBreakMsg:    DB "BREAK", 0
DebugAssertMsg:   DB "ASSERT!", 0

ENDC  ; IF DEF(DEBUG)
