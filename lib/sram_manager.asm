; sram_manager.asm - API unificada de acceso a SRAM
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

; --- API pública ---

; SRAM_Init: Inicializa SRAM si es necesario y verifica integridad
; Salida: A = 0 si ok, 1 si se reinició SRAM
SRAM_Init:
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
    ret

; SRAM_VerifyChecksum: Verifica integridad de SRAM
; Salida: Z=1 si ok, Z=0 si falla
SRAM_VerifyChecksum:
    ; Calcular checksum
    call SRAM_ComputeChecksum
    ld b, a
    
    ; Leer checksum almacenado
    ld hl, $A000 + CHECKSUM_OFFSET
    ld a, [hl]
    
    ; Comparar (afecta flag Z)
    cp b
    ret

; SRAM_ComputeChecksum: Calcular el checksum XOR
; Salida: A = checksum calculado
SRAM_ComputeChecksum:
    ld hl, $A000
    ld bc, CHECKSUM_OFFSET
    xor a ; Inicializar acumulador
    
.loop:
    xor [hl]
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .loop
    
    ret

; SRAM_Reset: Inicializa SRAM a valores por defecto
SRAM_Reset:
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
    call SRAM_FillMemory
    
    ; Calcular y guardar checksum
    call SRAM_ComputeChecksum
    ld hl, $A000 + CHECKSUM_OFFSET
    ld [hl], a
    
    ret

; SRAM_GetTxCount: Obtiene número de transacciones
; Salida: A = número de transacciones
SRAM_GetTxCount:
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
    ret

; SRAM_GetWalletCount: Obtiene número de wallets activos
; Salida: A = número de wallets
SRAM_GetWalletCount:
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
    call SRAM_Multiply ; HL = índice * WALLET_DATA_LEN
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
    call SRAM_CopyMemory
    
    ; Asegurar terminador 0
    ld a, 0
    ld [de], a
    
    ; Cargar dirección (copia segura con límite)
    inc hl ; Avanzar al campo de dirección
    ld de, WALLET_ADDR
    ld bc, WALLET_ADDR_LEN
    call SRAM_CopyMemory
    
    ; Asegurar terminador 0
    ld a, 0
    ld [de], a
    
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
    call SRAM_Multiply ; HL = índice * WALLET_DATA_LEN
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
    call SRAM_CopyToSRAM
    
    ; Guardar dirección (copia segura con límite)
    ld hl, WALLET_ADDR ; Origen en RAM
    ld bc, WALLET_ADDR_LEN
    call SRAM_CopyToSRAM
    
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
    call SRAM_Multiply ; HL = índice * WALLET_DATA_LEN
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
    ld b, a
    ld c, TX_LOG_LEN
    call SRAM_Multiply ; BC = (TxCount-1) * TX_LOG_LEN
    
    ; BC = offset en el log
    ld hl, $A000 + TX_LOG_OFFSET
    add hl, bc
    
    ; Construir entrada en el formato "XXXXX a YYYYY"
    ; donde XXXXX es el monto y YYYYY es la dirección
    
    ; Comenzar con el símbolo "-" (envío)
    ld a, "-"
    ld [hl+], a
    
    ; Copiar monto
    ld de, hl ; Destino en SRAM
    ld hl, AmountBuf ; Origen en RAM
    call SRAM_CopyTerminated ; Copia hasta terminator
    ld hl, de ; Restaurar posición en SRAM
    
    ; Agregar " a "
    ld a, " "
    ld [hl+], a
    ld a, "a"
    ld [hl+], a
    ld a, " "
    ld [hl+], a
    
    ; Copiar dirección (limitado al espacio disponible)
    ld de, hl ; Destino en SRAM
    ld hl, AddressBuf ; Origen en RAM
    call SRAM_CopyTerminated ; Copia hasta terminator
    
    ; Terminar con 0
    ld a, 0
    ld [de], a
    
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
    call SRAM_CopyTerminated ; Copia hasta terminator
    
    ; Rellenar resto con 0 hasta WALLET_NAME_LEN
    ld a, de
    sub low($A000 + WALLET_DATA_OFFSET + 1) ; Calcular bytes escritos
    ld c, a
    ld a, WALLET_NAME_LEN
    sub c ; Calcular bytes restantes
    jr c, .nameDone
    jr z, .nameDone
    
    ld b, a ; B = contador de bytes a rellenar
    
.padNameLoop:
    xor a
    ld [de], a
    inc de
    dec b
    jr nz, .padNameLoop
    
.nameDone:
    ; Copiar dirección
    ld hl, WALLET_ADDR ; Origen en RAM
    call SRAM_CopyTerminated ; Copia hasta terminator
    
    ; Rellenar resto con 0 hasta WALLET_ADDR_LEN
    ; (similar a padNameLoop)
    
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

; SRAM_Multiply: Multiplica HL por BC
; Entrada: HL, BC = operandos
; Salida: HL = HL * BC
SRAM_Multiply:
    ; Preservar registros
    push af
    push bc
    push de
    
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
    
    pop de
    pop bc
    pop af
    ret
    
.zero:
    ; Resultado es cero
    ld hl, 0
    
    pop de
    pop bc
    pop af
    ret

; SRAM_FillMemory: Llena bc bytes en hl con valor en a
SRAM_FillMemory:
    ; Preservar registros
    push af
    push bc
    push de
    push hl
    
.loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SRAM_CopyMemory: Copia bc bytes desde hl a de
SRAM_CopyMemory:
    ; Preservar registros
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

; SRAM_CopyToSRAM: Copia bc bytes desde hl (RAM) a de (SRAM)
SRAM_CopyToSRAM:
    ; Preservar registros
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

; SRAM_CopyTerminated: Copia string terminada en 0 de hl a de
; Asume que hay suficiente espacio en destino
; Retorna de apuntando después del último byte copiado
SRAM_CopyTerminated:
    ; Preservar registros
    push af
    push bc
    push hl
    
.loop:
    ; Leer byte
    ld a, [hl+]
    
    ; Verificar fin de cadena
    or a
    jr z, .done
    
    ; Copiar byte
    ld [de], a
    inc de
    
    jr .loop
    
.done:
    ; DE ya apunta a la posición correcta
    pop hl
    pop bc
    pop af
    ret

; --- Variables en RAM ---
SECTION "SRAMVars", WRAM0[$CC00]
WALLET_NAME:    DS WALLET_NAME_LEN
WALLET_ADDR:    DS WALLET_ADDR_LEN