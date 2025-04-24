; ui.asm - Primitivas de interfaz gráfica para DMG Cold Wallet
INCLUDE "../inc/hardware.inc"
INCLUDE "../inc/constants.inc"

; --- API pública ---

; UI_ClearScreen: Limpia toda la pantalla
UI_ClearScreen:
    ; Preservar registros
    push af
    push bc
    push de
    push hl
    
    ; Esperar a que VRAM esté disponible
    call UI_WaitVBlank
    
    ; Llenar pantalla con espacios
    ld hl, _SCRN0
    ld bc, SCRN_VX_B * SCRN_Y_B  ; Usar constantes definidas
    ld a, " "    ; Caracter espacio
    
.loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_DrawBox: Dibuja una caja con bordes
; Entrada: A=x, B=y, C=width, D=height
UI_DrawBox:
    ; Preservar registros
    push af
    push bc
    push de
    push hl
    
    ; Guardar parámetros originales
    push af    ; Guardar x
    push bc    ; Guardar y, width
    push de    ; Guardar height
    
    ; Calcular posición en VRAM
    ld e, a    ; E = x
    ld d, b    ; D = y
    call UI_GetVRAMPosition
    
    ; Dibujar esquina superior izquierda
    ld a, "+"
    ld [hl+], a
    
    ; Dibujar borde superior
    ld a, "-"
    ld b, c
    dec b    ; Ancho - 2 (por las esquinas)
    dec b
    
.topBorder:
    ld [hl+], a
    dec b
    jr nz, .topBorder
    
    ; Dibujar esquina superior derecha
    ld a, "+"
    ld [hl], a
    
    ; Restaurar parámetros para laterales
    pop de    ; height
    pop bc    ; y, width
    pop af    ; x
    
    push af   ; Guardar x
    push bc   ; Guardar y, width
    push de   ; Guardar height
    
    ; Dibujar bordes laterales
    ld e, d   ; E = height
    dec e     ; Alto - 2 (por las esquinas)
    dec e
    
.rows:
    ; Avanzar a la siguiente fila
    inc b     ; y++
    push de   ; Guardar contador de filas
    ld d, b   ; D = y
    ld e, a   ; E = x
    call UI_GetVRAMPosition
    pop de    ; Recuperar contador
    
    ; Dibujar borde izquierdo
    ld [hl], "|"
    
    ; Avanzar al borde derecho
    push de
    ld d, 0
    ld e, c   ; width
    dec e
    add hl, de
    pop de
    
    ; Dibujar borde derecho
    ld [hl], "|"
    
    dec e
    jr nz, .rows
    
    ; Restaurar y calcular posición para borde inferior
    pop de    ; height
    pop bc    ; y, width
    pop af    ; x
    
    ld d, b   ; D = y
    add d, e  ; D = y + height - 1
    dec d
    ld e, a   ; E = x
    
    call UI_GetVRAMPosition
    
    ; Dibujar esquina inferior izquierda
    ld a, "+"
    ld [hl+], a
    
    ; Dibujar borde inferior
    ld a, "-"
    ld b, c
    dec b
    dec b
    
.bottomBorder:
    ld [hl+], a
    dec b
    jr nz, .bottomBorder
    
    ; Dibujar esquina inferior derecha
    ld a, "+"
    ld [hl], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_PrintAtXY: Imprime un carácter en la posición especificada
; Entrada: A=carácter, D=y, E=x
UI_PrintAtXY:
    push af
    push bc
    push de
    push hl
    
    ; Preservar carácter
    push af
    
    ; Calcular posición en VRAM
    call UI_GetVRAMPosition
    
    ; Recuperar y escribir carácter
    pop af
    ld [hl], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_PrintStringAtXY: Imprime una cadena en la posición especificada
; Entrada: HL=puntero a cadena, D=y, E=x
UI_PrintStringAtXY:
    push af
    push bc
    push de
    push hl
    
    ; Guardar puntero a cadena
    push hl
    
    ; Calcular posición en VRAM
    call UI_GetVRAMPosition
    
    ; HL = posición VRAM, guardarlo en DE
    ld d, h
    ld e, l
    
    ; Recuperar puntero a cadena
    pop hl
    
.loop:
    ld a, [hl+]     ; Cargar siguiente carácter
    or a            ; Comprobar si es 0 (fin de cadena)
    jr z, .done     ; Si es 0, terminar
    
    ld [de], a      ; Escribir carácter
    inc de          ; Avanzar posición VRAM
    jr .loop        ; Repetir
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_PrintInBox: Imprime una cadena centrada en un cuadro
; Entrada: HL=puntero a cadena, C=box_x, D=box_y, E=box_width
UI_PrintInBox:
    push af
    push bc
    push de
    push hl
    
    ; Calcular longitud de la cadena
    push hl
    call UI_StringLength
    pop hl
    
    ; Calcular posición X centrada
    ld a, e    ; A = ancho del cuadro
    sub b      ; A = ancho - longitud
    srl a      ; A = (ancho - longitud) / 2
    add a, c   ; A = box_x + (ancho - longitud) / 2
    
    ; Imprimir cadena en posición calculada
    ld e, a    ; E = X centrada
    call UI_PrintStringAtXY
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_ClearLine: Limpia parte de una línea en la pantalla
; Entrada: D=y, E=x de inicio, B=longitud a limpiar
UI_ClearLine:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    call UI_GetVRAMPosition
    
    ; Limpiar línea con espacios
    ld a, " "
    
.loop:
    ld [hl+], a
    dec b
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_WaitVBlank: Espera a que ocurra una interrupción VBlank
UI_WaitVBlank:
    push af
    
.wait:
    ; Leer registro STAT
    ld a, [rSTAT]
    and STATF_BUSY    ; Comprobar si LCD está ocupado
    jr nz, .wait      ; Si está ocupado, seguir esperando
    
    pop af
    ret

; --- Funciones auxiliares internas unificadas ---

; UI_GetVRAMPosition: Calcula dirección VRAM para coordenadas (D,E)
; Entrada: D=y, E=x
; Salida: HL=dirección en VRAM
UI_GetVRAMPosition:
    push af
    push bc
    push de
    
    ; HL = _SCRN0 + y * 32 + x
    ld h, 0
    ld l, d        ; HL = y
    
    ; Optimización: multiplicar por 32 usando shifts
    add hl, hl     ; HL *= 2
    add hl, hl     ; HL *= 4
    add hl, hl     ; HL *= 8
    add hl, hl     ; HL *= 16
    add hl, hl     ; HL *= 32
    
    ld b, 0
    ld c, e        ; BC = x
    add hl, bc     ; HL += x
    
    ld bc, _SCRN0
    add hl, bc     ; HL += _SCRN0
    
    pop de
    pop bc
    pop af
    ret

; UI_StringLength: Calcula la longitud de una cadena
; Entrada: HL = puntero a cadena
; Salida: B = longitud
UI_StringLength:
    push af
    push hl
    
    ld b, 0    ; Contador
    
.loop:
    ld a, [hl+]
    or a
    jr z, .done
    inc b
    jr .loop
    
.done:
    pop hl
    pop af
    ret

; --- Funciones adicionales de utilidad ---

; UI_DrawHorizontalLine: Dibuja una línea horizontal
; Entrada: D=y, E=x inicial, B=longitud, C=carácter
UI_DrawHorizontalLine:
    push af
    push bc
    push de
    push hl
    
    call UI_GetVRAMPosition
    
    ld a, c    ; Carácter para la línea
    
.loop:
    ld [hl+], a
    dec b
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; UI_DrawVerticalLine: Dibuja una línea vertical
; Entrada: D=y inicial, E=x, B=longitud, C=carácter
UI_DrawVerticalLine:
    push af
    push bc
    push de
    push hl
    
.loop:
    push bc
    push de
    call UI_GetVRAMPosition
    
    ld a, c
    ld [hl], a
    
    pop de
    pop bc
    
    inc d      ; Siguiente fila
    dec b
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Macros para facilitar operaciones comunes ---

; PRINT_AT: Macro para imprimir en posición específica
; Uso: PRINT_AT cadena, x, y
PRINT_AT: MACRO
    ld hl, \1
    ld e, \2
    ld d, \3
    call UI_PrintStringAtXY
ENDM

; DRAW_BOX_AT: Macro para dibujar caja
; Uso: DRAW_BOX_AT x, y, width, height
DRAW_BOX_AT: MACRO
    ld a, \1
    ld b, \2
    ld c, \3
    ld d, \4
    call UI_DrawBox
ENDM

; --- Mensajes de error para UI ---
SECTION "UIMessages", ROM0
UI_NoMemoryMsg:    DB "Error: No hay memoria", 0
UI_VRAMBusyMsg:    DB "Error: VRAM ocupada", 0
