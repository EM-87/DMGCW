; assert.inc - Macros de aserciones para validación en tiempo de ensamblado
; Autor: DMG Cold Wallet Team
; Fecha: 2025

; ASSERT - Verifica una condición en tiempo de ensamblado
; Si la condición es falsa, genera un error y detiene el ensamblado
; Uso: ASSERT condición, "mensaje de error"
ASSERT: MACRO
    IF !(\1)
        FAIL "Aserción fallida: \2"
    ENDC
ENDM

; STATIC_ASSERT - Alias para ASSERT que enfatiza su uso para verificaciones estáticas
; Uso: STATIC_ASSERT condición, "mensaje de error"
STATIC_ASSERT: MACRO
    ASSERT \1, \2
ENDM

; ASSERT_BANK - Verifica que una dirección está en el banco correcto
; Uso: ASSERT_BANK dirección, banco_esperado
ASSERT_BANK: MACRO
    IF ((\1) >> 14) != (\2)
        FAIL "Dirección $\1 no está en el banco \2"
    ENDC
ENDM

; ASSERT_RANGE - Verifica que un valor está dentro de un rango [min, max]
; Uso: ASSERT_RANGE valor, min, max
ASSERT_RANGE: MACRO
    IF ((\1) < (\2)) || ((\1) > (\3))
        FAIL "Valor \1 fuera de rango [\2, \3]"
    ENDC
ENDM

; ASSERT_SIZE - Verifica que un tamaño no excede un límite
; Uso: ASSERT_SIZE tamaño, máximo, "mensaje"
ASSERT_SIZE: MACRO
    IF (\1) > (\2)
        FAIL "Tamaño excedido: \3 (\1 > \2 bytes)"
    ENDC
ENDM

; STATIC_WARNING - Muestra una advertencia en tiempo de ensamblado
; Uso: STATIC_WARNING condición, "mensaje de advertencia"
STATIC_WARNING: MACRO
    IF !(\1)
        WARN "Advertencia: \2"
    ENDC
ENDM

; DEBUG_MSG - Muestra un mensaje solo si DEBUG está definido
; Uso: DEBUG_MSG "mensaje de depuración"
DEBUG_MSG: MACRO
    IF DEF(DEBUG)
        PRINT "\1"
    ENDC
ENDM
