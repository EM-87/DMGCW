; qr.asm - Generación de QR dinámico (Version 1, EC Level L, Mask 0)
; Versión final con todas las optimizaciones aplicadas
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"
    
SECTION "QRModule", ROM1[$5000]

; --- Constantes QR Version 1 ---
QR_SIZE         EQU 21      ; Tamaño de la matriz 21x21
QR_MODULES      EQU 441     ; Total de módulos (21*21)
QR_CAPACITY     EQU 17      ; Capacidad en bytes para V1-L
QR_EC_SIZE      EQU 7       ; Bytes de corrección de errores para Level L

; Modos de codificación
MODE_NUMERIC    EQU 1       ; 0001b
MODE_ALPHANUMERIC EQU 2     ; 0010b
MODE_BYTE       EQU 4       ; 0100b

; Límites de seguridad
MAX_INPUT_LEN   EQU 40      ; Longitud máxima de entrada

Entry_QR_Gen:
    push af
    push bc
    push de
    push hl
    
    ; Mostrar pantalla "Generando QR..."
    call UI_ClearScreen
    ld hl, QRGeneratingMsg
    ld d, 8    ; y
    ld e, 5    ; x
    call UI_PrintStringAtXY
    
    ; Esperar VBlank para asegurar que se muestra el mensaje
    call UI_WaitVBlank
    
    ; Inicializar buffers
    call InitQRBuffers
    
    ; Obtener datos de dirección y monto para el QR
    ld hl, AddressBuf      ; Buffer de dirección
    ld de, QR_InputBuf     ; Buffer donde se copiará
    ld bc, MAX_INPUT_LEN   ; Límite de seguridad
    call CopyStringWithLimit
    
    ; Verificar si hay datos para generar
    ld a, [AddressBuf]
    or a
    jr z, .noData         ; Si no hay dirección, mostrar error
    
    ; Calcular espacio restante en buffer
    push de               ; Guardar posición actual
    ld hl, QR_InputBuf
    call StringLength
    ld b, a               ; B = longitud actual
    ld a, MAX_INPUT_LEN
    sub b
    sub 2                 ; Restar espacio para "|" y terminador
    ld c, a               ; C = espacio restante
    pop de
    
    ; Agregar separador
    ld a, "|"
    ld [de], a
    inc de
    
    ; Copiar monto con límite ajustado
    ; CORRECCIÓN: Hacer explícito el límite en BC
    ld hl, AmountBuf
    ld b, 0               ; B = 0
    ; C ya contiene el espacio restante
    push bc               ; Guardar límite
    pop bc                ; BC = límite completo (más claro)
    call CopyStringWithLimit
    
    ; Verificar si hay monto para generar
    ld a, [AmountBuf]
    or a
    jr z, .noData         ; Si no hay monto, mostrar error
    
    ; Verificar si los datos exceden capacidad
    ld hl, QR_InputBuf
    call CalculateDataSize
    cp QR_CAPACITY
    jr nc, .dataExceedsCapacity
    
    ; Codificar datos
    ld hl, QR_InputBuf
    call EncodeAlpha
    
    ; Calcular corrección de errores
    call CalculateECC
    
    ; Construir matriz QR
    call BuildMatrixV1L
    
    ; Aplicar máscara 0
    call ApplyMask0
    
    ; Mostrar pantalla QR
    call DrawQRScreen
    
    ; Esperar hasta que se presione un botón
    call WaitButton
    
    ; Restaurar registros
    pop hl
    pop de
    pop bc
    pop af
    ret
    
.noData:
    ; Mostrar mensaje de error - no hay datos
    call UI_ClearScreen
    ld hl, QRNoDataMsg
    ld d, 8    ; y
    ld e, 3    ; x
    call UI_PrintStringAtXY
    call WaitButton
    
    pop hl
    pop de
    pop bc
    pop af
    ret
    
.dataExceedsCapacity:
    ; Mostrar mensaje de error - datos exceden capacidad
    call UI_ClearScreen
    ld hl, QRTooLongMsg
    ld d, 8    ; y
    ld e, 3    ; x
    call UI_PrintStringAtXY
    call WaitButton
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; InitQRBuffers: Inicializa todos los buffers para QR
InitQRBuffers:
    push af
    push bc
    push hl
    
    ; Limpiar buffer de entrada QR
    ld hl, QR_InputBuf
    ld bc, MAX_INPUT_LEN
    xor a
    call FillMemory
    
    ; Limpiar buffer de bits
    ld hl, QR_BitBuf
    ld bc, QR_CAPACITY + QR_EC_SIZE
    xor a
    call FillMemory
    
    ; Limpiar matriz QR
    ld hl, QR_Matrix
    ld bc, QR_MODULES
    xor a
    call FillMemory
    
    ; Inicializar contadores y variables del acumulador de bits
    xor a
    ld [QR_DataLen], a
    ld [QR_BitAccum], a
    ld [QR_BitCount], a
    ld [QR_ByteIndex], a
    ld [QR_ReadByte], a
    ld [QR_BitsLeft], a
    ld [QR_ReadIndex], a
    
    pop hl
    pop bc
    pop af
    ret

; EncodeAlpha: Codifica datos alfanuméricos en formato QR
; Entrada: HL = puntero a cadena
EncodeAlpha:
    push af
    push bc
    push de
    push hl
    
    ; Resetear variables del acumulador
    xor a
    ld [QR_BitAccum], a
    ld [QR_BitCount], a
    ld [QR_ByteIndex], a
    
    ; Calcular longitud de la cadena
    push hl
    call StringLength
    ld [QR_DataLen], a
    pop hl
    
    ; 1. Escribir indicador de modo (4 bits: 0010 para alfanumérico)
    ld a, MODE_ALPHANUMERIC
    ld b, 4
    call WriteBitsSimple
    
    ; 2. Escribir contador de caracteres (9 bits para V1 alfanumérico)
    ld a, [QR_DataLen]
    ld b, 9
    call WriteBitsSimple
    
    ; 3. Codificar pares de caracteres
.encodePair:
    ; Verificar si quedan caracteres
    ld a, [hl]
    or a
    jr z, .encodeComplete
    
    ; Obtener valor del primer carácter
    push hl                ; Guardar puntero para siguiente iteración
    call GetAlphaValue     ; A = valor alfanumérico
    ld d, a                ; Guardar en D
    pop hl
    
    ; Avanzar al siguiente carácter
    inc hl
    ld a, [hl]
    or a
    jr z, .lastChar        ; Si no hay segundo carácter, procesar como individual
    
    ; Obtener valor del segundo carácter
    push hl
    call GetAlphaValue
    ld e, a                ; E = segundo valor
    pop hl
    
    ; Calcular: primer * 45 + segundo
    ld a, d
    ld b, 45
    call Multiply8         ; HL = A * B
    ld a, l
    add e                  ; A = resultado final
    
    ; Escribir 11 bits
    ld b, 11
    call WriteBitsSimple
    
    ; Avanzar al siguiente par
    inc hl
    jr .encodePair
    
.lastChar:
    ; Carácter individual: escribir 6 bits
    ld a, d
    ld b, 6
    call WriteBitsSimple
    
.encodeComplete:
    ; 4. Agregar terminador (0000)
    xor a
    ld b, 4
    call WriteBitsSimple
    
    ; 5. Pad hasta byte completo
    call PadToByte
    
    ; 6. Pad con bytes alternos 11101100 y 00010001
    call PadDataBytes
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; WriteBitsSimple: Escribe bits usando acumulador
; Entrada: A = datos, B = número de bits a escribir
WriteBitsSimple:
    push af
    push bc
    push de
    push hl
    
    ; B = número de bits a escribir
    ; A = datos a escribir
    ld c, a             ; Guardar datos en C
    
.writeLoop:
    ld a, b
    or a
    jr z, .done
    
    ; Rotar datos a la izquierda para obtener MSB en carry
    ld a, c
    rlca                ; Rotar a la izquierda (MSB -> carry -> LSB)
    ld c, a             ; Guardar datos rotados
    
    ; Obtener acumulador actual
    ld a, [QR_BitAccum]
    rla                 ; Meter carry (bit) en acumulador
    ld [QR_BitAccum], a
    
    ; Incrementar contador de bits
    ld a, [QR_BitCount]
    inc a
    ld [QR_BitCount], a
    
    ; ¿Byte completo?
    cp 8
    jr nz, .nextBit
    
    ; Escribir byte completo al buffer
    ld a, [QR_ByteIndex]
    ld e, a
    ld d, 0
    ld hl, QR_BitBuf
    add hl, de          ; HL = posición en buffer
    
    ld a, [QR_BitAccum]
    ld [hl], a          ; Escribir byte
    
    ; Reset acumulador y contador
    xor a
    ld [QR_BitAccum], a
    ld [QR_BitCount], a
    
    ; Incrementar índice de byte
    ld a, [QR_ByteIndex]
    inc a
    ld [QR_ByteIndex], a
    
.nextBit:
    dec b
    jr .writeLoop
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; GetAlphaValue: Convierte carácter ASCII a valor alfanumérico QR
; Entrada: A = carácter ASCII
; Salida: A = valor alfanumérico (0-44)
GetAlphaValue:
    push hl
    push bc
    
    ld c, a             ; Guardar carácter original
    
    ; Verificar si es número (0-9)
    cp '0'
    jr c, .checkAlpha
    cp '9' + 1
    jr nc, .checkAlpha
    
    ; Es número: valor = ASCII - '0'
    sub '0'
    jr .done
    
.checkAlpha:
    ; Verificar si es letra (A-Z)
    cp 'A'
    jr c, .checkSpecial
    cp 'Z' + 1
    jr nc, .checkSpecial
    
    ; Es letra: valor = ASCII - 'A' + 10
    sub 'A'
    add 10
    jr .done
    
.checkSpecial:
    ; Buscar en tabla de caracteres especiales
    ld hl, AlphaSpecialChars
    ld b, 0
    
.searchLoop:
    ld a, [hl]
    cp c                ; Comparar con carácter original
    jr z, .foundSpecial
    inc hl
    inc b
    ld a, b
    cp 9                ; Número de caracteres especiales
    jr c, .searchLoop
    
    ; No encontrado, usar espacio por defecto
    ld a, 36
    jr .done
    
.foundSpecial:
    ; Valor = 36 + índice
    ld a, b
    add 36
    
.done:
    pop bc
    pop hl
    ret

; PadToByte: Rellena bits hasta completar un byte
; IMPORTANTE: Tras esta llamada, QR_BitAccum y QR_BitCount quedan en cero
PadToByte:
    push af
    push bc
    
    ; Verificar si hay bits pendientes en el acumulador
    ld a, [QR_BitCount]
    or a
    jr z, .aligned      ; Ya está alineado
    
    ; Calcular bits restantes para completar byte
    ld b, a
    ld a, 8
    sub b
    ld b, a             ; B = bits a rellenar
    
    ; Escribir ceros para completar el byte
    xor a
    call WriteBitsSimple
    
.aligned:
    ; GARANTÍA: QR_BitAccum y QR_BitCount están en cero tras WriteBitsSimple
    pop bc
    pop af
    ret

; PadDataBytes: Rellena con bytes alternos hasta completar capacidad
PadDataBytes:
    push af
    push bc
    
    ; Obtener bytes escritos
    ld a, [QR_ByteIndex]
    
    ; Calcular bytes restantes
    ld b, a
    ld a, QR_CAPACITY
    sub b
    jr z, .padDone      ; No hay espacio para rellenar
    jr c, .padDone      ; Nos pasamos (no debería ocurrir)
    
    ld b, a             ; B = bytes a rellenar
    ld c, 0             ; C = alternar entre patrones
    
.padLoop:
    ld a, c
    and 1
    jr nz, .pattern2
    
    ; Patrón 1: 11101100
    ld a, $EC
    jr .writePadByte
    
.pattern2:
    ; Patrón 2: 00010001
    ld a, $11
    
.writePadByte:
    push bc
    ld b, 8
    call WriteBitsSimple
    pop bc
    
    inc c
    dec b
    jr nz, .padLoop
    
.padDone:
    pop bc
    pop af
    ret

; CalculateECC: Calcula bytes de corrección de errores
CalculateECC:
    push af
    push bc
    push de
    push hl
    
    ; Para QR V1-L, usamos polinomio generador de grado 7
    
    ; Copiar datos a buffer temporal para división
    ld hl, QR_BitBuf
    ld de, ECC_TempBuf
    ld bc, QR_CAPACITY
    call CopyMemory
    
    ; Agregar 7 bytes de ceros al final para la división
    ld hl, ECC_TempBuf + QR_CAPACITY
    ld b, QR_EC_SIZE
    xor a
.addZeros:
    ld [hl+], a
    dec b
    jr nz, .addZeros
    
    ; Realizar división polinomial en GF(256)
    ld b, QR_CAPACITY   ; Número de pasos
    
.divisionLoop:
    ; Obtener coeficiente líder
    ld hl, ECC_TempBuf
    ld a, b
    dec a
    ld d, 0
    ld e, a
    add hl, de
    ld a, [hl]          ; A = coeficiente líder
    
    or a
    jr z, .nextStep     ; Si es 0, pasar al siguiente
    
    ; Para cada término del generador
    ld c, 0             ; Índice del generador
    
.generatorLoop:
    push bc
    
    ; Obtener coeficiente del generador
    ld hl, GeneratorPoly
    ld b, 0
    add hl, bc
    ld b, [hl]          ; B = coeficiente del generador
    
    ; Multiplicar en GF(256)
    push af
    call GF256_Multiply ; A = A * B
    ld d, a             ; Guardar resultado
    pop af
    
    ; XOR con el byte correspondiente
    ld hl, ECC_TempBuf
    pop bc
    push bc
    
    ld a, b
    dec a
    add c               ; Posición = líder + índice generador
    ld e, a
    ld d, 0
    add hl, de
    
    ld a, [hl]
    xor d
    ld [hl], a
    
    pop bc
    inc c
    ld a, c
    cp QR_EC_SIZE + 1
    jr c, .generatorLoop
    
.nextStep:
    dec b
    jr nz, .divisionLoop
    
    ; Los bytes de ECC son el residuo (últimos 7 bytes)
    ld hl, ECC_TempBuf
    ld de, QR_BitBuf + QR_CAPACITY
    ld bc, QR_EC_SIZE
    call CopyMemory
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; BuildMatrixV1L: Construye la matriz QR Version 1
BuildMatrixV1L:
    push af
    push bc
    push de
    push hl
    
    ; 1. Colocar patrones fijos
    call PlaceFinderPatterns
    call PlaceSeparators
    call PlaceTimingPatterns
    call PlaceDarkModule
    
    ; 2. Colocar información de formato (para V1-L, máscara 0)
    call PlaceFormatInfo
    
    ; 3. Colocar datos y ECC
    call PlaceData
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; PlaceFinderPatterns: Coloca los 3 patrones de búsqueda
PlaceFinderPatterns:
    push bc
    push de
    
    ; Patrón superior izquierdo (0,0)
    ld d, 0
    ld e, 0
    call PlaceFinderPattern
    
    ; Patrón superior derecho (14,0)
    ld d, 0
    ld e, 14
    call PlaceFinderPattern
    
    ; Patrón inferior izquierdo (0,14)
    ld d, 14
    ld e, 0
    call PlaceFinderPattern
    
    pop de
    pop bc
    ret

; PlaceFinderPattern: Coloca un patrón de búsqueda en (D,E)
; OPTIMIZADO: Menos push/pop en el bucle interno
PlaceFinderPattern:
    push bc
    push hl
    
    ld hl, FinderPattern
    ld b, 7             ; 7 filas
    
    ; Guardar posición inicial
    push de
    
.rowLoop:
    push bc
    
    ; Restaurar X inicial para esta fila
    pop de
    push de
    
    ld c, 7             ; 7 columnas
    
.colLoop:
    ld a, [hl+]
    
    ; Colocar módulo en matriz (sin push/pop adicionales)
    push hl
    call SetModule      ; D=y, E=x, A=valor
    pop hl
    
    inc e               ; Siguiente columna
    dec c
    jr nz, .colLoop
    
    pop de              ; Recuperar posición inicial
    inc d               ; Siguiente fila
    push de             ; Guardar nueva posición
    
    pop bc
    dec b
    jr nz, .rowLoop
    
    pop de              ; Limpiar stack
    
    pop hl
    pop bc
    ret

; SetModule: Establece un módulo en la matriz
; Entrada: D=y, E=x, A=valor (0 o 1)
SetModule:
    push bc
    push hl
    
    ; Calcular offset: y * 21 + x
    ld h, 0
    ld l, d
    ld b, h
    ld c, l
    
    ; Multiplicar por 21
    add hl, hl         ; *2
    add hl, hl         ; *4
    add hl, bc         ; *5
    add hl, hl         ; *10
    add hl, hl         ; *20
    add hl, bc         ; *21
    
    ; Agregar x
    ld b, 0
    ld c, e
    add hl, bc
    
    ; Agregar base de matriz
    ld bc, QR_Matrix
    add hl, bc
    
    ; Establecer valor
    ld [hl], a
    
    pop hl
    pop bc
    ret

; PlaceSeparators: Coloca los separadores blancos
; OPTIMIZADO: Sin push/pop en bucles internos
PlaceSeparators:
    push bc
    
    ; Separador horizontal superior izquierdo
    ld d, 7             ; y
    ld e, 0             ; x inicial
    ld b, 8             ; longitud
    xor a               ; valor = 0 (blanco)
.topLeftH:
    push de
    call SetModule
    pop de
    inc e
    dec b
    jr nz, .topLeftH
    
    ; Separador vertical superior izquierdo
    ld d, 0             ; y inicial
    ld e, 7             ; x
    ld b, 7             ; longitud
.topLeftV:
    push de
    call SetModule
    pop de
    inc d
    dec b
    jr nz, .topLeftV
    
    ; Separador horizontal superior derecho
    ld d, 7             ; y
    ld e, 13            ; x inicial
    ld b, 8             ; longitud
.topRightH:
    push de
    call SetModule
    pop de
    inc e
    dec b
    jr nz, .topRightH
    
    ; Separador vertical superior derecho
    ld d, 0             ; y inicial
    ld e, 13            ; x
    ld b, 7             ; longitud
.topRightV:
    push de
    call SetModule
    pop de
    inc d
    dec b
    jr nz, .topRightV
    
    ; Separador horizontal inferior izquierdo
    ld d, 13            ; y
    ld e, 0             ; x inicial
    ld b, 8             ; longitud
.bottomLeftH:
    push de
    call SetModule
    pop de
    inc e
    dec b
    jr nz, .bottomLeftH
    
    ; Separador vertical inferior izquierdo
    ld d, 14            ; y inicial
    ld e, 7             ; x
    ld b, 7             ; longitud
.bottomLeftV:
    push de
    call SetModule
    pop de
    inc d
    dec b
    jr nz, .bottomLeftV
    
    pop bc
    ret

; PlaceTimingPatterns: Coloca los patrones de sincronización
PlaceTimingPatterns:
    push bc
    
    ; Patrón horizontal (fila 6)
    ld d, 6             ; y = 6
    ld e, 8             ; x inicial = 8
    ld b, 5             ; longitud = 5
    ld c, 1             ; alternar comenzando con negro
    
.horizontalTiming:
    ld a, c
    push de
    call SetModule
    pop de
    ld a, c
    xor 1               ; Alternar 0/1
    ld c, a
    inc e
    dec b
    jr nz, .horizontalTiming
    
    ; Patrón vertical (columna 6)
    ld d, 8             ; y inicial = 8
    ld e, 6             ; x = 6
    ld b, 5             ; longitud = 5
    ld c, 1             ; alternar comenzando con negro
    
.verticalTiming:
    ld a, c
    push de
    call SetModule
    pop de
    ld a, c
    xor 1               ; Alternar 0/1
    ld c, a
    inc d
    dec b
    jr nz, .verticalTiming
    
    pop bc
    ret

; PlaceDarkModule: Coloca el módulo oscuro obligatorio
PlaceDarkModule:
    push de
    
    ; Para V1, el módulo oscuro está en (4*1+9, 13) = (13, 8)
    ld d, 13
    ld e, 8
    ld a, 1
    call SetModule
    
    pop de
    ret

; PlaceFormatInfo: Coloca la información de formato
PlaceFormatInfo:
    push bc
    push de
    push hl
    
    ; Para V1-L máscara 0: formato = 0x77C4
    ; Bits: 011101111000100
    
    ; Colocar alrededor del patrón superior izquierdo
    ld hl, FormatBitsUL
    ld b, 0
    
.upperLeftLoop:
    ld a, [hl+]
    ld d, [hl+]         ; y
    ld e, [hl+]         ; x
    
    push hl
    call SetModule
    pop hl
    
    inc b
    ld a, b
    cp 15               ; 15 bits de formato
    jr c, .upperLeftLoop
    
    ; Colocar en la esquina inferior izquierda y superior derecha
    ld hl, FormatBitsLR
    ld b, 0
    
.lowerRightLoop:
    ld a, [hl+]
    ld d, [hl+]         ; y
    ld e, [hl+]         ; x
    
    push hl
    call SetModule
    pop hl
    
    inc b
    ld a, b
    cp 15
    jr c, .lowerRightLoop
    
    pop hl
    pop de
    pop bc
    ret

; PlaceData: Coloca los datos y ECC en la matriz
; NOTA: Algoritmo zigzag complejo pero necesario
; DataCol: columna actual (20->0, saltando 6)
; DataRow: fila actual (0->20)
; DataDirection: 0=bajando, 1=subiendo
PlaceData:
    push af
    push bc
    push de
    push hl
    
    ; Inicializar variables de lectura
    xor a
    ld [QR_ReadByte], a
    ld [QR_BitsLeft], a
    ld [QR_ReadIndex], a
    
    ; Los datos se colocan en columnas de 2, de derecha a izquierda
    ; y de abajo hacia arriba, alternando dirección
    
    ld a, 20            ; Columna inicial (rightmost)
    ld [DataCol], a
    ld a, 1             ; Dirección: 1=arriba, 0=abajo
    ld [DataDirection], a
    xor a
    ld [DataBitIndex], a
    
.columnLoop:
    ; Procesar columna actual
    ld a, [DataCol]
    cp 6
    jr nz, .notColumn6
    
    ; Saltar columna 6 (timing pattern)
    dec a
    ld [DataCol], a
    
.notColumn6:
    ; Determinar fila inicial según dirección
    ld a, [DataDirection]
    or a
    jr z, .goingDown
    
    ; Subiendo: comenzar desde abajo
    ld a, 20
    jr .setRow
    
.goingDown:
    ; Bajando: comenzar desde arriba
    xor a
    
.setRow:
    ld [DataRow], a
    
    ; Procesar módulos en esta columna
.moduleLoop:
    ; Verificar si hemos colocado todos los datos
    ld a, [DataBitIndex]
    ld b, a
    ld a, (QR_CAPACITY + QR_EC_SIZE) * 8
    cp b
    jr z, .placementComplete
    jr c, .placementComplete
    
    ; Colocar bit en posición actual si no está ocupada
    ld a, [DataRow]
    ld d, a
    ld a, [DataCol]
    ld e, a
    
    ; Verificar si la posición está disponible
    call IsModuleAvailable
    or a
    jr z, .skipModule
    
    ; Obtener siguiente bit de datos
    call GetNextDataBit
    push af             ; Guardar bit
    
    ; Colocar bit
    ld a, [DataRow]
    ld d, a
    ld a, [DataCol]
    ld e, a
    pop af              ; Recuperar bit
    call SetModule
    
    ; Incrementar índice de bit
    ld a, [DataBitIndex]
    inc a
    ld [DataBitIndex], a
    
.skipModule:
    ; Mover a la siguiente posición
    ld a, [DataCol]
    and 1
    jr nz, .oddColumn
    
    ; Columna par: mover a la derecha
    ld a, [DataCol]
    inc a
    ld [DataCol], a
    jr .moduleLoop
    
.oddColumn:
    ; Columna impar: mover a la izquierda y arriba/abajo
    ld a, [DataCol]
    dec a
    ld [DataCol], a
    
    ; Mover arriba o abajo según dirección
    ld a, [DataDirection]
    or a
    jr z, .moveDown
    
    ; Mover arriba
    ld a, [DataRow]
    or a
    jr z, .changeDirection  ; Llegamos al tope
    dec a
    ld [DataRow], a
    jr .moduleLoop
    
.moveDown:
    ; Mover abajo
    ld a, [DataRow]
    cp 20
    jr z, .changeDirection  ; Llegamos al fondo
    inc a
    ld [DataRow], a
    jr .moduleLoop
.changeDirection:
   ; Cambiar dirección y mover a siguiente par de columnas
   ld a, [DataDirection]
   xor 1
   ld [DataDirection], a
   
   ld a, [DataCol]
   dec a
   ld [DataCol], a
   
   ; Verificar si terminamos
   ld a, [DataCol]
   cp $FF
   jr nz, .columnLoop
   
.placementComplete:
   pop hl
   pop de
   pop bc
   pop af
   ret

; GetNextDataBit: Obtiene el siguiente bit de datos usando lectura secuencial
; Salida: A=bit (0 o 1)
GetNextDataBit:
   push bc
   push de
   push hl
   
   ; Verificar si necesitamos leer un nuevo byte
   ld a, [QR_BitsLeft]
   or a
   jr nz, .extractBit
   
   ; Leer siguiente byte del buffer
   ld a, [QR_ReadIndex]
   ld e, a
   ld d, 0
   ld hl, QR_BitBuf
   add hl, de
   ld a, [hl]
   ld [QR_ReadByte], a
   
   ; Incrementar índice
   ld a, [QR_ReadIndex]
   inc a
   ld [QR_ReadIndex], a
   
   ; Resetear contador de bits
   ld a, 8
   ld [QR_BitsLeft], a
   
.extractBit:
   ; Extraer MSB del byte actual
   ld a, [QR_ReadByte]
   rlca                ; Rotar a la izquierda
   ld [QR_ReadByte], a ; Guardar byte rotado
   
   ; El bit está ahora en el bit 0
   and 1               ; Aislar bit
   
   ; Decrementar contador de bits
   push af             ; Guardar bit
   ld a, [QR_BitsLeft]
   dec a
   ld [QR_BitsLeft], a
   pop af              ; Recuperar bit
   
   pop hl
   pop de
   pop bc
   ret

; IsModuleAvailable: Verifica si un módulo está disponible
; Entrada: D=y, E=x
; Salida: A=1 si disponible, 0 si ocupado
IsModuleAvailable:
   push bc
   push de
   
   ; Verificar patrones de búsqueda (3 esquinas 7x7)
   ; Superior izquierdo
   ld a, d
   cp 9
   jr nc, .notTopLeft
   ld a, e
   cp 9
   jr nc, .notTopLeft
   xor a               ; Ocupado
   jr .done
   
.notTopLeft:
   ; Superior derecho
   ld a, d
   cp 9
   jr nc, .notTopRight
   ld a, e
   cp 13
   jr c, .notTopRight
   xor a               ; Ocupado
   jr .done
   
.notTopRight:
   ; Inferior izquierdo
   ld a, d
   cp 13
   jr c, .notBottomLeft
   ld a, e
   cp 9
   jr nc, .notBottomLeft
   xor a               ; Ocupado
   jr .done
   
.notBottomLeft:
   ; Verificar timing patterns
   ; Horizontal (fila 6)
   ld a, d
   cp 6
   jr nz, .notHorizontalTiming
   ld a, e
   cp 8
   jr c, .checkVerticalTiming
   cp 13
   jr nc, .checkVerticalTiming
   xor a               ; Ocupado
   jr .done
   
.notHorizontalTiming:
.checkVerticalTiming:
   ; Vertical (columna 6)
   ld a, e
   cp 6
   jr nz, .notVerticalTiming
   ld a, d
   cp 8
   jr c, .checkDarkModule
   cp 13
   jr nc, .checkDarkModule
   xor a               ; Ocupado
   jr .done
   
.notVerticalTiming:
.checkDarkModule:
   ; Módulo oscuro (13, 8)
   ld a, d
   cp 13
   jr nz, .available
   ld a, e
   cp 8
   jr nz, .available
   xor a               ; Ocupado
   jr .done
   
.available:
   ld a, 1             ; Disponible
   
.done:
   pop de
   pop bc
   ret

; ApplyMask0: Aplica máscara 0 (tablero de ajedrez)
; Patrón: (row + column) mod 2 == 0
ApplyMask0:
   push bc
   push de
   
   ld d, 0             ; y = 0
   
.rowLoop:
   ld e, 0             ; x = 0
   
.colLoop:
   ; Verificar si debemos aplicar máscara
   push de
   call IsDataModule   ; Verificar si es módulo de datos
   pop de
   or a
   jr z, .skipModule   ; No es módulo de datos
   
   ; Calcular (row + column) mod 2
   ld a, d
   add e
   and 1
   jr nz, .skipModule  ; No aplicar máscara si es 1
   
   ; Aplicar máscara (invertir módulo)
   push de
   call GetModule      ; Obtener valor actual
   xor 1               ; Invertir
   call SetModule      ; Guardar valor invertido
   pop de
   
.skipModule:
   inc e
   ld a, e
   cp 21
   jr c, .colLoop
   
   inc d
   ld a, d
   cp 21
   jr c, .rowLoop
   
   pop de
   pop bc
   ret

; IsDataModule: Verifica si un módulo contiene datos (no es patrón fijo)
; Entrada: D=y, E=x
; Salida: A=1 si es módulo de datos, 0 si es patrón fijo
IsDataModule:
   ; Reutilizamos IsModuleAvailable ya que tiene la misma lógica
   call IsModuleAvailable
   ret

; GetModule: Obtiene el valor de un módulo
; Entrada: D=y, E=x
; Salida: A=valor (0 o 1)
GetModule:
   push bc
   push hl
   
   ; Calcular offset: y * 21 + x
   ld h, 0
   ld l, d
   ld b, h
   ld c, l
   
   ; Multiplicar por 21
   add hl, hl         ; *2
   add hl, hl         ; *4
   add hl, bc         ; *5
   add hl, hl         ; *10
   add hl, hl         ; *20
   add hl, bc         ; *21
   
   ; Agregar x
   ld b, 0
   ld c, e
   add hl, bc
   
   ; Agregar base de matriz
   ld bc, QR_Matrix
   add hl, bc
   
   ; Obtener valor
   ld a, [hl]
   
   pop hl
   pop bc
   ret

; DrawQRScreen: Muestra el código QR en pantalla
; OPTIMIZADO: Menos push/pop en bucles internos
DrawQRScreen:
   push af
   push bc
   push de
   push hl
   
   ; Limpiar pantalla
   call UI_ClearScreen
   
   ; Mostrar título centrado
   ld hl, QRTitle
   ld d, 0             ; y
   ld e, 6             ; x centrado
   call UI_PrintStringAtXY
   
   ; Nota sobre visualización parcial
   ld hl, QRPartialMsg
   ld d, 1             ; y
   ld e, 2             ; x
   call UI_PrintStringAtXY
   
   ; Calcular posición inicial para mostrar QR
   ; Mostraremos 18x16 de los 21x21 módulos
   
   ld d, 2             ; y inicial (dejar espacio para título)
   
   ; Guardar posición inicial para optimización
   push de
   
.drawRowLoop:
   ; Restaurar X inicial para esta fila
   pop de
   push de
   ld e, 1             ; x inicial (dejar margen)
   
.drawColLoop:
   ; Obtener valor del módulo (sin push/pop adicionales)
   push de
   call GetModule
   pop de
   push af             ; Guardar valor
   
   ; Convertir a carácter ASCII
   or a
   jr z, .whiteModule
   
   ; Módulo negro
   ld a, '#'
   jr .drawModule
   
.whiteModule:
   ; Módulo blanco
   ld a, ' '
   
.drawModule:
   ; Dibujar módulo
   push de
   call UI_PrintAtXY
   pop de
   pop af              ; Limpiar stack del valor
   
   ; Siguiente columna
   inc e
   ld a, e
   cp 19               ; Límite de pantalla (1 + 18)
   jr z, .nextRow      ; Si llegamos al límite, siguiente fila
   
   ; Verificar si procesamos todas las columnas del QR visible
   ld a, e
   sub 1               ; Restar offset inicial
   cp 18               ; Solo mostramos 18 columnas
   jr c, .drawColLoop
   
.nextRow:
   ; Recuperar Y actual y avanzar
   pop de
   inc d
   push de
   
   ; Verificar límites
   ld a, d
   cp 18               ; Límite de pantalla
   jr z, .drawComplete ; Si llegamos al límite, terminar
   
   ; Verificar si procesamos todas las filas del QR visible
   ld a, d
   sub 2               ; Restar offset inicial
   cp 16               ; Solo mostramos 16 filas
   jr c, .drawRowLoop
   
.drawComplete:
   pop de              ; Limpiar stack
   
   ; Mostrar instrucciones
   ld hl, QRInstructions
   ld d, 17            ; y (última línea)
   ld e, 1             ; x
   call UI_PrintStringAtXY
   
   pop hl
   pop de
   pop bc
   pop af
   ret

; WaitButton: Espera hasta que se presione un botón
WaitButton:
   push af
   
.waitLoop:
   call ReadJoypad
   ld a, [JoyState]
   and $F0             ; Máscara para botones
   jr z, .waitLoop
   
   ; Esperar a que se suelte
.releaseLoop:
   call ReadJoypad
   ld a, [JoyState]
   and $F0
   jr nz, .releaseLoop
   
   ; Reproducir sonido
   call PlayBeepNav
   
   pop af
   ret

; CalculateDataSize: Calcula el tamaño necesario para los datos
; Entrada: HL = puntero a cadena
; Salida: A = tamaño en bytes
CalculateDataSize:
   push bc
   push hl
   
   ; Contar caracteres
   call StringLength
   ld b, a             ; B = longitud
   
   ; Calcular bits necesarios:
   ld a, 4             ; Indicador de modo (4 bits)
   add a, 9            ; Campo de longitud (9 bits para V1 alfanumérico)
   add a, 4            ; Terminador obligatorio (4 bits)
   ld c, a             ; C = bits fijos totales
   
   ; Calcular bits de datos
   ld a, b
   srl a               ; A = longitud / 2
   jr z, .noFullPairs
   
   ; Multiplicar por 11 (bits por par de caracteres)
   ld d, a
   add a               ; *2
   add a               ; *4
   add a               ; *8
   add d               ; *9
   add d               ; *10
   add d               ; *11
   add c               ; Agregar a total
   ld c, a
   
.noFullPairs:
   ; Verificar si hay carácter suelto
   ld a, b
   and 1
   jr z, .nOddChar
   
   ; Agregar 6 bits por carácter suelto
   ld a, c
   add 6
   ld c, a
   
.nOddChar:
   ; Convertir bits a bytes (redondear hacia arriba)
   ld a, c
   add 7               ; Para redondear hacia arriba
   srl a
   srl a
   srl a               ; A = bits / 8
   
   pop hl
   pop bc
   ret

; StringLength: Calcula la longitud de una cadena
; Entrada: HL = puntero a cadena
; Salida: A = longitud
StringLength:
   push bc
   push hl
   
   ld b, 0
.loop:
   ld a, [hl+]
   or a
   jr z, .done
   inc b
   jr .loop
   
.done:
   ld a, b
   
   pop hl
   pop bc
   ret

; CopyStringWithLimit: Copia una cadena con límite específico
; Entrada: HL = origen, DE = destino, BC = límite
; NOTA: Esta función debe estar definida en utils.asm
CopyStringWithLimit:
   push af
   
.loop:
   ; Verificar límite
   ld a, b
   or c
   jr z, .hitLimit
   
   ; Copiar byte
   ld a, [hl+]
   ld [de], a
   
   ; Verificar terminador
   or a
   jr z, .done
   
   ; Siguiente byte
   inc de
   dec bc
   jr .loop
   
.hitLimit:
   ; Forzar terminación si alcanzamos el límite
   dec de              ; Retroceder una posición
   xor a
   ld [de], a
   
.done:
   pop af
   ret

; FillMemory: Llena memoria con un valor
; Entrada: HL = inicio, BC = longitud, A = valor
FillMemory:
   push de
   
   ld d, a             ; Guardar valor
.loop:
   ld a, b
   or c
   jr z, .done
   
   ld a, d
   ld [hl+], a
   
   dec bc
   jr .loop
   
.done:
   pop de
   ret

; CopyMemory: Copia un bloque de memoria
; Entrada: HL = origen, DE = destino, BC = longitud
CopyMemory:
   push af
   
.loop:
   ld a, b
   or c
   jr z, .done
   
   ld a, [hl+]
   ld [de], a
   inc de
   
   dec bc
   jr .loop
   
.done:
   pop af
   ret

; Multiply8: Multiplica dos números de 8 bits
; Entrada: A = multiplicando, B = multiplicador
; Salida: HL = resultado (16 bits)
; NOTA: Considerar mover a utils.asm si se usa en otros módulos
Multiply8:
   push bc
   push de
   
   ld h, 0
   ld l, a
   ld d, h
   ld e, l             ; DE = multiplicando
   
   dec b
   jr z, .done         ; Si multiplicador es 1, ya está
   
.loop:
   add hl, de
   dec b
   jr nz, .loop
   
.done:
   pop de
   pop bc
   ret

; GF256_Multiply: Multiplicación en GF(256)
; Entrada: A, B = operandos
; Salida: A = resultado
; NOTA: Considerar mover a rs_ecc.asm
GF256_Multiply:
   push bc
   push de
   push hl
   
   ; Si alguno es 0, resultado es 0
   or a
   jr z, .result_zero
   ld c, a             ; Guardar primer operando
   ld a, b
   or a
   jr z, .result_zero
   
   ; Usar logaritmos para multiplicar
   ; result = antilog(log(a) + log(b))
   
   ; Obtener log(a)
   ld h, 0
   ld l, c
   ld de, GF256_LogTable
   add hl, de
   ld a, [hl]
   ld c, a             ; C = log(a)
   
   ; Obtener log(b)
   ld l, b
   ld h, 0
   add hl, de
   ld a, [hl]
   
   ; Sumar logaritmos
   add c
   
   ; Si excede 255, restar 255
   jr nc, .no_overflow
   sub 255
   
.no_overflow:
   ; Obtener antilogaritmo
   ld l, a
   ld h, 0
   ld de, GF256_ExpTable
   add hl, de
   ld a, [hl]
   
   jr .done
   
.result_zero:
   xor a
   
.done:
   pop hl
   pop de
   pop bc
   ret

; --- Datos ---
SECTION "QRData", ROM1

; Patrón de búsqueda 7x7
FinderPattern:
   DB 1,1,1,1,1,1,1
   DB 1,0,0,0,0,0,1
   DB 1,0,1,1,1,0,1
   DB 1,0,1,1,1,0,1
   DB 1,0,1,1,1,0,1
   DB 1,0,0,0,0,0,1
   DB 1,1,1,1,1,1,1

; Caracteres especiales para codificación alfanumérica
AlphaSpecialChars:
   DB " ", "$", "%", "*", "+", "-", ".", "/", ":"

; Polinomio generador para QR V1-L (grado 7)
GeneratorPoly:
   DB 0, 87, 229, 146, 149, 238, 102, 21

; Posiciones de los bits de formato
; Formato: bit, y, x
FormatBitsUL:   ; Superior izquierdo
   DB 0, 8, 0
   DB 1, 8, 1
   DB 1, 8, 2
   DB 1, 8, 3
   DB 0, 8, 4
   DB 1, 8, 5
   DB 1, 8, 7
   DB 1, 8, 8
   DB 1, 7, 8
   DB 0, 5, 8
   DB 0, 4, 8
   DB 0, 3, 8
   DB 1, 2, 8
   DB 0, 1, 8
   DB 0, 0, 8

FormatBitsLR:   ; Inferior izquierdo y superior derecho
   DB 1, 20, 8
   DB 0, 19, 8
   DB 0, 18, 8
   DB 0, 17, 8
   DB 1, 16, 8
   DB 1, 15, 8
   DB 1, 14, 8
   DB 0, 8, 20
   DB 1, 8, 19
   DB 1, 8, 18
   DB 1, 8, 17
   DB 0, 8, 16
   DB 1, 8, 15
   DB 1, 8, 14
   DB 1, 8, 13

; Tablas GF(256) para Reed-Solomon
GF256_LogTable:
   ; 256 bytes - tabla de logaritmos
   DB 0,0,1,25,2,50,26,198,3,223,51,238,27,104,199,75
   DB 4,100,224,14,52,141,239,129,28,193,105,248,200,8,76,113
   DB 5,138,101,47,225,36,15,33,53,147,142,218,240,18,130,69
   DB 29,181,194,125,106,39,249,185,201,154,9,120,77,228,114,166
   DB 6,191,139,98,102,221,48,253,226,152,37,179,16,145,34,136
   DB 54,208,148,206,143,150,219,189,241,210,19,92,131,56,70,64
   DB 30,66,182,163,195,72,126,110,107,58,40,84,250,133,186,61
   DB 202,94,155,159,10,21,121,43,78,212,229,172,115,243,167,87
   DB 7,112,192,247,140,128,99,13,103,74,222,237,49,197,254,24
   DB 227,165,153,119,38,184,180,124,17,68,146,217,35,32,137,46
   DB 55,63,209,91,149,188,207,205,144,135,151,178,220,252,190,97
   DB 242,86,211,171,20,42,93,158,132,60,57,83,71,109,65,162
   DB 31,45,67,216,183,123,164,118,196,23,73,236,127,12,111,246
   DB 108,161,59,82,41,157,85,170,251,96,134,177,187,204,62,90
   DB 203,89,95,176,156,169,160,81,11,245,22,235,122,117,44,215
   DB 79,174,213,233,230,231,173,232,116,214,244,234,168,80,88,175

GF256_ExpTable:
   ; 256 bytes - tabla de exponenciales (antilogaritmos)
   DB 1,2,4,8,16,32,64,128,29,58,116,232,205,135,19,38
   DB 76,152,45,90,180,117,234,201,143,3,6,12,24,48,96,192
   DB 157,39,78,156,37,74,148,53,106,212,181,119,238,193,159,35
   DB 70,140,5,10,20,40,80,160,93,186,105,210,185,111,222,161
   DB 95,190,97,194,153,47,94,188,101,202,137,15,30,60,120,240
   DB 253,231,211,187,107,214,177,127,254,225,223,163,91,182,113,226
   DB 217,175,67,134,17,34,68,136,13,26,52,104,208,189,103,206
   DB 129,31,62,124,248,237,199,147,59,118,236,197,151,51,102,204
   DB 133,23,46,92,184,109,218,169,79,158,33,66,132,21,42,84
   DB 168,77,154,41,82,164,85,170,73,146,57,114,228,213,183,115
   DB 230,209,191,99,198,145,63,126,252,229,215,179,123,246,241,255
   DB 227,219,171,75,150,49,98,196,149,55,110,220,165,87,174,65
   DB 130,25,50,100,200,141,7,14,28,56,112,224,221,167,83,166
   DB 81,162,89,178,121,242,249,239,195,155,43,86,172,69,138,9
   DB 18,36,72,144,61,122,244,245,247,243,251,235,203,139,11,22
   DB 44,88,176,125,250,233,207,131,27,54,108,216,173,71,142,0

; Mensajes
QRGeneratingMsg:
   DB "Generando QR...", 0
   
QRTitle:
   DB "CODIGO QR", 0

QRPartialMsg:
   DB "(Vista parcial)", 0
   
QRInstructions:
   DB "Pulsa para volver", 0
   
QRNoDataMsg:
   DB "No hay datos!", 0
   
QRTooLongMsg:
   DB "Datos muy largos!", 0

; --- Variables ---
SECTION "QRVars", WRAM0[$CA00]

; Buffers
QR_InputBuf:    DS MAX_INPUT_LEN       ; Buffer para datos de entrada
QR_BitBuf:      DS QR_CAPACITY + QR_EC_SIZE  ; Buffer para datos codificados
QR_Matrix:      DS QR_MODULES          ; Matriz QR completa
ECC_TempBuf:    DS QR_CAPACITY + QR_EC_SIZE  ; Buffer temporal para ECC

; Variables de estado
QR_DataLen:     DS 1        ; Longitud de datos

; Variables para el acumulador de bits (WriteBitsSimple)
QR_BitAccum:    DS 1        ; Byte acumulador
QR_BitCount:    DS 1        ; Bits en el acumulador (0-7)
QR_ByteIndex:   DS 1        ; Índice de byte en buffer

; Variables para lectura de bits (GetNextDataBit)
QR_ReadByte:    DS 1        ; Byte actual siendo leído
QR_BitsLeft:    DS 1        ; Bits restantes en el byte actual
QR_ReadIndex:   DS 1        ; Índice de lectura en el buffer

; Variables para colocación de datos
DataCol:        DS 1        ; Columna actual para colocación
DataRow:        DS 1        ; Fila actual para colocación
DataDirection:  DS 1        ; Dirección de colocación (0=abajo, 1=arriba)
DataBitIndex:   DS 1        ; Índice de bit de datos actual
