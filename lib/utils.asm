; ====================================================================
; Archivo: utils.asm - Funciones de utilidades comunes para DMG Cold Wallet
; Versión corregida y robusta.
; ====================================================================

INCLUDE "../inc/hardware.inc"
INCLUDE "../inc/constants.inc"
; Declarar variables globales que se usarán aquí
EXTERN JoyState, JoyPrevState

; ------------------------------------------------------------
; CopyString: Copia una cadena de Source (HL) a Dest (DE)
; Garantiza un terminador nulo y respeta el límite de BC.
; Entradas: HL = puntero source, DE = puntero dest, BC = límite
; ------------------------------------------------------------
CopyString:
    push af
    push bc
    push de
    push hl
.loop:
    ld a, b
    or c
    jr z, .limit_reached ; Salta si BC llega a 0

    ld a, [hl+]
    ld [de], a
    inc de
    dec bc

    or a ; Comprueba si el carácter copiado era el terminador nulo
    jr nz, .loop
    jr .done ; Si era nulo, la copia está completa y terminada

.limit_reached:
    ; Forzar terminador nulo si se alcanzó el límite.
    ; DE ya apunta a la posición siguiente, así que retrocedemos uno.
    dec de
    xor a
    ld [de], a

.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; ------------------------------------------------------------
; FillMemory: Llena un bloque de memoria con un valor
; Entradas: HL = puntero, BC = cantidad, A = valor
; ------------------------------------------------------------
FillMemory:
    push bc
    push hl
    ld d, a ; Guardar el valor a rellenar para no perderlo en el bucle
.loop:
    ld a, b
    or c
    jr z, .done_fill ; Terminar si BC es 0

    ld a, d
    ld [hl+], a
    dec bc
    jr .loop
.done_fill:
    pop hl
    pop bc
    ret

; ------------------------------------------------------------
; CopyMemory: Copia BC bytes desde HL a DE
; Entradas: HL = origen, DE = destino, BC = cantidad
; ------------------------------------------------------------
EXPORT CopyMemory
CopyMemory:
    push af
    push bc
    push de
    push hl
.copy_loop:
    ld a, b
    or c
    jr z, .done_copy

    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    jr .copy_loop
.done_copy:
    pop hl
    pop de
    pop bc
    pop af
    ret

; ------------------------------------------------------------
; StringLength: Devuelve la longitud de una cadena
; Entradas: HL = puntero a la cadena
; Salida: A = longitud
; ------------------------------------------------------------
StringLength:
    push hl
    xor a ; Contador de longitud
.loop:
    ld d, [hl+]
    or d
    jr z, .done_len
    inc a
    jr .loop
.done_len:
    pop hl
    ret

; ------------------------------------------------------------
; WaitButton: Espera la pulsación Y LIBERACIÓN de un botón.
; Entradas: A = Máscara del botón (ej. BUTTON_A_BIT)
; ------------------------------------------------------------
WaitButton:
    push bc
    ld b, a ; Guardar la máscara del botón en B
.wait_press:
    call ReadJoypadWithDebounce
    ld a, [JoyState]
    and b
    jr z, .wait_press ; Esperar a que el bit del botón esté activo

.wait_release:
    call ReadJoypadWithDebounce
    ld a, [JoyState]
    and b
    jr nz, .wait_release ; Esperar a que el bit del botón esté inactivo

    pop bc
    ret

; ------------------------------------------------------------
; WaitVBlank: Espera a la próxima interrupción VBlank de forma segura.
; ------------------------------------------------------------
WaitVBlank:
    push af
.wait:
    ld a, [rLY]
    cp 144 ; VRAM es accesible durante el VBlank (líneas 144-153)
    jr c, .wait
    pop af
    ret

; ------------------------------------------------------------
; ReadJoypadWithDebounce: Lee el joypad con debounce.
; Esta es la implementación completa y correcta.
; ------------------------------------------------------------
ReadJoypadWithDebounce:
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    ret z ; Sin cambios, salir

    ld a, b
    ld [JoyPrevState], a

    ; Esperar frames de debounce para estabilizar la lectura
    ld b, DEBOUNCE_FRAMES
.delay_loop:
    push bc
    call WaitVBlank
    pop bc
    dec b
    jr nz, .delay_loop

    call ReadJoypad ; Releer para obtener el estado final estable
    ret

; ------------------------------------------------------------
; ReadJoypad: Lectura de bajo nivel del registro P1.
; ------------------------------------------------------------
ReadJoypad:
    push bc
    ; Leer cruceta (P14=1)
    ld a, P1F_GET_DPAD
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    cpl
    and $0F
    swap a
    ld b, a
    ; Leer botones (P15=1)
    ld a, P1F_GET_BTN
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    cpl
    and $0F
    or b
    ld [JoyState], a
    ; Restaurar P1 para que no interfiera
    ld a, P1F_GET_NONE
    ld [rP1], a
    pop bc
    ret

; ====================================================================
; Fin de utils.asm
; ====================================================================
