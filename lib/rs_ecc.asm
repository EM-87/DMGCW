; rs_ecc.asm - Algoritmo Reed-Solomon para generación de QR
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

; --- Constantes ---
; Polinomio generador para QR version 1, level L (7 bytes)
RS_GENERATOR_SIZE EQU 7

; --- API pública ---

; RS_GenerateECC: Genera bytes de corrección de errores Reed-Solomon
; Entrada: HL = puntero a datos, B = longitud
; Salida: DE = puntero a buffer de ECC (RS_GENERATOR_SIZE bytes)
RS_GenerateECC:
    push af
    push bc
    push hl
    
    ; Inicializar buffer ECC a ceros
    ld hl, RS_Buffer
    ld b, RS_GENERATOR_SIZE
    xor a
    
.clear_loop:
    ld [hl+], a
    dec b
    jr nz, .clear_loop
    
    ; Restaurar puntero a datos
    pop hl
    push hl
    
    ; Guardar longitud original
    ld a, b
    ld [RS_DataLen], a
    
    ; Procesar cada byte de datos
.process_loop:
    ; Verificar si quedan bytes por procesar
    ld a, [RS_DataLen]
    or a
    jr z, .done_processing
    
    ; Leer siguiente byte de datos
    ld a, [hl+]
    
    ; Aplicar XOR con primer byte de ECC
    ld c, a
    ld a, [RS_Buffer]
    xor c
    ld c, a ; C = byte líder
    
    ; Multiplicar por generador
    call RS_MultiplyGenerator
    
    ; Decrementar contador de bytes
    ld a, [RS_DataLen]
    dec a
    ld [RS_DataLen], a
    
    jr .process_loop
    
.done_processing:
    ; Devolver puntero a ECC
    ld de, RS_Buffer
    
    pop hl
    pop bc
    pop af
    ret

; --- Funciones auxiliares internas ---

; RS_MultiplyGenerator: Multiplica ECC actual por el polinomio generador
; Entrada: C = byte líder
RS_MultiplyGenerator:
    push af
    push bc
    push de
    push hl
    
    ; Desplazar ECC un byte a la izquierda (descartando byte 0)
    ld hl, RS_Buffer + 1
    ld de, RS_Buffer
    ld b, RS_GENERATOR_SIZE - 1
    
.shift_loop:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .shift_loop
    
    ; Último byte a 0
    xor a
    ld [de], a
    
    ; Si byte líder es 0, no multiplicar
    ld a, c
    or a
    jr z, .done
    
    ; Multiplicar generador por byte líder
    ld hl, RS_Generator
    ld de, RS_Buffer
    ld b, RS_GENERATOR_SIZE
    
.multiply_loop:
    ; Leer byte del generador
    ld a, [hl+]
    
    ; Multiplicar con byte líder en GF(256)
    push hl
    push de
    ld h, a
    ld l, c
    call RS_MultiplyGF256
    pop de
    pop hl
    
    ; XOR resultado con buffer ECC
    ld a, [de]
    xor l ; L tiene el resultado de la multiplicación
    ld [de], a
    
    ; Avanzar a siguiente byte
    inc de
    dec b
    jr nz, .multiply_loop
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; RS_MultiplyGF256: Multiplica dos bytes en campo de Galois GF(256)
; Entrada: H, L = operandos
; Salida: L = resultado
RS_MultiplyGF256:
    ; Para QR Level L, podemos usar tablas precalculadas
    ; Simplificado: suma los logaritmos y aplica antilogaritmo
    
    ; Si alguno es 0, resultado es 0
    ld a, h
    or a
    jr z, .result_zero
    
    ld a, l
    or a
    jr z, .result_zero
    
    ; Consultar logaritmo de H
    ld a, h
    ld hl, RS_GFLog
    ld b, 0
    ld c, a
    add hl, bc
    ld a, [hl]
    
    ; Guardar logaritmo de H
    ld b, a
    
    ; Consultar logaritmo de L original
    ld a, l
    ld hl, RS_GFLog
    ld c, a
    ld a, 0
    add hl, bc
    ld a, [hl]
    
    ; Sumar logaritmos (mod 255)
    add a, b
    cp 255
    jr c, .no_overflow
    sub 255
    
.no_overflow:
    ; Convertir suma a valor mediante antilogaritmo
    ld hl, RS_GFAntiLog
    ld b, 0
    ld c, a
    add hl, bc
    ld l, [hl]
    
    ret
    
.result_zero:
    ld l, 0
    ret

; --- Datos ---
SECTION "RS_Data", ROM1
; Coeficientes del polinomio generador para QR V1, Level L
RS_Generator:
    DB $01, $19, $C4, $6A, $AC, $4D, $2F

; Tablas de logaritmos y antilogaritmos para GF(256)
; Estas tablas son precalculadas para multiplicación en GF(256)
; usando el polinomio primitivo x^8 + x^4 + x^3 + x^2 + 1
RS_GFLog:
    ; 256 bytes: índice -> logaritmo
    DB 0,   0,   1,  25,   2,  50,  26, 198
    ; ... (resto de la tabla omitida por brevedad)
    
RS_GFAntiLog:
    ; 256 bytes: logaritmo -> valor
    DB 1,   2,   4,   8,  16,  32,  64, 128
    ; ... (resto de la tabla omitida por brevedad)
    
; --- Variables en RAM ---
SECTION "RS_Vars", WRAM0[$CB00]
RS_Buffer:   DS RS_GENERATOR_SIZE
RS_DataLen:  DS 1