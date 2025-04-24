; rs_ecc.asm - Algoritmo Reed-Solomon para generación de QR
INCLUDE "../inc/hardware.inc"
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
    push af
    push bc
    push de
    push hl
    
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
    pop hl
    push hl
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
    
    jr .done
    
.result_zero:
    ld l, 0
    
.done:
    pop hl
    ld a, l
    push af
    pop af
    pop de
    pop bc
    pop af
    ret

; --- Datos ---
SECTION "RS_Data", ROM1
; Coeficientes del polinomio generador para QR V1, Level L
RS_Generator:
    DB $01, $19, $C4, $6A, $AC, $4D, $2F

; Tablas de logaritmos y antilogaritmos para GF(256)
; Estas tablas son precalculadas para multiplicación en GF(256)
; usando el polinomio primitivo x^8 + x^4 + x^3 + x^2 + 1

; Log base (α=2) para GF(256)
RS_GFLog:
    ; 256 bytes: índice -> logaritmo
    DB 0,   0,   1,  25,   2,  50,  26, 198,   3, 223,  51, 238,  27, 104, 199,  75
    DB 4, 100, 224,  14,  52, 141, 239, 129,  28, 193, 105, 248, 200,   8,  76, 113
    DB 5, 138, 101,  47, 225,  36,  15,  33,  53, 147, 142, 218, 240,  18, 130,  69
    DB 29, 181, 194, 125, 106,  39, 249, 185, 201, 154,   9, 120,  77, 228, 114, 166
    DB 6, 191, 139,  98, 102, 221,  48, 253, 226, 152,  37, 179,  16, 145,  34, 136
    DB 54, 208, 148, 206, 143, 150, 219, 189, 241, 210,  19,  92, 131,  56,  70,  64
    DB 30,  66, 182, 163, 195,  72, 126, 110, 107,  58,  40,  84, 250, 133, 186,  61
    DB 202,  94, 155, 159,  10,  21, 121,  43,  78, 212, 229, 172, 115, 243, 167,  87
    DB 7, 112, 192, 247, 140, 128,  99,  13, 103,  74, 222, 237,  49, 197, 254,  24
    DB 227, 165, 153, 119,  38, 184, 180, 124,  17,  68, 146, 217,  35,  32, 137,  46
    DB 55,  63, 209,  91, 149, 188, 207, 205, 144, 135, 151, 178, 220, 252, 190,  97
    DB 242,  86, 211, 171,  20,  42,  93, 158, 132,  60,  57,  83,  71, 109,  65, 162
    DB 31,  45,  67, 216, 183, 123, 164, 118, 196,  23,  73, 236, 127,  12, 111, 246
    DB 108, 161,  59,  82,  41, 157,  85, 170, 251,  96, 134, 177, 187, 204,  62,  90
    DB 203,  89,  95, 176, 156, 169, 160,  81,  11, 245,  22, 235, 122, 117,  44, 215
    DB 79, 174, 213, 233, 230, 231, 173, 232, 116, 214, 244, 234, 168,  80,  88, 175

; Antilogaritmo: 2^n en GF(256)
RS_GFAntiLog:
    ; 256 bytes: logaritmo -> valor
    DB   1,   2,   4,   8,  16,  32,  64, 128,  29,  58, 116, 232, 205, 135,  19,  38
    DB  76, 152,  45,  90, 180, 117, 234, 201, 143,   3,   6,  12,  24,  48,  96, 192
    DB 157,  39,  78, 156,  37,  74, 148,  53, 106, 212, 181, 119, 238, 193, 159,  35
    DB  70, 140,   5,  10,  20,  40,  80, 160,  93, 186, 105, 210, 185, 111, 222, 161
    DB  95, 190,  97, 194, 153,  47,  94, 188, 101, 202, 137,  15,  30,  60, 120, 240
    DB 253, 231, 211, 187, 107, 214, 177, 127, 254, 225, 223, 163,  91, 182, 113, 226
    DB 217, 175,  67, 134,  17,  34,  68, 136,  13,  26,  52, 104, 208, 189, 103, 206
    DB 129,  31,  62, 124, 248, 237, 199, 147,  59, 118, 236, 197, 151,  51, 102, 204
    DB 133,  23,  46,  92, 184, 109, 218, 169,  79, 158,  33,  66, 132,  21,  42,  84
    DB 168,  77, 154,  41,  82, 164,  85, 170,  73, 146,  57, 114, 228, 213, 183, 115
    DB 230, 209, 191,  99, 198, 145,  63, 126, 252, 229, 215, 179, 123, 246, 241, 255
    DB 227, 219, 171,  75, 150,  49,  98, 196, 149,  55, 110, 220, 165,  87, 174,  65
    DB 130,  25,  50, 100, 200, 141,   7,  14,  28,  56, 112, 224, 221, 167,  83, 166
    DB  81, 162,  89, 178, 121, 242, 249, 239, 195, 155,  43,  86, 172,  69, 138,   9
    DB  18,  36,  72, 144,  61, 122, 244, 245, 247, 243, 251, 235, 203, 139,  11,  22
    DB  44,  88, 176, 125, 250, 233, 207, 131,  27,  54, 108, 216, 173,  71, 142,   1

; --- Variables en RAM ---
SECTION "RS_Vars", WRAM0[$CB00]
RS_Buffer:   DS RS_GENERATOR_SIZE
RS_DataLen:  DS 1
