; utils.asm - Utilidades generales para DMG Cold Wallet
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

; --- Funciones de manejo de memoria ---

; CopyMemory: Copia BC bytes desde HL a DE
CopyMemory:
    ; Preservar registros
    push af
    push bc
    push de
    push hl
    
.loop:
    ; Verificar si quedan bytes por copiar
    ld a, b
    or c
    jr z, .done
    
    ; Copiar byte
    ld a, [hl+]
    ld [de], a
    inc de
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; FillMemory: Llena BC bytes en HL con valor en A
FillMemory:
    ; Preservar registros
    push bc
    push de
    push hl
    
.loop:
    ; Verificar si quedan bytes por llenar
    ld a, b
    or c
    jr z, .done
    
    ; Llenar byte
    ld [hl+], a
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.done:
    pop hl
    pop de
    pop bc
    ret

; CopyString: Copia cadena terminada en 0 de HL a DE
; Se detiene al encontrar terminador o después de BC bytes
CopyString:
    ; Preservar registros
    push af
    push bc
    push de
    push hl
    
.loop:
    ; Verificar si quedan bytes por copiar en límite
    ld a, b
    or c
    jr z, .limit_reached
    
    ; Leer byte
    ld a, [hl]
    
    ; Verificar terminador
    or a
    jr z, .done
    
    ; Copiar byte
    ld [de], a
    
    ; Avanzar punteros
    inc hl
    inc de
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.limit_reached:
    ; Asegurar terminador después del límite
    xor a
    ld [de], a
    
.done:
    ; Asegurar terminador
    xor a
    ld [de], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Funciones de conversión ---

; ByteToHex: Convierte byte en A a representación hexadecimal
; Entrada: A = byte a convertir
; Salida: HL = puntero a buffer con string hex + terminador
ByteToHex:
    ; Preservar registros
    push af
    push bc
    push de
    
    ; Guardar valor original
    ld b, a
    
    ; Convertir nibble alto
    srl a
    srl a
    srl a
    srl a
    call .NibbleToChar
    ld [HexBuffer], a
    
    ; Convertir nibble bajo
    ld a, b
    and $0F
    call .NibbleToChar
    ld [HexBuffer+1], a
    
    ; Agregar terminador
    xor a
    ld [HexBuffer+2], a
    
    ; Devolver puntero a buffer
    ld hl, HexBuffer
    
    pop de
    pop bc
    pop af
    ret
    
.NibbleToChar:
    ; Convierte un valor 0-15 a carácter hexadecimal
    cp 10
    jr c, .Digit
    
    ; Es A-F
    add "A" - 10
    ret
    
.Digit:
    ; Es 0-9
    add "0"
    ret

; --- Funciones matemáticas ---

; Multiply: Multiplica HL por BC
; Entrada: HL, BC = operandos
; Salida: HL = HL * BC
Multiply:
    ; Si alguno es cero, resultado es cero
    ld a, h
    or l
    jr z, .zero
    
    ld a, b
    or c
    jr z, .zero
    
    ; Guardar valor original de HL
    push de
    ld d, h
    ld e, l
    
    ; Inicializar resultado
    ld hl, 0
    
.loop:
    ; Sumar HL += DE
    add hl, de
    
    ; Decrementar contador
    dec bc
    
    ; Verificar si terminamos
    ld a, b
    or c
    jr nz, .loop
    
    pop de
    ret
    
.zero:
    ; Resultado es cero
    ld hl, 0
    ret

; --- Funciones de comparación ---

; CompareString: Compara dos cadenas terminadas en 0
; Entrada: HL, DE = punteros a cadenas
; Salida: Z=1 si iguales, Z=0 si diferentes
;         C=1 si HL < DE, C=0 si HL >= DE
CompareString:
    ; Preservar registros
    push hl
    push de
    
.loop:
    ; Leer bytes
    ld a, [de]
    ld b, [hl]
    
    ; Comparar
    cp b
    jr nz, .different
    
    ; Si ambos son terminadores, cadenas iguales
    or a
    jr z, .equal
    
    ; Avanzar punteros
    inc hl
    inc de
    jr .loop
    
.different:
    ; Restaurar registros con flags intactos
    pop de
    pop hl
    ret
    
.equal:
    ; Restaurar registros con Z=1
    pop de
    pop hl
    xor a  ; Asegurar Z=1
    ret

; CompareMemory: Compara dos bloques de memoria
; Entrada: HL, DE = punteros a bloques, BC = tamaño
; Salida: Z=1 si iguales, Z=0 si diferentes
CompareMemory:
    ; Preservar registros
    push hl
    push de
    push bc
    
.loop:
    ; Verificar si queda por comparar
    ld a, b
    or c
    jr z, .equal
    
    ; Leer bytes
    ld a, [de]
    cp [hl]
    jr nz, .different
    
    ; Avanzar punteros
    inc hl
    inc de
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.different:
    ; Restaurar registros con flags intactos (Z=0)
    pop bc
    pop de
    pop hl
    ret
    
.equal:
    ; Restaurar registros con Z=1
    pop bc
    pop de
    pop hl
    xor a  ; Asegurar Z=1
    ret

; --- Variables ---
SECTION "Utils_Vars", WRAM0[$CD00]
HexBuffer:    DS 3   ; Buffer para conversión a hex (2 caracteres + null)