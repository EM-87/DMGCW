; sram_manager.asm - API unificada de acceso a SRAM
INCLUDE "../inc/hardware.inc"
INCLUDE "../inc/constants.inc"

; --- API pública ---

; SRAM_Init: Inicializa SRAM si es necesario y verifica integridad
; Salida: A = 0 si ok, 1 si se reinició SRAM
SRAM_Init:
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar integridad con checksum
    call SRAM_VerifyChecksum
    jr nz, .reset_sram
    
    ; SRAM OK
    xor a ; A = 0, todo bien
    jr .done
    
.reset_sram:
    ; Resetear SRAM 
    call SRAM_Reset
    
    ; Indicar que se reseteo
    ld a, 1
    
.done:
    ; Deshabilitar SRAM
    xor a
    ld [$0000], a
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_VerifyChecksum: Verifica integridad de SRAM
; Salida: Z=1 si ok, Z=0 si falla
SRAM_VerifyChecksum:
    push bc
    push hl
    
    ; Calcular checksum
    call SRAM_ComputeChecksum
    ld b, a
    
    ; Leer checksum almacenado
    ld hl, $A000 + CHECKSUM_OFFSET
    ld a, [hl]
    
    ; Comparar (afecta flag Z)
    cp b
    
    pop hl
    pop bc
    ret

; SRAM_ComputeChecksum: Calcular el checksum XOR
; Salida: A = checksum calculado
SRAM_ComputeChecksum:
    push bc
    push de
    push hl
    
    ld hl, $A000
    ld bc, CHECKSUM_OFFSET
    xor a ; Inicializar acumulador
    
.loop:
    xor [hl]
    inc hl
    dec bc
    ld d, a
    ld a, b
    or c
    ld a, d
    jr nz, .loop
    
    ; A contiene el checksum
    pop hl
    pop de
    pop bc
    ret

; SRAM_Reset: Inicializa SRAM a valores por defecto
SRAM_Reset:
    push af
    push bc
    push de
    push hl
    
    ; Limpiar área de transacción
    ld hl, $A000 + ADDR_INPUT_OFFSET
    xor a
    ld [hl], a ; Terminar con 0
    
    ld hl, $A000 + AMOUNT_INPUT_OFFSET
    xor a
    ld [hl], a ; Terminar con 0
    
    ; Limpiar log de transacciones
    ld hl, $A000 + TX_LOG_OFFSET
    ld bc, MAX_LOG_ENTRIES * TX_LOG_LEN
    xor a
    call SRAM_FillMemory
    
    ; Inicializar contador de transacciones
    ld hl, $A000 + TX_COUNT_OFFSET
    xor a
    ld [hl], a
    
    ; Inicializar contador de wallets
    ld hl, $A000 + WALLET_COUNT_OFFSET
    xor a
    ld [hl], a
    
    ; Limpiar área de wallets
    ld hl, $A000 + WALLET_DATA_OFFSET
    ld bc, MAX_WALLETS * WALLET_DATA_LEN
    xor a
    call SRAM_FillMemory
    
    ; Calcular y guardar checksum
    call SRAM_ComputeChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SRAM_GetTxCount: Obtiene número de transacciones
; Salida: A = número de transacciones
SRAM_GetTxCount:
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Leer contador
    ld hl, $A000 + TX_COUNT_OFFSET
    ld a, [hl]
    
    ; Deshabilitar SRAM
    push af ; Preservar contador
    xor a
    ld [$0000], a
    pop af ; Recuperar contador
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_GetWalletCount: Obtiene número de wallets activos
; Salida: A = número de wallets
SRAM_GetWalletCount:
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Leer contador
    ld hl, $A000 + WALLET_COUNT_OFFSET
    ld a, [hl]
    
    ; Deshabilitar SRAM
    push af ; Preservar contador
    xor a
    ld [$0000], a
    pop af ; Recuperar contador
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_LoadWallet: Carga datos de wallet por índice
; Entrada: A = índice wallet (0-based)
; Salida: Datos en buffers WALLET_NAME y WALLET_ADDR, A=0 si éxito
SRAM_LoadWallet:
    push bc
    push de
    push hl
    
    ; Guardar índice
    ld b, a
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar índice válido
    ld a, b
    ld hl, $A000 + WALLET_COUNT_OFFSET
    cp [hl] ; Comparar con total
    jr nc, .error ; Si es mayor o igual, error
    
    ; Calcular offset al wallet
    ld a, b
    ld h, 0
    ld l, a
    ld bc, WALLET_DATA_LEN
    call SRAM_Multiply_Optimized ; HL = índice * WALLET_DATA_LEN
    ld bc, $A000 + WALLET_DATA_OFFSET
    add hl, bc ; HL = dirección al wallet
    
    ; Verificar si está activo
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .error
    
    ; Cargar nombre (copia segura con límite)
    inc hl ; Saltar byte de estado
    ld de, WALLET_NAME
    ld bc, WALLET_NAME_LEN
    call SRAM_CopyMemory_Safe
    
    ; Cargar dirección (copia segura con límite)
    ; HL ya apunta a la dirección correcta
    ld de, WALLET_ADDR
    ld bc, WALLET_ADDR_LEN
    call SRAM_CopyMemory_Safe
    
    ; Éxito
    xor a
    jr .done
    
.error:
    ; Error
    ld a, 1
    
.done:
    ; Deshabilitar SRAM
    push af ; Preservar resultado
    xor a
    ld [$0000], a
    pop af ; Recuperar resultado
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_SaveWallet: Guarda datos en wallet por índice
; Entrada: A = índice wallet (0-based)
;          WALLET_NAME y WALLET_ADDR contienen los datos
; Salida: A=0 si éxito
SRAM_SaveWallet:
    push bc
    push de
    push hl
    
    ; Guardar índice
    ld b, a
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar índice válido
    ld a, b
    ld hl, $A000 + WALLET_COUNT_OFFSET
    cp [hl] ; Comparar con total
    jr nc, .error ; Si es mayor o igual, error
    
    ; Calcular offset al wallet
    ld a, b
    ld h, 0
    ld l, a
    ld bc, WALLET_DATA_LEN
    call SRAM_Multiply_Optimized ; HL = índice * WALLET_DATA_LEN
    ld bc, $A000 + WALLET_DATA_OFFSET
    add hl, bc ; HL = dirección al wallet
    
    ; Marcar como activo
    ld a, WALLET_ACTIVE
    ld [hl], a
    
    ; Guardar nombre (copia segura con límite)
    inc hl ; Saltar byte de estado
    ld de, hl ; Destino en SRAM
    ld hl, WALLET_NAME ; Origen en RAM
    ld bc, WALLET_NAME_LEN
    call SRAM_CopyToSRAM_Safe
    
    ; Guardar dirección (copia segura con límite)
    ld hl, WALLET_ADDR ; Origen en RAM
    ld bc, WALLET_ADDR_LEN
    call SRAM_CopyToSRAM_Safe
    
    ; Calcular y guardar checksum
    call SRAM_ComputeChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    ; Éxito
    xor a
    jr .done
    
.error:
    ; Error
    ld a, 1
    
.done:
    ; Deshabilitar SRAM
    push af ; Preservar resultado
    xor a
    ld [$0000], a
    pop af ; Recuperar resultado
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_DeleteWallet: Marca un wallet como eliminado
; Entrada: A = índice wallet (0-based)
; Salida: A=0 si éxito
SRAM_DeleteWallet:
    push bc
    push de
    push hl
    
    ; Guardar índice
    ld b, a
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar índice válido
    ld a, b
    ld hl, $A000 + WALLET_COUNT_OFFSET
    cp [hl] ; Comparar con total
    jr nc, .error ; Si es mayor o igual, error
    
    ; Calcular offset al wallet
    ld a, b
    ld h, 0
    ld l, a
    ld bc, WALLET_DATA_LEN
    call SRAM_Multiply_Optimized ; HL = índice * WALLET_DATA_LEN
    ld bc, $A000 + WALLET_DATA_OFFSET
    add hl, bc ; HL = dirección al wallet
    
    ; Marcar como eliminado
    ld a, WALLET_DELETED
    ld [hl], a
    
    ; Decrementar contador
    ld hl, $A000 + WALLET_COUNT_OFFSET
    dec [hl]
    
    ; Calcular y guardar checksum
    call SRAM_ComputeChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    ; Éxito
    xor a
    jr .done
    
.error:
    ; Error
    ld a, 1
    
.done:
    ; Deshabilitar SRAM
    push af ; Preservar resultado
    xor a
    ld [$0000], a
    pop af ; Recuperar resultado
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_LogTransaction: Añade una transacción al log
; Entrada: AddressBuf y AmountBuf contienen los datos
; Salida: A=0 si éxito
SRAM_LogTransaction:
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar si el log está lleno
    ld a, [$A000 + TX_COUNT_OFFSET]
    cp MAX_LOG_ENTRIES
    jr c, .notFull
    
    ; Si está lleno, desplazar entradas (eliminar la más antigua)
    ld hl, $A000 + TX_LOG_OFFSET + TX_LOG_LEN ; Segunda entrada
    ld de, $A000 + TX_LOG_OFFSET ; Primera entrada
    ld bc, (MAX_LOG_ENTRIES - 1) * TX_LOG_LEN
    call SRAM_CopyMemory
    
    ; Ahora TxCount = MAX_LOG_ENTRIES (no cambia)
    jr .prepareEntry
    
.notFull:
    ; Incrementar contador de transacciones
    inc a
    ld [$A000 + TX_COUNT_OFFSET], a
    
.prepareEntry:
    ; Calcular posición para la nueva entrada
    ; Si desplazamos, va en la última posición
    ; Si no, va en la posición TxCount-1
    ld a, [$A000 + TX_COUNT_OFFSET]
    dec a
    ld h, 0
    ld l, a
    ld bc, TX_LOG_LEN
    call SRAM_Multiply_Optimized ; HL = (TxCount-1) * TX_LOG_LEN
    
    ; HL = offset en el log
    ld bc, $A000 + TX_LOG_OFFSET
    add hl, bc
    
    ; Construir entrada en el formato "XXXXX a YYYYY"
    ; donde XXXXX es el monto y YYYYY es la dirección
    
    ; Comenzar con el símbolo "-" (envío)
    ld a, "-"
    ld [hl+], a
    
    ; Copiar monto
    ld de, hl ; Destino en SRAM
    ld hl, AmountBuf ; Origen en RAM
    call SRAM_CopyTerminated_Safe ; Copia hasta terminator
    
    ; Agregar " a "
    ld a, " "
    ld [de], a
    inc de
    ld a, "a"
    ld [de], a
    inc de
    ld a, " "
    ld [de], a
    inc de
    
    ; Copiar dirección (limitado al espacio disponible)
    ld hl, AddressBuf ; Origen en RAM
    call SRAM_CopyTerminated_Safe ; Copia hasta terminator
    
    ; Calcular y guardar checksum
    call SRAM_ComputeChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    ; Éxito
    xor a
    
    ; Deshabilitar SRAM
    push af ; Preservar resultado
    xor a
    ld [$0000], a
    pop af ; Recuperar resultado
    
    pop hl
    pop de
    pop bc
    ret

; SRAM_CreateWallet: Crea un nuevo wallet con los datos actuales
; Entrada: WALLET_NAME y WALLET_ADDR contienen los datos
; Salida: A=0 si éxito, 1 si hay errores
SRAM_CreateWallet:
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Verificar espacio
    ld a, [$A000 + WALLET_COUNT_OFFSET]
    cp MAX_WALLETS
    jr nc, .error ; Si ya hay MAX_WALLETS, error
    
    ; Buscar slot libre
    ld b, a ; B = contador de wallets existentes
    ld c, 0 ; C = índice actual
    ld hl, $A000 + WALLET_DATA_OFFSET
    
.searchLoop:
    ; Verificar si slot está libre
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .foundSlot ; Si no está activo, encontramos slot
    
    ; Avanzar al siguiente slot
    ld de, WALLET_DATA_LEN
    add hl, de
    
    ; Incrementar índice, continuar búsqueda
    inc c
    ld a, c
    cp MAX_WALLETS
    jr c, .searchLoop
    
    ; Si llegamos aquí, no hay slots libres (no debería ocurrir)
    jr .error
    
.foundSlot:
    ; Marcar como activo
    ld a, WALLET_ACTIVE
    ld [hl+], a
    
    ; Copiar nombre
    ld de, hl ; Destino en SRAM
    ld hl, WALLET_NAME ; Origen en RAM
    call SRAM_CopyTerminated_Safe ; Copia hasta terminator
    
    ; Calcular longitud usada
    call SRAM_StringLength
    
    ; Rellenar resto con 0 hasta WALLET_NAME_LEN
    ld a, WALLET_NAME_LEN
    sub l ; A = bytes restantes
    jr c, .nameDone
    jr z, .nameDone
    
    ld b, a ; B = contador de bytes a rellenar
    xor a
    
.padNameLoop:
    ld [de], a
    inc de
    dec b
    jr nz, .padNameLoop
    
.nameDone:
    ; Copiar dirección
    ld hl, WALLET_ADDR ; Origen en RAM
    call SRAM_CopyTerminated_Safe ; Copia hasta terminator
    
    ; Incrementar contador de wallets
    ld hl, $A000 + WALLET_COUNT_OFFSET
    inc [hl]
    
    ; Calcular y guardar checksum
    call SRAM_ComputeChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    ; Éxito
    xor a
    jr .done
    
.error:
    ; Error
    ld a, 1
    
.done:
    ; Deshabilitar SRAM
    push af ; Preservar resultado
    xor a
    ld [$0000], a
    pop af ; Recuperar resultado
    
    pop hl
    pop de
    pop bc
    ret

; --- Funciones auxiliares internas ---

; SRAM_Multiply_Optimized: Multiplica HL por BC (optimizado para potencias de 2)
; Entrada: HL, BC = operandos
; Salida: HL = HL * BC
SRAM_Multiply_Optimized:
    push af
    push bc
    push de
    
    ; Verificar si BC es potencia de 2
    ld a, c
    dec a
    and c
    jr nz, .not_power_of_2
    
    ; BC es potencia de 2, usar shift
    ld a, c
    ld b, 0
.find_power:
    srl a
    jr c, .found_power
    inc b
    jr .find_power
    
.found_power:
    ; b tiene el exponente (2^b = BC)
    dec b  ; Ajustar porque el primer bit ya fue procesado
    inc b  ; Si bc=1, b=0 (no desplazar)
    
.shift_loop:
    ld a, b
    or a
    jr z, .done
    add hl, hl  ; HL *= 2
    dec b
    jr .shift_loop
    
.not_power_of_2:
    ; Usar multiplicación normal
    call SRAM_Multiply
    
.done:
    pop de
    pop bc
    pop af
    ret

; SRAM_Multiply: Multiplica HL por BC (versión general)
; Entrada: HL, BC = operandos
; Salida: HL = HL * BC
SRAM_Multiply:
    ; Si alguno es cero, resultado es cero
    ld a, h
    or l
    jr z, .zero
    
    ld a, b
    or c
    jr z, .zero
    
    ; Guardar valor original de HL
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
    
    ret
    
.zero:
    ; Resultado es cero
    ld hl, 0
    ret

; SRAM_FillMemory: Llena bc bytes en hl con valor en a
SRAM_FillMemory:
    push af
    push bc
    push de
    push hl
    
.loop:
    ld [hl+], a
    dec bc
    ld d, a
    ld a, b
    or c
    ld a, d
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SRAM_CopyMemory: Copia bc bytes desde hl a de
SRAM_CopyMemory:
    push af
    push bc
    push de
    push hl
    
.loop:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SRAM_CopyMemory_Safe: Copia bc bytes desde hl a de con verificación
SRAM_CopyMemory_Safe:
    push af
    push bc
    push de
    push hl
    
.loop:
    ; Verificar si quedan bytes
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
    ; Asegurar terminador
    xor a
    ld [de], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SRAM_CopyToSRAM_Safe: Copia bc bytes desde hl (RAM) a de (SRAM) con verificación
SRAM_CopyToSRAM_Safe:
    ; Similar a SRAM_CopyMemory_Safe pero específico para copiar a SRAM
    push af
    push bc
    push de
    push hl
    
.loop:
    ; Verificar si quedan bytes
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
    ; Asegurar terminador
    xor a
    ld [de], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SRAM_CopyTerminated_Safe: Copia string terminada en 0 de hl a de
; Asume que hay suficiente espacio en destino
; Retorna de apuntando después del último byte copiado
SRAM_CopyTerminated_Safe:
    push af
    push bc
    push hl
    
    ; Establecer límite máximo (para seguridad)
    ld bc, 255
    
.loop:
    ; Verificar límite
    ld a, b
    or c
    jr z, .limit_reached
    
    ; Leer byte
    ld a, [hl+]
    
    ; Verificar fin de cadena
    or a
    jr z, .done
    
    ; Copiar byte
    ld [de], a
    inc de
    
    ; Decrementar contador de seguridad
    dec bc
    jr .loop
    
.limit_reached:
    ; Asegurar terminador
    xor a
    ld [de], a
    
.done:
    ; Terminar con 0
    xor a
    ld [de], a
    
    ; DE ya apunta a la posición correcta
    pop hl
    pop bc
    pop af
    ret

; SRAM_StringLength: Calcula la longitud de una cadena
; Entrada: HL = puntero a cadena
; Salida: L = longitud
SRAM_StringLength:
    push af
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
    ld l, b
    
    pop hl
    pop bc
    pop af
    ret

; --- Variables en RAM ---
SECTION "SRAMVars", WRAM0[$CC00]
WALLET_NAME:    DS WALLET_NAME_LEN
WALLET_ADDR:    DS WALLET_ADDR_LEN
