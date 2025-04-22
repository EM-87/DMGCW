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
    ld a, 0
    ld [hl], a
    
    ld hl, WalletAddrBuffer
    ld a, 0
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
    ld c, [InputPos]
    ld b, 0
    add hl, bc
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
    ld c, [InputPos]
    ld b, 0
    add hl, bc
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
    
    ld a, [InputPos]
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
    
    ld a, [InputPos]
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
    
    ; Copiar nombre
    ld de, WalletNameBuffer
    
.copyNameLoop:
    ld a, [de]
    ld [hl+], a
    inc de
    
    ; Verificar terminador
    or a
    jr nz, .copyNameLoop
    
    ; Rellenar resto con 0 hasta WALLET_NAME_LEN
    ld a, l
    sub low($A000 + WALLET_DATA_OFFSET + 1)  ; Calcular bytes escritos
    ld c, a
    ld a, WALLET_NAME_LEN
    sub c        ; Calcular bytes restantes
    jr c, .nameDone
    jr z, .nameDone
    
    ld b, a     ; B = contador
    
.padNameLoop:
    xor a
    ld [hl+], a
    dec b
    jr nz, .padNameLoop
    
.nameDone:
    ; Copiar dirección
    ld de, WalletAddrBuffer
    
.copyAddrLoop:
    ld a, [de]
    ld [hl+], a
    inc de
    
    ; Verificar terminador
    or a
    jr nz, .copyAddrLoop
    
    ; Rellenar resto con 0 hasta WALLET_ADDR_LEN
    ld a, l
    sub low($A000 + WALLET_DATA_OFFSET + 1 + WALLET_NAME_LEN)  ; Calcular bytes escritos
    ld c, a
    ld a, WALLET_ADDR_LEN
    sub c        ; Calcular bytes restantes
    jr c, .addrDone
    jr z, .addrDone
    
    ld b, a     ; B = contador
    
.padAddrLoop:
    xor a
    ld [hl+], a
    dec b
    jr nz, .padAddrLoop
    
.addrDone:
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

; DoDeleteWallet: Elimina un wallet
DoDeleteWallet:
    ; Verificar si hay wallets
    call GetWalletCount
    or a
    jr nz, .hasWallets
    
    ; No hay wallets, mostrar error
    call ShowNoWalletsError
    
    ; Volver al menú
    jp DrawWalletMenu
    
.hasWallets:
    ; Mostrar pantalla de selección para eliminar
    call DrawDeleteScreen
    
    ; Inicializar cursor
    xor a
    ld [DeleteCursor], a
    
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
    bit PADB_UP, a
    jr nz, .moveUp
    
    bit PADB_DOWN, a
    jr nz, .moveDown
    
    bit PADB_A, a
    jr nz, .selectDelete
    
    bit PADB_B, a
    jr nz, .cancel
    
    jr .inputLoop
    
.moveUp:
    ld a, [DeleteCursor]
    or a
    jr z, .wrapDown  ; Si estamos en 0, ir al último
    
    ; Decrementar cursor
    dec a
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.wrapDown:
    ; Obtener número de wallets
    call GetWalletCount
    dec a  ; 0-indexado
    
    ; Guardar como cursor
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.moveDown:
    ; Obtener número de wallets
    call GetWalletCount
    dec a  ; 0-indexado
    
    ; Comparar con cursor actual
    ld b, a
    ld a, [DeleteCursor]
    cp b
    jr z, .wrapUp  ; Si estamos en el último, ir al primero
    
    ; Incrementar cursor
    inc a
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.wrapUp:
    ; Ir a la primera opción
    xor a
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.selectDelete:
    ; Pedir confirmación
    call DrawDeleteConfirm
    
    ; Esperar respuesta
.confirmLoop:
    ; Leer input
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .confirmLoop
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Verificar botones
    bit PADB_A, a
    jr nz, .confirmDelete
    
    bit PADB_B, a
    jr nz, .cancelDelete
    
    jr .confirmLoop
    
.confirmDelete:
    ; Eliminar wallet
    call DeleteWallet
    
    ; Mostrar mensaje de éxito
    call ShowDeletedMsg
    
    ; Esperar tecla
    call WaitButton
    
    ; Volver al menú
    jp DrawWalletMenu
    
.cancelDelete:
    ; Volver a pantalla de selección
    call DrawDeleteScreen
    
    jp .inputLoop
    
.cancel:
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Volver al menú
    jp DrawWalletMenu

; DrawDeleteScreen: Dibuja la pantalla de selección para eliminar
DrawDeleteScreen:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, DeleteTitle
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
    
    jr .showInstructions
    
.hasWallets:
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Mostrar lista de wallets
    ld b, a   ; B = contador de wallets
    ld c, 3   ; C = posición Y inicial
    ld hl, $A000 + WALLET_DATA_OFFSET  ; HL = inicio de datos
    
    ; Resetear índice wallet
    xor a
    ld [WalletIndex], a
    
.listLoop:
    ; Verificar si wallet está activo
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .skipWallet
    
    ; Mostrar índice
    ld a, [WalletIndex]
    add "1"
    ld d, c   ; y
    ld e, 3   ; x
    call PrintAtXY
    
    ; Mostrar nombre
    push bc
    push hl
    
    inc hl   ; Saltar byte de estado
    ld d, c  ; y
    ld e, 5  ; x
    call PrintHLString
    
    pop hl
    pop bc
    
    ; Dibujar cursor si es la selección actual
    ld a, [DeleteCursor]
    ld e, a
    ld a, [WalletIndex]
    cp e
    jr nz, .noCursor
    
    ; Dibujar cursor
    ld a, ">"
    ld d, c   ; y
    ld e, 1   ; x
    call PrintAtXY
    
.noCursor:
    ; Siguiente posición Y
    inc c
    
    ; Incrementar índice
    ld a, [WalletIndex]
    inc a
    ld [WalletIndex], a
    
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
    
.showInstructions:
    ; Instrucciones
    ld hl, DeleteInstr
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ret

; DrawDeleteConfirm: Pide confirmación para eliminar
DrawDeleteConfirm:
    ; Limpiar área de mensaje
    ld d, 10  ; y
    ld e, 2   ; x
    ld b, 16  ; longitud
    call ClearLine
    
    ld d, 11  ; y
    ld e, 2   ; x
    ld b, 16  ; longitud
    call ClearLine
    
    ; Mostrar mensaje de confirmación
    ld hl, DeleteConfirmMsg
    ld d, 10  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Instrucciones
    ld hl, DeleteConfirmInstr
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ret

; DeleteWallet: Elimina el wallet seleccionado
DeleteWallet:
    push af
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Buscar wallet por índice
    ld hl, $A000 + WALLET_DATA_OFFSET
    ld b, 0  ; contador
    
.findLoop:
    ; Verificar si wallet está activo
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .skipWallet
    
    ; Verificar si es el índice buscado
    ld a, b
    ld e, [DeleteCursor]
    cp e
    jr z, .foundWallet
    
    ; Incrementar índice
    inc b
    
.skipWallet:
    ; Avanzar al siguiente wallet
    ld de, WALLET_DATA_LEN
    add hl, de
    
    ; Verificar límite
    ld a, b
    cp MAX_WALLETS
    jr c, .findLoop
    
    ; Si llegamos aquí, no se encontró el wallet
    jr .done
    
.foundWallet:
    ; Marcar como eliminado
    ld a, WALLET_DELETED
    ld [hl], a
    
    ; Decrementar contador de wallets
    ld hl, $A000 + WALLET_COUNT_OFFSET
    ld a, [hl]
    dec a
    ld [hl], a
    
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

; DoSelectWallet: Selecciona un wallet como actual
DoSelectWallet:
    ; Verificar si hay wallets
    call GetWalletCount
    or a
    jr nz, .hasWallets
    
    ; No hay wallets, mostrar error
    call ShowNoWalletsError
    
    ; Volver al menú
    jp DrawWalletMenu
    
.hasWallets:
    ; Mostrar pantalla de selección
    call DrawSelectScreen
    
    ; Inicializar cursor
    xor a
    ld [SelectCursor], a
    
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
    bit PADB_UP, a
    jr nz, .moveUp
    
    bit PADB_DOWN, a
    jr nz, .moveDown
    
    bit PADB_A, a
    jr nz, .selectWallet
    
    bit PADB_B, a
    jr nz, .cancel
    
    jr .inputLoop
    
.moveUp:
    ld a, [SelectCursor]
    or a
    jr z, .wrapDown  ; Si estamos en 0, ir al último
    
    ; Decrementar cursor
    dec a
    ld [SelectCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectScreen
    
    jr .inputLoop
    
.wrapDown:
    ; Obtener número de wallets
    call GetWalletCount
    dec a  ; 0-indexado
    
    ; Guardar como cursor
    ld [SelectCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectScreen
    
    jr .inputLoop
    
.moveDown:
    ; Obtener número de wallets
    call GetWalletCount
    dec a  ; 0-indexado
    
    ; Comparar con cursor actual
    ld b, a
    ld a, [SelectCursor]
    cp b
    jr z, .wrapUp  ; Si estamos en el último, ir al primero
    
    ; Incrementar cursor
    inc a
    ld [SelectCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectScreen
    
    jr .inputLoop
    
.wrapUp:
    ; Ir a la primera opción
    xor a
    ld [SelectCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectScreen
    
    jr .inputLoop
    
.selectWallet:
    ; Seleccionar wallet
    call SelectWallet
    
    ; Mostrar mensaje de éxito
    call ShowSelectedMsg
    
    ; Esperar tecla
    call WaitButton
    
    ; Volver al menú
    jp DrawWalletMenu
    
.cancel:
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Volver al menú
    jp DrawWalletMenu

; DrawSelectScreen: Dibuja la pantalla de selección de wallet
DrawSelectScreen:
    ; Similar a DrawDeleteScreen pero con título diferente
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, SelectTitle
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
    
    jr .showInstructions
    
.hasWallets:
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Mostrar lista de wallets
    ld b, a   ; B = contador de wallets
    ld c, 3   ; C = posición Y inicial
    ld hl, $A000 + WALLET_DATA_OFFSET  ; HL = inicio de datos
    
    ; Resetear índice wallet
    xor a
    ld [WalletIndex], a
    
.listLoop:
    ; Verificar si wallet está activo
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .skipWallet
    
    ; Mostrar índice
    ld a, [WalletIndex]
    add "1"
    ld d, c   ; y
    ld e, 3   ; x
    call PrintAtXY
    
    ; Mostrar nombre
    push bc
    push hl
    
    inc hl   ; Saltar byte de estado
    ld d, c  ; y
    ld e, 5  ; x
    call PrintHLString
    
    pop hl
    pop bc
    
    ; Dibujar cursor si es la selección actual
    ld a, [SelectCursor]
    ld e, a
    ld a, [WalletIndex]
    cp e
    jr nz, .noCursor
    
    ; Dibujar cursor
    ld a, ">"
    ld d, c   ; y
    ld e, 1   ; x
    call PrintAtXY
    
.noCursor:
    ; Siguiente posición Y
    inc c
    
    ; Incrementar índice
    ld a, [WalletIndex]
    inc a
    ld [WalletIndex], a
    
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
    
.showInstructions:
    ; Instrucciones
    ld hl, SelectInstr
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ret

; SelectWallet: Establece el wallet seleccionado como actual
SelectWallet:
    push af
    push bc
    push de
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Buscar wallet por índice
    ld hl, $A000 + WALLET_DATA_OFFSET
    ld b, 0  ; contador
    
.findLoop:
    ; Verificar si wallet está activo
    ld a, [hl]
    cp WALLET_ACTIVE
    jr nz, .skipWallet
    
    ; Verificar si es el índice buscado
    ld a, b
    ld e, [SelectCursor]
    cp e
    jr z, .foundWallet
    
    ; Incrementar índice
    inc b
    
.skipWallet:
    ; Avanzar al siguiente wallet
    ld de, WALLET_DATA_LEN
    add hl, de
    
    ; Verificar límite
    ld a, b
    cp MAX_WALLETS
    jr c, .findLoop
    
    ; Si llegamos aquí, no se encontró el wallet
    jr .done
    
.foundWallet:
    ; Guardar puntero a wallet
    ld a, l
    ld [CurrentWalletPtr], a
    ld a, h
    ld [CurrentWalletPtr+1], a
    
    ; Copiar nombre a buffer actual
    inc hl  ; Saltar byte de estado
    ld de, CurrentWalletName
    
.copyLoop:
    ld a, [hl+]
    ld [de], a
    inc de
    
    ; Verificar terminador
    or a
    jr nz, .copyLoop
    
    ; Copiar dirección a buffer actual
    ld de, CurrentWalletAddr
    
.copyAddrLoop:
    ld a, [hl+]
    ld [de], a
    inc de
    
    ; Verificar terminador
    or a
    jr nz, .copyAddrLoop
    
.done:
    ; Desactivar SRAM
    xor a
    ld [$0000], a
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; GetWalletCount: Obtiene el número de wallets
; Salida: A = número de wallets
GetWalletCount:
    push hl
    
    ; Habilitar SRAM
    ld a, CART_SRAM_ENABLE
    ld [$0000], a
    
    ; Leer contador
    ld hl, $A000 + WALLET_COUNT_OFFSET
    ld a, [hl]
    
    ; Desactivar SRAM
    xor a
    ld [$0000], a
    
    ; Restaurar contador a A
    ld a, [JoyState+1]  ; Valor temporal
    
    pop hl
    ret

; ShowNumberAtXY: Muestra un número en la pantalla
; Entrada: A = número, D = y, E = x
ShowNumberAtXY:
    push af
    
    ; Convertir a ASCII
    add "0"
    
    ; Mostrar
    call PrintAtXY
    
    pop af
    ret

; ShowWalletFullError: Muestra mensaje de error por wallet lleno
ShowWalletFullError:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, ErrorTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Mostrar mensaje de error
    ld hl, WalletFullMsg
    ld d, 6   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Instrucciones
    ld hl, BackMsg
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Esperar tecla
    call WaitButton
    
    ret

; ShowNoWalletsError: Muestra mensaje de error por no haber wallets
ShowNoWalletsError:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, ErrorTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Mostrar mensaje de error
    ld hl, NoWalletsMsg
    ld d, 6   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Instrucciones
    ld hl, BackMsg
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Esperar tecla
    call WaitButton
    
    ret

; ShowInvalidDataError: Muestra mensaje de error por datos inválidos
ShowInvalidDataError:
    ; Mostrar mensaje de error en línea de estado
    ld hl, InvalidDataMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de error
    call PlayBeepError
    
    ; Esperar un momento
    ld bc, 30
.wait:
    call WaitVBlank
    dec bc
    ld a, b
    or c
    jr nz, .wait
    
    ret

; ShowWalletSavedMsg: Muestra mensaje de éxito al guardar wallet
ShowWalletSavedMsg:
    ; Limpiar área de mensaje
    ld d, 12  ; y
    ld e, 2   ; x
    ld b, 16  ; longitud
    call ClearLine
    
    ; Mostrar mensaje de éxito
    ld hl, WalletSavedMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de confirmación
    call PlayBeepConfirm
    
    ret

; ShowDeletedMsg: Muestra mensaje de éxito al eliminar wallet
ShowDeletedMsg:
    ; Mostrar mensaje de éxito
    ld hl, WalletDeletedMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de confirmación
    call PlayBeepConfirm
    
    ret

; ShowSelectedMsg: Muestra mensaje de éxito al seleccionar wallet
ShowSelectedMsg:
    ; Mostrar mensaje de éxito
    ld hl, WalletSelectedMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de confirmación
    call PlayBeepConfirm
    
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
    and %11110000   ; Máscara para botones A, B, Select, Start
    jr z, .wait
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ret

; --- Variables en WRAM ---
SECTION "SRAMVars", WRAM0[$CB00]
WalletMenuCursor:      DS 1  ; Cursor en menú de wallets
WalletNameBuffer:      DS WALLET_NAME_LEN  ; Buffer para nombre de wallet
WalletAddrBuffer:      DS WALLET_ADDR_LEN  ; Buffer para dirección de wallet
InputField:            DS 1  ; Campo actual (0=nombre, 1=dirección)
InputChar:             DS 1  ; Índice de caracter actual
InputPos:              DS 1  ; Posición actual en el campo
DeleteCursor:          DS 1  ; Cursor en pantalla de eliminación
SelectCursor:          DS 1  ; Cursor en pantalla de selección
WalletIndex:           DS 1  ; Índice temporal para recorrer wallets
CurrentWalletPtr:      DS 2  ; Puntero a wallet actual en SRAM
CurrentWalletName:     DS WALLET_NAME_LEN  ; Nombre de wallet actual
CurrentWalletAddr:     DS WALLET_ADDR_LEN  ; Dirección de wallet actual

; --- Datos y Mensajes ---
SECTION "SRAMData", ROM1
WalletTitle:         DB "GESTIONAR WALLETS", 0
WalletOptList:       DB "Listar wallets", 0
WalletOptCreate:     DB "Crear wallet", 0
WalletOptDelete:     DB "Eliminar wallet", 0
WalletOptSelect:     DB "Seleccionar wallet", 0
WalletCountMsg:      DB "Wallets: ", 0
WalletCurrentMsg:    DB "Actual: ", 0
WalletInstructions:  DB "A:Sel B:Volver", 0
WalletListTitle:     DB "LISTA DE WALLETS", 0
WalletEmptyMsg:      DB "No hay wallets", 0
BackMsg:             DB "B: Volver", 0
CreateTitle:         DB "CREAR WALLET", 0
NameLabel:           DB "Nombre:", 0
AddrLabel:           DB "Direccion:", 0
CharLabel:           DB "Caracter:", 0
FieldLabel:          DB "Campo:", 0
NameValue:           DB "NOMBRE", 0
AddrValue:           DB "DIRECCION", 0
CreateInstr1:        DB "A:Add Sel:Campo", 0
CreateInstr2:        DB "Start:Guardar B:Cancel", 0
DeleteTitle:         DB "ELIMINAR WALLET", 0
DeleteInstr:         DB "A:Selec. B:Volver", 0
DeleteConfirmMsg:    DB "Confirmar borrado?", 0
DeleteConfirmInstr:  DB "A:Si B:No", 0
SelectTitle:         DB "SELECCIONAR WALLET", 0
SelectInstr:         DB "A:Selec. B:Volver", 0
ErrorTitle:          DB "ERROR", 0
WalletFullMsg:       DB "Limite alcanzado", 0
NoWalletsMsg:        DB "No hay wallets", 0
InvalidDataMsg:      DB "Datos incompletos", 0
WalletSavedMsg:      DB "Wallet guardado!", 0
WalletDeletedMsg:    DB "Wallet eliminado!", 0
WalletSelectedMsg:   DB "Wallet seleccionado!", 0

; Juego de caracteres para entrada
Charset: DB "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
CharsetLen: EQU $-Charset; sram.asm - Módulo de gestión de SRAM para múltiples wallets
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
    ld a, 0
    ld [hl], a
    
    ld hl, WalletAddrBuffer
    ld a, 0
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
    ld c, [InputPos]
    ld b, 0
    add hl, bc
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
    ld c, [InputPos]
    ld b, 0
    add hl, bc
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
    
    ld a, [InputPos]
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
    
    ld a, [InputPos]
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
    
    ; Copiar nombre
    ld de, WalletNameBuffer
    
.copyNameLoop:
    ld a, [de]
    ld [hl+], a
    inc de
    
    ; Verificar terminador
    or a
    jr nz, .copyNameLoop
    
    ; Rellenar resto con 0 hasta WALLET_NAME_LEN
    ld a, l
    sub low($A000 + WALLET_DATA_OFFSET + 1)  ; Calcular bytes escritos
    ld c, a
    ld a, WALLET_NAME_LEN
    sub c        ; Calcular bytes restantes
    jr c, .nameDone
    jr z, .nameDone
    
    ld b, a     ; B = contador
    
.padNameLoop:
    xor a
    ld [hl+], a
    dec b
    jr nz, .padNameLoop
    
.nameDone:
    ; Copiar dirección
    ld de, WalletAddrBuffer
    
.copyAddrLoop:
    ld a, [de]
    ld [hl+], a
    inc de
    
    ; Verificar terminador
    or a
    jr nz, .copyAddrLoop
    
    ; Rellenar resto con 0 hasta WALLET_ADDR_LEN
    ld a, l
    sub low($A000 + WALLET_DATA_OFFSET + 1 + WALLET_NAME_LEN)  ; Calcular bytes escritos
    ld c, a
    ld a, WALLET_ADDR_LEN
    sub c        ; Calcular bytes restantes
    jr c, .addrDone
    jr z, .addrDone
    
    ld b, a     ; B = contador
    
.padAddrLoop:
    xor a
    ld [hl+], a
    dec b
    jr nz, .padAddrLoop
    
.addrDone:
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

; DoDeleteWallet: Elimina un wallet
DoDeleteWallet:
    ; Verificar si hay wallets
    call GetWalletCount
    or a
    jr nz, .hasWallets
    
    ; No hay wallets, mostrar error
    call ShowNoWalletsError
    
    ; Volver al menú
    jp DrawWalletMenu
    
.hasWallets:
    ; Mostrar pantalla de selección para eliminar
    call DrawDeleteScreen
    
    ; Inicializar cursor
    xor a
    ld [DeleteCursor], a
    
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
    bit PADB_UP, a
    jr nz, .moveUp
    
    bit PADB_DOWN, a
    jr nz, .moveDown
    
    bit PADB_A, a
    jr nz, .selectDelete
    
    bit PADB_B, a
    jr nz, .cancel
    
    jr .inputLoop
    
.moveUp:
    ld a, [DeleteCursor]
    or a
    jr z, .wrapDown  ; Si estamos en 0, ir al último
    
    ; Decrementar cursor
    dec a
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.wrapDown:
    ; Obtener número de wallets
    call GetWalletCount
    dec a  ; 0-indexado
    
    ; Guardar como cursor
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.moveDown:
    ; Obtener número de wallets
    call GetWalletCount
    dec a  ; 0-indexado
    
    ; Comparar con cursor actual
    ld b, a
    ld a, [DeleteCursor]
    cp b
    jr z, .wrapUp  ; Si estamos en el último, ir al primero
    
    ; Incrementar cursor
    inc a
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.wrapUp:
    ; Ir a la primera opción
    xor a
    ld [DeleteCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawDeleteScreen
    
    jr .inputLoop
    
.selectDelete:
    ; Pedir confirmación
    call DrawDeleteConfirm
    
    ; Esperar respuesta
.confirmLoop:
    ; Leer input
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .confirmLoop
    
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    
    ; Verificar botones
    bit PADB_A, a
    jr nz, .confirmDelete
    
    bit PADB_B, a
    jr nz, .cancelDelete
    
    jr .confirmLoop
    
.confirmDelete:
    ; Eliminar wallet
    call DeleteWallet
    
    ; Mostrar; sram.asm - Módulo de gestión de SRAM para múltiples wallets
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
    ld a, 0
    ld [hl], a
    
    ld hl, WalletAddrBuffer
    ld a, 0
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
    ld c, [InputPos]
    ld b, 0
    add hl, bc
    ld [hl], a
    
    ; Añadir terminador
    inc hl
    ld [hl], 0
    
    ; Incrementar posición
    ld a, [Input