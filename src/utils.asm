; ====================================================================
; Archivo: src/utils.asm - VERSIÓN FINAL Y CORREGIDA
; ====================================================================
INCLUDE "hardware.inc"
INCLUDE "inc/constants.inc"

; --- Funciones de manejo de memoria ---

; CopyMemory: Copia BC bytes desde HL a DE
CopyMemory:
    push af
    push bc
    push de
    push hl
.loopCM:
    ld a, b
    or c
    jr z, .doneCM
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    jr .loopCM
.doneCM:
    pop hl
    pop de
    pop bc
    pop af
    ret

; FillMemory: Llena BC bytes en HL con valor en A
FillMemory:
    push af          ; Preservar A, que contiene el valor de relleno
    push bc
    push de
    push hl
    
    ld d, a          ; Guardar el valor de relleno en D para no perderlo
.loopFM:
    ld a, b          ; Usar A temporalmente para comprobar el contador BC
    or c
    jr z, .doneFM
    ld a, d          ; Recuperar el valor de relleno desde D
    ld [hl+], a
    dec bc
    jr .loopFM
.doneFM:
    pop hl
    pop de
    pop bc
    pop af           ; Restaurar el valor original de A
    ret

; CopyString: Copia cadena terminada en 0 de HL a DE (máx. BC bytes)
; Garantiza un terminador nulo al final.
CopyString:
    push af
    push bc
    push de
    push hl
.loopCS:
    ld a, b
    or c
    jr z, .limit_reached  ; Límite de bytes alcanzado

    ld a, [hl+]           ; Leer carácter y avanzar puntero origen
    ld [de], a            ; Escribir carácter
    inc de                ; Avanzar puntero destino
    dec bc                ; Decrementar contador de límite

    or a                  ; Comprobar si el carácter era el terminador (0)
    jr nz, .loopCS        ; Si no, repetir el bucle
    jr .doneCS            ; Si sí, la copia está completa y terminada

.limit_reached:
    dec de                ; Retroceder para sobrescribir el último carácter copiado
    xor a                 ; a = 0
    ld [de], a            ; Forzar el terminador nulo

.doneCS:
    pop hl
    pop de
    pop bc
    pop af
    ret

; StringLength: Calcula la longitud de una cadena terminada en 0
; Entrada: HL = puntero a cadena
; Salida: A = longitud
StringLength:
    push bc
    push hl
    
    ld b, 0
.loopSL:
    ld a, [hl+]
    or a
    jr z, .doneSL
    inc b
    jr .loopSL
    
.doneSL:
    ld a, b
    
    pop hl
    pop bc
    ret

; --- Rutinas de I/O y temporización ---

; WaitButton: Espera pulsación y liberación de un botón.
; Entrada: A = máscara del botón (ej. PADB_B)
WaitButton:
    push af               ; Preservar flags y la máscara de botón
    push bc
    ld b, a               ; Guardar la máscara en B para no perderla
.wait:
    call ReadJoypad       ; Leer estado actual de los botones
    ld a, [JoyState]
    and b                 ; Aislar el botón que nos interesa
    jr z, .wait           ; Si es cero, no está presionado. Esperar.
.release:
    call ReadJoypad       ; El botón está presionado, ahora esperar a que se suelte
    ld a, [JoyState]
    and b
    jr nz, .release       ; Si no es cero, sigue presionado. Esperar.
    
    call PlayBeepNav      ; Dar feedback al usuario una vez se ha soltado el botón
    pop bc
    pop af
    ret

; DelayFrames: Espera A frames
; Entrada: A = número de frames a esperar
DelayFrames:
    push bc
    
    ld b, a
.loopDF:
    push bc
    call WaitVBlank
    pop bc
    dec b
    jr nz, .loopDF
    
    pop bc
    ret
    
; WaitVBlank: Espera al inicio del VBlank
WaitVBlank:
    push af
.waitVB:
    ld a, [rLY]
    cp 144
    jr c, .waitVB
    pop af
    ret

; --- Variables ---
SECTION "Utils_Vars", WRAM0[$CD00]
HexBuffer:    DS 3   ; Buffer para conversión a hex (2 caracteres + null)
