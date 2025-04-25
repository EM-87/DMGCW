; sram.asm - Módulo de gestión de SRAM para múltiples wallets
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

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

; Constantes para modos de lista
DELETE_MODE     EQU 0    ; Modo lista para eliminar wallet
SELECT_MODE     EQU 1    ; Modo lista para seleccionar wallet

; Constantes para resultados de selección
LIST_RESULT_CANCELED   EQU 0    ; Operación cancelada
LIST_RESULT_SELECTED   EQU 1    ; Item seleccionado

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
    
    ; Mostrar contador de wallets (usando API)
    call SRAM_GetWalletCount
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
    call SRAM_GetWalletCount
    
    ; Si no hay wallets, mostrar mensaje
    or a
    jr nz, .hasWallets
    
    ld hl, WalletEmptyMsg
    ld d, 8   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    jr .waitKey
    
.hasWallets:
    ; Mostrar lista de wallets
    ld b, a   ; B = número total de wallets
    xor a
    ld [ListIndex], a  ; Inicializar índice
    ld c, 3   ; C = posición Y inicial
    
.listLoop:
    ; Cargar wallet por índice
    push bc
    ld a, [ListIndex]
    call SRAM_LoadWallet
    pop bc
    
    ; Verificar si se cargó correctamente
    or a
    jr nz, .skipWallet
    
    ; Mostrar índice
    ld a, [ListIndex]
    inc a      ; Mostrar como 1-based
    add "0"    ; Convertir a ASCII
    ld d, c    ; y
    ld e, 2    ; x
    call PrintAtXY
    
    ; Mostrar nombre
    ld hl, WALLET_NAME
    ld d, c    ; y
    ld e, 4    ; x
    call PrintStringAtXY
    
    ; Siguiente posición Y
    inc c
    
.skipWallet:
    ; Incrementar índice
    ld a, [ListIndex]
    inc a
    ld [ListIndex], a
    
    ; Verificar si hemos procesado todos los wallets
    cp b
    jr c, .listLoop
    
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

; DoCreateWallet: Crea un nuevo wallet
DoCreateWallet:
    ; Verificar si hay espacio
    call SRAM_GetWalletCount
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
    
    ; Copiar datos a buffers de API
    ld hl, WalletNameBuffer
    ld de, WALLET_NAME
    ld bc, WALLET_NAME_LEN
    call CopyMemory
    
    ld hl, WalletAddrBuffer
    ld de, WALLET_ADDR
    ld bc, WALLET_ADDR_LEN
    call CopyMemory
    
    ; Guardar wallet usando API
    call SRAM_CreateWallet
    
    ; Verificar resultado
    or a
    jr nz, .saveError
    
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
    
.saveError:
    ; Mostrar error al guardar
    call ShowWalletSaveError
    call WaitButton
    jp DrawWalletMenu

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

; DoDeleteWallet: Elimina un wallet
DoDeleteWallet:
    ; Verificar si hay wallets
    call SRAM_GetWalletCount
    or a
    jr nz, .hasWallets
    
    ; No hay wallets, mostrar error
    call ShowNoWalletsError
    
    ; Volver al menú
    jp DrawWalletMenu
    
.hasWallets:
    ; Mostrar pantalla de selección para eliminar
    call DrawSelectListScreen
    ld a, DELETE_MODE
    ld [ListMode], a
    
    ; Esperar selección
    call HandleListSelection
    
    ; Verificar resultado
    ld a, [ListResult]
    cp LIST_RESULT_SELECTED
    jr nz, .returnToMenu  ; Si no se seleccionó (canceló)
    
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
    jr nz, .returnToMenu
    
    jr .confirmLoop
    
.confirmDelete:
    ; Eliminar wallet usando API
    ld a, [ListCursor]
    call SRAM_DeleteWallet
    
    ; Verificar resultado
    or a
    jr nz, .deleteError
    
    ; Mostrar mensaje de éxito
    call ShowDeletedMsg
    
    ; Esperar tecla
    call WaitButton
    
.returnToMenu:
    ; Volver al menú
    jp DrawWalletMenu
    
.deleteError:
    ; Mostrar error al eliminar
    call ShowWalletDeleteError
    call WaitButton
    jp DrawWalletMenu

; DrawSelectListScreen: Pantalla genérica para seleccionar de la lista
DrawSelectListScreen:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Determinar título según modo
    ld a, [ListMode]
    or a
    jr nz, .selectTitle
    
    ; Título para eliminar
    ld hl, DeleteTitle
    jr .drawTitle
    
.selectTitle:
    ; Título para seleccionar
    ld hl, SelectTitle
    
.drawTitle:
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Obtener número de wallets
    call SRAM_GetWalletCount
    
    ; Si no hay wallets, mostrar mensaje
    or a
    jr nz, .hasWallets
    
    ld hl, WalletEmptyMsg
    ld d, 8   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    jr .showInstructions
    
.hasWallets:
    ; Mostrar lista de wallets
    ld b, a   ; B = número total de wallets
    xor a
    ld [ListIndex], a  ; Inicializar índice
    ld c, 3   ; C = posición Y inicial
    
.listLoop:
    ; Cargar wallet por índice
    push bc
    ld a, [ListIndex]
    call SRAM_LoadWallet
    pop bc
    
    ; Verificar si se cargó correctamente
    or a
    jr nz, .skipWallet
    
    ; Mostrar índice
    ld a, [ListIndex]
    inc a      ; Mostrar como 1-based
    add "0"    ; Convertir a ASCII
    ld d, c    ; y
    ld e, 3    ; x
    call PrintAtXY
    
    ; Mostrar nombre
    ld hl, WALLET_NAME
    ld d, c    ; y
    ld e, 5    ; x
    call PrintStringAtXY
    
    ; Dibujar cursor si es la selección actual
    ld a, [ListCursor]
    ld e, a
    ld a, [ListIndex]
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
    
.skipWallet:
    ; Incrementar índice
    ld a, [ListIndex]
    inc a
    ld [ListIndex], a
    
    ; Verificar si hemos procesado todos los wallets
    cp b
    jr c, .listLoop
    
.showInstructions:
    ; Determinar instrucciones según modo
    ld a, [ListMode]
    or a
    jr nz, .selectInstr
    
    ; Instrucciones para eliminar
    ld hl, DeleteInstr
    jr .showInstr
    
.selectInstr:
    ; Instrucciones para seleccionar
    ld hl, SelectInstr
    
.showInstr:
    ld d, 14  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ret

; HandleListSelection: Maneja la navegación y selección en una lista
; Utiliza ListCursor y ListIndex
; Establece ListResult con el resultado (0=cancelado, 1=seleccionado)
HandleListSelection:
    ; Inicializar cursor
    xor a
    ld [ListCursor], a
    ld [ListResult], a
    
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
    jr nz, .select
    
    bit PADB_B, a
    jr nz, .cancel
    
    jr .inputLoop
    
.moveUp:
    ld a, [ListCursor]
    or a
    jr z, .wrapDown  ; Si estamos en 0, ir al último
    
    ; Decrementar cursor
    dec a
    ld [ListCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectListScreen
    
    jr .inputLoop
    
.wrapDown:
    ; Obtener número de wallets
    call SRAM_GetWalletCount
    dec a  ; 0-indexado
    
    ; Guardar como cursor
    ld [ListCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectListScreen
    
    jr .inputLoop
    
.moveDown:
    ; Obtener número de wallets
    call SRAM_GetWalletCount
    dec a  ; 0-indexado
    
    ; Comparar con cursor actual
    ld b, a
    ld a, [ListCursor]
    cp b
    jr z, .wrapUp  ; Si estamos en el último, ir al primero
    
    ; Incrementar cursor
    inc a
    ld [ListCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectListScreen
    
    jr .inputLoop
    
.wrapUp:
    ; Ir a la primera opción
    xor a
    ld [ListCursor], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar pantalla
    call DrawSelectListScreen
    
    jr .inputLoop
    
.select:
    ; Reproducir sonido
    call PlayBeepConfirm
    
    ; Marcar como seleccionado
    ld a, LIST_RESULT_SELECTED
    ld [ListResult], a
    ret
    
.cancel:
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Marcar como cancelado
    ld a, LIST_RESULT_CANCELED
    ld [ListResult], a
    ret

; DoSelectWallet: Selecciona un wallet como actual
DoSelectWallet:
    ; Verificar si hay wallets
    call SRAM_GetWalletCount
    or a
    jr nz, .hasWallets
    
    ; No hay wallets, mostrar error
    call ShowNoWalletsError
    
    ; Volver al menú
    jp DrawWalletMenu
    
.hasWallets:
    ; Mostrar pantalla de selección utilizando la rutina compartida
    call DrawSelectListScreen
    ld a, SELECT_MODE
    ld [ListMode], a
    
    ; Esperar selección
    call HandleListSelection
    
    ; Verificar resultado
    ld a, [ListResult]
    cp LIST_RESULT_SELECTED
    jr nz, .returnToMenu  ; Si no se seleccionó (canceló)
    
    ; Cargar wallet seleccionado usando API
    ld a, [ListCursor]
    call SRAM_LoadWallet
    
    ; Verificar resultado
    or a
    jr nz, .selectError
    
    ; Copiar datos a buffers actuales
    ld hl, WALLET_NAME
    ld de, CurrentWalletName
    ld bc, WALLET_NAME_LEN
    call CopyMemory
    
    ld hl, WALLET_ADDR
    ld de, CurrentWalletAddr
    ld bc, WALLET_ADDR_LEN
    call CopyMemory
    
    ; Mostrar mensaje de éxito
    call ShowSelectedMsg
    
    ; Esperar tecla
    call WaitButton
    
.returnToMenu:
    ; Volver al menú
    jp DrawWalletMenu
    
.selectError:
    ; Mostrar error al seleccionar
    call ShowWalletSelectError
    call WaitButton
    jp DrawWalletMenu

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

; ShowWalletSaveError: Muestra mensaje de error al guardar wallet
ShowWalletSaveError:
    ; Mostrar mensaje de error
    ld hl, WalletSaveErrorMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de error
    call PlayBeepError
    
    ret

; ShowWalletDeleteError: Muestra mensaje de error al eliminar wallet
ShowWalletDeleteError:
    ; Mostrar mensaje de error
    ld hl, WalletDeleteErrorMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de error
    call PlayBeepError
    
    ret

; ShowWalletSelectError: Muestra mensaje de error al seleccionar wallet
ShowWalletSelectError:
    ; Mostrar mensaje de error
    ld hl, WalletSelectErrorMsg
    ld d, 12  ; y
    ld e, 2   ; x
    call PrintStringAtXY
    
    ; Reproducir sonido de error
    call PlayBeepError
    
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

; Multiply: Multiplica HL por C
; Entrada: HL, C = operandos
; Salida: HL = HL * C
Multiply:
    push bc
    push de
    
    ; Si alguno es cero, resultado es cero
    ld a, h
    or l
    jr z, .zero
    
    ld a, c
    or a
    jr z, .zero
    
    ; Guardar valor original de HL
    ld d, h
    ld e, l
    
    ; Inicializar resultado
    ld hl, 0
    
    ; Multiplicar sumando HL veces C
    ld b, c
    
.loop:
    ; Sumar HL += DE
    add hl, de
    
    ; Decrementar contador
    dec b
    jr nz, .loop
    
.done:
    pop de
    pop bc
    ret
    
.zero:
    ; Resultado es cero
    ld hl, 0
    jr .done

; --- Variables en WRAM ---
SECTION "SRAMVars", WRAM0[$CB00]
WalletMenuCursor:      DS 1  ; Cursor en menú de wallets
WalletNameBuffer:      DS WALLET_NAME_LEN  ; Buffer para nombre de wallet
WalletAddrBuffer:      DS WALLET_ADDR_LEN  ; Buffer para dirección de wallet
InputField:            DS 1  ; Campo actual (0=nombre, 1=dirección)
InputChar:             DS 1  ; Índice de caracter actual
InputPos:              DS 1  ; Posición actual en el campo
ListCursor:            DS 1  ; Cursor en pantalla de lista (eliminar/seleccionar)
ListIndex:             DS 1  ; Índice temporal para recorrer wallets
ListMode:              DS 1  ; Modo de lista (0=eliminar, 1=seleccionar)
ListResult:            DS 1  ; Resultado de selección (0=cancelado, 1=seleccionado)

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
WalletSaveErrorMsg:  DB "Error al guardar", 0
WalletDeleteErrorMsg: DB "Error al eliminar", 0
WalletSelectErrorMsg: DB "Error al seleccionar", 0

; Juego de caracteres para entrada
Charset: DB "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
CharsetLen: EQU $-Charset
