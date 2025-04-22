; qr.asm - Generación de QR dinámico (Version 1, EC Level L, Mask 0)
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"
    
SECTION "QRModule", ROM1[$5000]
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
    call CopyString        ; Copiar dirección
    
    ; Verificar si hay datos para generar
    ld a, [AddressBuf]
    or a
    jr z, .noData         ; Si no hay dirección, mostrar error
    
    ; Agregar separador
    ld a, "|"
    ld [de], a
    inc de
    
    ; Copiar monto
    ld hl, AmountBuf       ; Buffer de monto
    call CopyString        ; Copiar monto
    
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
    call BuildMatrixLvlL
    
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

; CalculateDataSize: Calcula tamaño de los datos para QR
; Entrada: HL = puntero a cadena
; Salida: A = tamaño necesario en bytes
CalculateDataSize:
    push bc
    push hl
    
    ; Calcular longitud de la cadena
    ld b, 0    ; contador
    
.countLoop:
    ld a, [hl]
    or a
    jr z, .done
    inc hl
    inc b
    jr .countLoop
    
.done:
    ; Calcular tamaño:
    ; 4 bits indicador modo + 9 bits longitud + datos * 5.5 bits + terminador
    ; (aproximadamente)
    ld a, b
    ; Dividir por 2 y multiplicar por 11 (5.5 bits por caracter)
    srl a      ; a = b / 2
    ld c, a    ; c = b / 2
    sla a      ; a = b
    sla a      ; a = 2*b
    add c      ; a = 2.5*b
    add b      ; a = 3.5*b
    add b      ; a = 4.5*b
    add b      ; a = 5.5*b
    
    ; Agregar header y terminador
    add 4      ; Modo (4 bits)
    add 9      ; Longitud (9 bits)
    add 4      ; Terminador (4 bits)
    
    ; Convertir a bytes (dividir por 8 y redondear hacia arriba)
    add 7      ; a = a + 7
    srl a
    srl a
    srl a      ; a = (a + 7) / 8 (redondeado hacia arriba)
    
    pop hl
    pop bc
    ret

; InitQRBuffers: Inicializa todos los buffers para QR
InitQRBuffers:
    ; Limpiar buffer de entrada
    ld hl, QR_InputBuf
    ld bc, 40       ; Tamaño máximo de entrada (dir + | + monto)
    xor a
    call FillMemory
    
    ; Limpiar buffer de bits
    ld hl, QR_BitBuf
    ld bc, QR_CAPACITY + QR_EC_SIZE
    xor a
    call FillMemory
    
    ; Limpiar buffer de matriz
    ld hl, QR_Matrix
    ld bc, QR_SIZE * QR_SIZE
    xor a
    call FillMemory
    
    ret

; EncodeAlpha: Codifica datos alfanuméricos en formato QR
; Implementación completa...
; (Resto del código de generación de QR)
EncodeAlpha:
    ; [Implementación existente]
    ret

; CalculateECC: Calcula bytes ECC usando el algoritmo Reed-Solomon
CalculateECC:
    ; Usamos lib/rs_ecc.asm para el cálculo real
    ld hl, QR_BitBuf
    ld b, QR_CAPACITY
    call RS_GenerateECC
    
    ; Copiar bytes de corrección al final del buffer de bits
    ld hl, RS_Buffer
    ld de, QR_BitBuf + QR_CAPACITY
    ld bc, QR_EC_SIZE
    call CopyMemory
    
    ret

; BuildMatrixLvlL: Construye la matriz QR
BuildMatrixLvlL:
    ; [Implementación existente]
    ret

; ApplyMask0: Aplica máscara patrón 0 (i+j) mod 2 == 0
ApplyMask0:
    ; [Implementación existente]
    ret

; DrawQRScreen: Muestra el código QR en pantalla
DrawQRScreen:
    ; [Implementación existente]
    ret

; WaitButton: Espera hasta que se pulse cualquier botón
WaitButton:
    ; Guardar estado actual
    ld a, [JoyState]
    ld [JoyPrevState], a
    
.wait:
    ; Leer joypad
    call ReadJoypad
    
    ; Verificar cambios
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .wait
    
    ; Verificar si se pulsó algún botón
    ld a, b
    and $F0         ; Máscara para botones
    jr z, .wait
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ret

; --- Variables en WRAM ---
SECTION "QRVars", WRAM0[$CA00]
QR_InputBuf:    DS 40       ; Buffer para datos de entrada
QR_BitBuf:      DS QR_CAPACITY + QR_EC_SIZE  ; Buffer para datos codificados
QR_Matrix:      DS QR_SIZE * QR_SIZE  ; Matriz QR
QR_DataLen:     DS 1        ; Longitud de datos
QR_BitIndex:    DS 1        ; Índice de bit actual
QR_BitCounter:  DS 1        ; Contador de bits para llenado de matriz

; --- Datos y Mensajes ---
SECTION "QRData", ROM1
QRGeneratingMsg:  DB "Generando QR...", 0
QRScreenTitle:    DB "CODIGO QR", 0
QRInstructions:   DB "Pulsa cualquier boton", 0
QRNoDataMsg:      DB "No hay datos para QR", 0
QRTooLongMsg:     DB "Datos muy largos", 0

; Tabla de símbolos para codificación alfanumérica
SymbolTable:      DB " ", "$", "%", "*", "+", "-", ".", "/", ":"
