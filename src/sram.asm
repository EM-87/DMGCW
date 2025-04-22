; sram.asm - Módulo de gestión de SRAM para múltiples wallets
INCLUDE "hardware.inc"

SECTION "SRAMModule", ROM1[$5500]

; --- Constantes ---
MAX_WALLETS:        EQU 5   ; Máximo número de wallets almacenados
WALLET_NAME_LEN:    EQU 12  ; Longitud máxima del nombre de wallet
WALLET_ADDR_LEN:    EQU 24  ; Longitud máxima de la dirección
WALLET_DATA_LEN:    EQU WALLET_NAME_LEN + WALLET_ADDR_LEN + 1  ; +1 para byte de estado

; Offsets SRAM para wallets
WALLET_COUNT_OFFSET:    EQU 0
WALLET_DATA_OFFSET:     EQU 1
WALLET_CHECKSUM_OFFSET: EQU WALLET_DATA_OFFSET + (MAX_WALLETS * WALLET_DATA_LEN)

; Flags de estado wallet
WALLET_ACTIVE:     EQU 1   ; Wallet activo
WALLET_DELETED:    EQU 0   ; Wallet eliminado

; --- Entry Point ---
Entry_SRAM:
    push af
    push bc
    push de
    push hl
    
    ; Mostrar menú de gestión de wallets
    call DrawWalletMenu
    
.menuLoop:
    ; Leer input
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .menuLoop
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Verificar botones
    bit PADB_UP, a
    jr nz, .moveUp
    
    bit PADB_DOWN, a
    jr nz, .moveDown
    
    bit PADB_A, a
    jr nz, .selectOption
    
    bit PADB_B, a
    jr nz, .exit
    
    jr .menuLoop
    
.moveUp:
    ld a, [WalletMenuCursor]
    or a
    jr z, .wrapDown  ; Si estamos en 0, ir al último
    
    ; Decrementar cursor
    dec a
    ld [WalletMenuCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar menú
    call DrawWalletMenu
    
    jr .menuLoop
    
.wrapDown:
    ; Ir a la última opción
    ld a, 3  ; Opciones 0-3
    ld [WalletMenuCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar menú
    call DrawWalletMenu
    
    jr .menuLoop
    
.moveDown:
    ld a, [WalletMenuCursor]
    cp 3  ; Última opción
    jr z, .wrapUp  ; Si estamos en el último, ir al primero
    
    ; Incrementar cursor
    inc a
    ld [WalletMenuCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar menú
    call DrawWalletMenu
    
    jr .menuLoop
    
.wrapUp:
    ; Ir a la primera opción
    xor a
    ld [WalletMenuCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar menú
    call DrawWalletMenu
    
    jr .menuLoop
    
.selectOption:
    ; Reproducir sonido
    call PlayBeepConfirm
    
    ; Ejecutar opción según cursor
    ld a, [WalletMenuCursor]
    or a
    jp z, DoListWallets
    
    cp 1
    jp z, DoCreateWallet
    
    cp 2
    jp z, DoDeleteWallet
    
    cp 3
    jp z, DoSelectWallet
    
    ; Si llegamos aquí, índice inválido
    jr .menuLoop
    
.exit:
    ; Reproducir sonido
    call PlayBeepNav
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; DrawWalletMenu: Dibuja el menú de gestión de wallets
DrawWalletMenu:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, WalletTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Dibujar opciones
    ld hl, WalletOptList
    ld d, 3   ; y
    ld e, 4   ; x
    call PrintStringAtXY
    
    ld hl, WalletOptCreate
    ld d, 4   ; y
    ld e, 4   ; x
    call PrintStringAtXY
    
    ld hl, WalletOptDelete
    ld d, 5   ; y
    ld e, 4   ; x
    call PrintStringAtXY
    
    ld hl, WalletOptSelect
    ld d, 6   ; y
    ld e, 4   ; x
    call PrintStringAtXY
    
    ; Dibujar indicador del cursor
    ld a, [WalletMenuCursor]
    add 3  ; y base + offset cursor
    ld d, a
    ld e, 2  ; x
    ld a, ">"
    call PrintAtXY
    
    ; Dibujar información de wallets actuales
    ld hl, WalletCountMsg
    ld d, 9   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar contador de wallets
    call GetWalletCount
    ld d, 9   ; y
    ld e, 16  ; x
    call ShowNumberAtXY
    
    ; Mostrar wallet actual
    ld hl, WalletCurrentMsg
    ld d, 10  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar nombre de wallet actual
    ld hl, CurrentWalletName
    ld d, 11  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, WalletInstructions
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ret

; DoListWallets: Muestra la lista de wallets
DoListWallets:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, WalletListTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Obtener número de wallets
    call GetWalletCount
    
    ; Si no hay wallets, mostrar mensaje
    or a
    jr nz, .hasWallets
    
    ld hl, WalletEmptyMsg
    ld d, 8   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    jr .waitKey
    
.hasWallets:
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Mostrar lista de wallets
    ld b, a   ; B = contador de wallets
    ld c, 3   ; C = posición Y inicial
    ld hl, $A000 + WALLET_DATA_OFFSET  ; HL = inicio de datos
    
.listLoop:
    ; Verificar si wallet está activo
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .skipWallet
    
    ; Mostrar índice
    ld a, c
    sub 3
    add "1"
    ld d, c   ; y
    ld e, 2   ; x
    call PrintAtXY
    
    ; Mostrar nombre
    push bc
    push hl
    
    inc hl   ; Saltar byte de estado
    ld d, c  ; y
    ld e, 4  ; x
    call PrintHLString
    
    pop hl
    pop bc
    
    ; Siguiente posición Y
    inc c
    
.skipWallet:
    ; Avanzar al siguiente wallet
    ld de, WALLET_DATA_LEN
    add hl, de
    
    ; Decrementar contador
    dec b
    jr nz, .listLoop
    
    ; Desactivar SRAM
    xor a
    ld [$0000], a
    
.waitKey:
    ; Instrucción para volver
    ld hl, BackMsg
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Esperar tecla para volver
    call WaitButton
    
    ; Redibujar menú
    jp DrawWalletMenu

; PrintHLString: Imprime cadena apuntada por HL en posición D,E
PrintHLString:
    push af
    push bc
    push de
    push hl
    
.loop:
    ld a, [hl]
    or a
    jr z, .done
    
    call PrintAtXY
    
    inc hl
    inc e
    jr .loop
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; DoCreateWallet: Crea un nuevo wallet
DoCreateWallet:
    ; Verificar si hay espacio
    call GetWalletCount
    cp MAX_WALLETS
    jr c, .hasSpace
    
    ; No hay espacio, mostrar error
    call ShowWalletFullError
    
    ; Volver al menú
    jp DrawWalletMenu
    
.hasSpace:
    ; Mostrar pantalla de creación
    call DrawCreateScreen
    
    ; Inicializar buffer de entrada
    ld hl, WalletNameBuffer
    xor a
    ld [hl], a
    
    ld hl, WalletAddrBuffer
    xor a
    ld [hl], a
    
    ; Inicializar estado de entrada
    xor a
    ld [InputField], a  ; 0 = nombre
    ld [InputPos], a
    
.inputLoop:
    ; Leer input
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .inputLoop
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Verificar botones
    bit PADB_LEFT, a
    jr nz, .charPrev
    
    bit PADB_RIGHT, a
    jr nz, .charNext
    
    bit PADB_SELECT, a
    jr nz, .toggleField
    
    bit PADB_A, a
    jr nz, .addChar
    
    bit PADB_B, a
    jr nz, .cancel
    
    bit PADB_START, a
    jr nz, .saveWallet
    
    jr .inputLoop
    
.charPrev:
    ; Caracter anterior
    ld a, [InputChar]
    or a
    jr nz, .notFirstChar
    
    ; Wrap a último caracter
    ld a, CharsetLen - 1
    jr .updateChar
    
.notFirstChar:
    dec a
    
.updateChar:
    ld [InputChar], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Actualizar pantalla
    call UpdateCreateScreen
    
    jr .inputLoop
    
.charNext:
    ; Siguiente caracter
    ld a, [InputChar]
    inc a
    cp CharsetLen
    jr c, .notLastChar
    
    ; Wrap a primer caracter
    xor a
    
.notLastChar:
    ld [InputChar], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Actualizar pantalla
    call UpdateCreateScreen
    
    jr .inputLoop
    
.toggleField:
    ; Cambiar entre nombre y dirección
    ld a, [InputField]
    xor 1
    ld [InputField], a
    
    ; Actualizar posición según campo actual
    ld a, [InputField]
    or a
    jr nz, .getAddrPos
    
    ; Obtener posición en nombre
    call GetWalletNameLength
    jr .updatePos
    
.getAddrPos:
    ; Obtener posición en dirección
    call GetWalletAddrLength
    
.updatePos:
    ld [InputPos], a
    
    ; Reproducir sonido
    call PlayBeepConfirm
    
    ; Actualizar pantalla
    call UpdateCreateScreen
    
    jr .inputLoop
    
.addChar:
    ; Añadir caracter al campo actual
    ld a, [InputField]
    or a
    jr nz, .addToAddr
    
    ; Añadir al nombre
    ld a, [InputPos]
    cp WALLET_NAME_LEN - 1
    jr nc, .inputLoop  ; No añadir si estamos en el límite
    
    ; Obtener caracter actual
    ld a, [InputChar]
    ld b, a
    
    ; Obtener caracter del charset
    ld hl, Charset
    ld c, 0
    add hl, bc
    ld a, [hl]
    
    ; Añadir al buffer
    ld hl, WalletNameBuffer
    ld c, a           ; Guardar caracter
    ld a, [InputPos]
    ld b, 0
    push bc
    ld c, a
    add hl, bc        ; HL += posición
    pop bc
    ld a, c           ; Recuperar caracter
    ld [hl], a
    
    ; Añadir terminador
    inc hl
    ld [hl], 0
    
    ; Incrementar posición
    ld a, [InputPos]
    inc a
    ld [InputPos], a
    
    jr .charAdded
    
.addToAddr:
    ; Añadir a la dirección
    ld a, [InputPos]
    cp WALLET_ADDR_LEN - 1
    jr nc, .inputLoop  ; No añadir si estamos en el límite
    
    ; Obtener caracter actual
    ld a, [InputChar]
    ld b, a
    
    ; Obtener caracter del charset
    ld hl, Charset
    ld c, 0
    add hl, bc
    ld a, [hl]
    
    ; Añadir al buffer
    ld hl, WalletAddrBuffer
    ld c, a           ; Guardar caracter
    ld a, [InputPos]
    ld b, 0
    push bc
    ld c, a
    add hl, bc        ; HL += posición
    pop bc
    ld a, c           ; Recuperar caracter
    ld [hl], a
    
    ; Añadir terminador
    inc hl
    ld [hl], 0
    
    ; Incrementar posición
    ld a, [InputPos]
    inc a
    ld [InputPos], a
    
.charAdded:
    ; Reproducir sonido
    call PlayBeepConfirm
    
    ; Actualizar pantalla
    call UpdateCreateScreen
    
    jr .inputLoop
    
.cancel:
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Volver al menú
    jp DrawWalletMenu
    
.saveWallet:
    ; Verificar que ambos campos tengan datos
    ld a, [WalletNameBuffer]
    or a
    jr z, .invalidData
    
    ld a, [WalletAddrBuffer]
    or a
    jr z, .invalidData
    
    ; Guardar wallet
    call SaveNewWallet
    
    ; Mostrar mensaje de éxito
    call ShowWalletSavedMsg
    
    ; Esperar tecla
    call WaitButton
    
    ; Volver al menú
    jp DrawWalletMenu
    
.invalidData:
    ; Mostrar error de datos inválidos
    call ShowInvalidDataError
    
    ; Volver al bucle
    jp .inputLoop

; GetWalletNameLength: Calcula longitud del nombre actual
; Salida: A = longitud
GetWalletNameLength:
    push bc
    push hl
    
    ld hl, WalletNameBuffer
    ld b, 0
    
.loop:
    ld a, [hl+]
    or a
    jr z, .done
    inc b
    ; Protección contra desbordamiento
    ld a, b
    cp WALLET_NAME_LEN
    jr z, .done
    jr .loop
    
.done:
    ld a, b
    
    pop hl
    pop bc
    ret

; GetWalletAddrLength: Calcula longitud de la dirección actual
; Salida: A = longitud
GetWalletAddrLength:
    push bc
    push hl
    
    ld hl, WalletAddrBuffer
    ld b, 0
    
.loop:
    ld a, [hl+]
    or a
    jr z, .done
    inc b
    ; Protección contra desbordamiento
    ld a, b
    cp WALLET_ADDR_LEN
    jr z, .done
    jr .loop
    
.done:
    ld a, b
    
    pop hl
    pop bc
    ret

; DrawCreateScreen: Dibuja la pantalla de creación de wallet
DrawCreateScreen:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, CreateTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Etiqueta nombre
    ld hl, NameLabel
    ld d, 3   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar buffer nombre
    ld hl, WalletNameBuffer
    ld d, 4   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Etiqueta dirección
    ld hl, AddrLabel
    ld d, 6   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar buffer dirección
    ld hl, WalletAddrBuffer
    ld d, 7   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Etiqueta caracter
    ld hl, CharLabel
    ld d, 10  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar caracter actual
    ld a, [InputChar]
    ld b, a
    ld hl, Charset
    ld c, 0
    add hl, bc
    ld a, [hl]
    ld d, 10  ; y
    ld e, 10  ; x
    call PrintAtXY
    
    ; Etiqueta campo
    ld hl, FieldLabel
    ld d, 11  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Mostrar campo actual
    ld a, [InputField]
    or a
    jr nz, .showAddr
    
    ld hl, NameValue
    jr .showField
    
.showAddr:
    ld hl, AddrValue
    
.showField:
    ld d, 11  ; y
    ld e, 10  ; x
    call PrintStringAtXY
    
    ; Instrucciones
    ld hl, CreateInstr1
    ld d, 13  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ld hl, CreateInstr2
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ret

; UpdateCreateScreen: Actualiza la pantalla de creación sin redibujarlo todo
UpdateCreateScreen:
    ; Actualizar buffer de nombre
    ld hl, WalletNameBuffer
    ld d, 4   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Limpiar resto de la línea
    ld a, [InputField]
    or a
    jr nz, .skipNameClear
    
    ; Calcular posición del cursor en el buffer del nombre
    call GetWalletNameLength
    add 2     ; Ajustar por posición x
    ld e, a
    ld d, 4   ; y
    ld b, 16  ; Longitud a limpiar
    call ClearLine
    
.skipNameClear:
    ; Actualizar buffer de dirección
    ld hl, WalletAddrBuffer
    ld d, 7   ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Limpiar resto de la línea
    ld a, [InputField]
    or a
    jr z, .skipAddrClear
    
    ; Calcular posición del cursor en el buffer de dirección
    call GetWalletAddrLength
    add 2     ; Ajustar por posición x
    ld e, a
    ld d, 7   ; y
    ld b, 16  ; Longitud a limpiar
    call ClearLine
    
.skipAddrClear:
    ; Actualizar caracter actual
    ld a, [InputChar]
    ld b, a
    ld hl, Charset
    ld c, 0
    add hl, bc
    ld a, [hl]
    ld d, 10  ; y
    ld e, 10  ; x
    call PrintAtXY
    
    ; Actualizar campo actual
    ld a, [InputField]
    or a
    jr nz, .showAddrUpdate
    
    ld hl, NameValue
    jr .showFieldUpdate
    
.showAddrUpdate:
    ld hl, AddrValue
    
.showFieldUpdate:
    ld d, 11  ; y
    ld e, 10  ; x
    call PrintStringAtXY
    
    ret

; ClearLine: Limpia parte de una línea en la pantalla
; Entrada: D=y, E=x de inicio, B=longitud a limpiar
ClearLine:
    push af
    push bc
    push de
    push hl
    
    ; Calcular posición en VRAM
    ld h, 0
    ld l, d
    ld c, 32
    call Multiply  ; HL = y * 32
    
    ld c, e
    ld b, 0
    add hl, bc     ; HL += x
    
    ld bc, _SCRN0
    add hl, bc     ; HL += base VRAM
    
    ; Limpiar caracteres
    ld a, " "
    ld c, b        ; C = contador longitud
    
.loop:
    ld [hl+], a
    dec c
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SaveNewWallet: Guarda el nuevo wallet en SRAM
SaveNewWallet:
    push af
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Obtener contador actual
    ld hl, $A000 + WALLET_COUNT_OFFSET
    ld a, [hl]
    
    ; Incrementar contador
    inc a
    ld [hl], a
    
    ; Buscar posición libre
    ld hl, $A000 + WALLET_DATA_OFFSET
    ld b, MAX_WALLETS
    
.findLoop:
    ; Verificar si slot está libre
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .foundSlot
    
    ; Avanzar al siguiente slot
    ld de, WALLET_DATA_LEN
    add hl, de
    
    ; Decrementar contador
    dec b
    jr nz, .findLoop
    
    ; Si llegamos aquí, no hay slots libres (no debería ocurrir)
    jr .done
    
.foundSlot:
    ; Marcar como activo
    ld a, WALLET_ACTIVE
    ld [hl+], a
    
    ; Guardar posición para escritura segura
    push hl
    
    ; Copiar nombre con límite
    ld hl, WalletNameBuffer
    pop de          ; DE = destino SRAM
    push de         ; Preservar DE
    ld bc, WALLET_NAME_LEN  ; Límite
    call SafeCopyString
    
    ; Restaurar DE al final de la copia de nombre
    pop de
    
    ; Calcular posición final después de copiar nombre
    ld hl, WalletNameBuffer
    call GetStringLength
    inc a           ; +1 por el terminador nulo
    ld b, 0
    ld c, a
    ex de, hl       ; HL = destino SRAM
    add hl, bc      ; HL = destino + longitud nombre
    
    ; DE = posición para dirección, considerando padding
    ld de, WALLET_NAME_LEN
    ld a, c         ; A = longitud + terminador
    ld c, a
    ld a, e         ; A = tamaño campo nombre
    sub c           ; A = espacio restante en campo nombre
    jr c, .noNamePadding
    
    ; Añadir padding si es necesario
    ld c, a         ; C = bytes padding
    ld a, 0         ; Carácter nulo para padding
    
.padNameLoop:
    ld [hl+], a
    dec c
    jr nz, .padNameLoop
    
.noNamePadding:
    ; Copiar dirección con límite
    ld de, WalletAddrBuffer
    ld bc, WALLET_ADDR_LEN  ; Límite
    call SafeCopyString
    
    ; Calcular y guardar checksum
    call CalcSRAMWalletChecksum
    ld hl, $A000 + WALLET_CHECKSUM_OFFSET
    ld [hl], a
    
.done:
    ; Desactivar SRAM
    xor a
    ld [$0000], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; SafeCopyString: Copia una cadena con límite de longitud
; Entrada: DE = origen, HL = destino, BC = longitud máxima
; Modifica: AF, BC, DE, HL
SafeCopyString:
    push bc
    
.loop:
    ; Verificar si hemos alcanzado el límite
    ld a, b
    or c
    jr z, .limitReached
    
    ; Cargar carácter
    ld a, [de]
    
    ; Comprobar fin de cadena
    or a
    jr z, .done
    
    ; Copiar carácter
    ld [hl+], a
    inc de
    
    ; Decrementar contador
    dec bc
    jr .loop
    
.limitReached:
    ; Asegurarnos de terminar con nulo
    xor a
    ld [hl], a
    jr .exit
    
.done:
    ; Copiar terminador nulo
    ld [hl], a
    
.exit:
    pop bc
    ret

; GetStringLength: Calcula la longitud de una cadena
; Entrada: HL = puntero a cadena
; Salida: A = longitud
GetStringLength:
    push bc
    push hl
    
    ld b, 0  ; Contador
    
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

; CalcSRAMWalletChecksum: Calcula checksum de datos de wallets
; Salida: A = checksum
CalcSRAMWalletChecksum:
    push bc
    push de
    push hl
    
    ; Inicializar checksum
    xor a
    
    ; Contador de wallets
    ld hl, $A000 + WALLET_COUNT_OFFSET
    xor [hl]
    
    ; Datos de wallets
    ld hl, $A000 + WALLET_DATA_OFFSET
    ld bc, MAX_WALLETS * WALLET_DATA_LEN
    
.loop:
    xor [hl]
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .loop
    
    pop hl
    pop de
    pop bc
    ret
