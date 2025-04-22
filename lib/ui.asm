; ui.asm - Primitivas de interfaz gráfica para DMG Cold Wallet
INCLUDE "hardware.inc"
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
    ld bc, 32*18 ; 32 columnas * 18 filas visibles
    ld a, " "    ; Caracter espacio
    
.loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    
    ; Restaurar 'a' a espacio
    ld a, " "
    
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
    
    ; Guardar posición y dimensiones
    ld h, a    ; H = x
    ld l, b    ; L = y
    
    ; Calcular posición en VRAM
    call UI_SetVRAMPosition
    
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
    
    ; Dibujar bordes laterales y contenido
    ld b, d     ; b = alto
    dec b       ; Alto - 2 (por las esquinas)
    dec b
    
.rows:
    push bc
    
    ; Avanzar a la siguiente fila
    ld a, l
    inc a
    ld l, a
    call UI_SetVRAMPosition
    
    ; Dibujar borde izquierdo
    ld a, "|"
    ld [hl+], a
    
    ; Dibujar espacios en el centro
    ld a, " "
    ld b, c
    dec b
    dec b
    
.spaces:
    ld [hl+], a
    dec b
    jr nz, .spaces
    
    ; Dibujar borde derecho
    ld a, "|"
    ld [hl], a
    
    pop bc
    dec b
    jr nz, .rows
    
    ; Dibujar borde inferior
    ld a, l
    inc a
    ld l, a
    call UI_SetVRAMPosition
    
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
    push bc
    push hl
    
    ; Preservar carácter
    ld b, a
    
    ; Calcular posición en VRAM
    ld h, e    ; x
    ld l, d    ; y
    call UI_SetVRAMPosition
    
    ; Escribir carácter
    ld a, b
    ld [hl], a
    
    pop hl
    pop bc
    ret

; UI_PrintStringAtXY: Imprime una cadena en la posición especificada
; Entrada: HL=puntero a cadena, D=y, E=x
UI_PrintStringAtXY:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    ld a, e    ; x
    ld b, d    ; y
    call UI_CalculateVRAMPosition ; HL = posición en VRAM
    
    ; Guardar posición VRAM en DE
    ld d, h
    ld e, l
    
    ; Restaurar puntero a cadena
    pop hl
    push hl
    
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
    ld b, 0    ; B = contador de caracteres
    push hl
    
.strLen:
    ld a, [hl+]
    or a
    jr z, .gotLen
    inc b
    jr .strLen
    
.gotLen:
    ; Restaurar puntero a cadena
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
    push hl
    
    ; Calcular posición en VRAM
    ld h, e    ; x
    ld l, d    ; y
    call UI_SetVRAMPosition
    
    ; Limpiar línea con espacios
    ld a, " "
    
.loop:
    ld [hl+], a
    dec b
    jr nz, .loop
    
    pop hl
    pop af
    ret

; UI_WaitVBlank: Espera a que ocurra una interrupción VBlank
UI_WaitVBlank:
    ; Esperar a que LCD esté en VBlank
    push af
    
.wait:
    ; Leer registro STAT
    ld a, [rSTAT]
    and STATF_BUSY    ; Comprobar si LCD está ocupado
    jr nz, .wait      ; Si está ocupado, seguir esperando
    
    pop af
    ret

; --- Funciones auxiliares internas ---

; UI_SetVRAMPosition: Establece HL a la posición VRAM para coordenadas (H,L)
; Entrada: H=x, L=y
; Salida: HL=dirección en VRAM
UI_SetVRAMPosition:
    push af
    push bc
    push de
    
    ; HL = _SCRN0 + y * 32 + x
    ld a, l        ; A = y
    ld l, 0
    ld c, 32
    call UI_Multiply  ; HL = y * 32
    
    ld a, h        ; A = x
    ld h, 0
    ld l, a        ; HL = x
    add hl, bc     ; HL = y * 32 + x
    
    ld bc, _SCRN0
    add hl, bc     ; HL = _SCRN0 + y * 32 + x
    
    pop de
    pop bc
    pop af
    ret

; UI_CalculateVRAMPosition: Calcula la dirección VRAM para coordenadas (A,B)
; Entrada: A=x, B=y
; Salida: HL=dirección en VRAM
UI_CalculateVRAMPosition:
    push de
    
    ; HL = _SCRN0 + y * 32 + x
    ld d, 0
    ld e, b        ; DE = y
    ld h, 0
    ld l, 32
    call UI_MultiplyHL_DE  ; HL = y * 32
    
    ld b, 0
    ld c, a        ; BC = x
    add hl, bc     ; HL = y * 32 + x
    
    ld bc, _SCRN0
    add hl, bc     ; HL = _SCRN0 + y * 32 + x
    
    pop de
    ret

; UI_Multiply: Multiplica A por C, resultado en HL
; Entrada: A, C = operandos
; Salida: HL = A * C
UI_Multiply:
    ld b, 0        ; BC = C
    ld h, 0
    ld l, a        ; HL = A
    
    ; Si alguno es cero, resultado es cero
    or a
    ret z
    
    ld a, c
    or a
    ret z
    
    ; HL = HL * BC
    call UI_MultiplyHL_BC
    ret

; UI_MultiplyHL_BC: Multiplica HL por BC
; Entrada: HL, BC = operandos
; Salida: HL = HL * BC
UI_MultiplyHL_BC:
    ; Preservar DE
    push de
    
    ; Guardar valor original de HL
    ld d, h
    ld e, l
    
    ; Inicializar resultado
    ld hl, 0
    
.loop:
    ; Verificar si BC es cero
    ld a, b
    or c
    jr z, .done
    
    ; Sumar HL += DE
    add hl, de
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.done:
    pop de
    ret

; UI_MultiplyHL_DE: Multiplica HL por DE
; Entrada: HL, DE = operandos
; Salida: HL = HL * DE
UI_MultiplyHL_DE:
    ; Similar a UI_MultiplyHL_BC pero usando DE como segundo operando
    push bc
    
    ; Guardar valor original de HL
    ld b, h
    ld c, l
    
    ; Inicializar resultado
    ld hl, 0
    
.loop:
    ; Verificar si DE es cero
    ld a, d
    or e
    jr z, .done
    
    ; Sumar HL += BC
    add hl, bc
    
    ; Decrementar contador
    dec de
    jr .loop
    
.done:
    pop bc
    ret
