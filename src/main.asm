; main.asm - Módulo principal con UI y sistema de banking
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

; --- Interrupciones ---
SECTION "Reset", ROM0[$0000]
    jp Start

SECTION "VBlank", ROM0[$0040]
    jp VBlankHandler

SECTION "LCDStat", ROM0[$0048]
    reti

SECTION "Timer", ROM0[$0050]
    reti

SECTION "Serial", ROM0[$0058]
    reti

SECTION "Joypad", ROM0[$0060]
    reti

; --- Código Principal ---
SECTION "MainCode", ROM0[$0150]
Start:
    di                  ; Deshabilitar interrupciones
    
    ; Inicializar stack
    ld sp, $FFFE
    
    ; Inicializar variables
    xor a
    ld [CursorIndex], a
    ld [JoyState], a
    ld [JoyPrevState], a
    ld [EntryReason], a
    
    ; Inicializar subsistemas
    call InitSound
    call SRAM_Init      ; Usar la API de sram_manager
    call InitVRAM
    call ShowWarning
    
    ; Habilitar interrupciones VBlank
    ld a, IEF_VBLANK
    ld [rIE], a
    ei
    
MainLoop:
    ; Dibujar menú principal
    call DrawMenu
    
    ; Esperar VBlank
    call UI_WaitVBlank
    
ReadInputLoop:
    ; Leer input del joypad
    call ReadJoypad
    
    ; Verificar si hay cambios
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, ReadInputLoop  ; Si no hay cambios, seguir esperando
    
    ; Actualizar estado previo
    ld a, [JoyState]
    ld [JoyPrevState], a
    
    ; Comprobar botones
    bit BUTTON_UP_BIT, a
    jr nz, .moveUp
    
    bit BUTTON_DOWN_BIT, a
    jr nz, .moveDown
    
    bit BUTTON_A_BIT, a
    jr nz, .selectItem
    
    ; Si no se presionó ningún botón, seguir leyendo
    jr ReadInputLoop
    
.moveUp:
    ; Mover cursor hacia arriba
    ld a, [CursorIndex]
    cp 0                 ; Si ya estamos en el primer ítem
    jr z, ReadInputLoop  ; No hacer nada
    
    ; Decrementar cursor
    dec a
    ld [CursorIndex], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar menú
    jp MainLoop
    
.moveDown:
    ; Mover cursor hacia abajo
    ld a, [CursorIndex]
    cp MENU_ITEMS - 1    ; Si ya estamos en el último ítem
    jr z, ReadInputLoop  ; No hacer nada
    
    ; Incrementar cursor
    inc a
    ld [CursorIndex], a
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Redibujar menú
    jp MainLoop
    
.selectItem:
    ; Reproducir sonido de selección
    call PlayBeepConfirm
    
    ; Seleccionar ítem según posición del cursor
    ld a, [CursorIndex]
    
    ; Indicar razón de entrada (nuevo)
    ld a, ENTRY_NEW
    ld [EntryReason], a
    
    ; Obtener puntero de salto según cursor
    ld a, [CursorIndex]
    
    ; Cambiar al banco correspondiente (1)
    ld a, 1
    call SwitchBank
    
    ; Obtener dirección de salto
    ld a, [CursorIndex]
    ld hl, EntryPoints
    ld c, a
    ld b, 0
    add hl, bc
    add hl, bc  ; HL += A*2 (cada puntero es de 2 bytes)
    
    ; Obtener dirección en DE
    ld e, [hl]
    inc hl
    ld d, [hl]
    
    ; Saltar a la rutina
    push de
    ret         ; Saltar a DE (pop PC)

; --- VBlank Handler ---
VBlankHandler:
    push af
    push bc
    push de
    push hl
    
    ; Código de manejo VBlank
    
    pop hl
    pop de
    pop bc
    pop af
    reti

; --- Rutinas de UI ---
; Ahora delegamos a lib/ui.asm

; DrawMenu: Dibuja el menú principal con ítems y cursor
DrawMenu:
    ; Limpiar pantalla
    call UI_ClearScreen
    
    ; Dibujar caja para el menú
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call UI_DrawBox
    
    ; Dibujar título
    ld hl, MenuTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call UI_PrintInBox
    
    ; Dibujar ítems de menú
    ld b, 0   ; Contador de ítems
    ld c, [MenuYStart]  ; Posición Y inicial
    
.menuLoop:
    ; Verificar si hemos terminado
    ld a, b
    cp MENU_ITEMS
    jr z, .done
    
    ; Obtener puntero a cadena del ítem
    ld hl, MenuPtrs
    ld e, a
    ld d, 0
    add hl, de
    add hl, de  ; HL += A*2 (punteros de 2 bytes)
    
    ; Obtener puntero en DE
    ld e, [hl]
    inc hl
    ld d, [hl]
    
    ; Mover DE (puntero a cadena) a HL
    push de
    pop hl
    
    ; Imprimir ítem
    ld d, c   ; Y = contador + yStart
    ld e, 4   ; X = 4 (indentado)
    call UI_PrintStringAtXY
    
    ; Verificar si este es el ítem seleccionado
    ld a, [CursorIndex]
    cp b
    jr nz, .nextItem
    
    ; Dibujar cursor de selección
    ld a, [Arrow]
    ld d, c   ; Y = mismo que el ítem
    ld e, 2   ; X = 2 (antes del ítem)
    call UI_PrintAtXY
    
.nextItem:
    ; Incrementar contadores
    inc b     ; Siguiente ítem
    inc c     ; Siguiente línea
    jr .menuLoop
    
.done:
    ; Dibujar mensaje de advertencia
    ld hl, WarningMsg
    ld d, 14  ; Y = línea inferior
    ld e, 2   ; X = 2
    call UI_PrintStringAtXY
    
    ret

; ReadJoypad: Lee el estado del joypad
; Salida: JoyState actualizado (bit=1 si pulsado)
ReadJoypad:
    ; Leer cruceta
    ld a, P1F_GET_DPAD
    ld [rP1], a
    
    ; Leer varias veces para estabilizar
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    
    ; Guardar solo los 4 bits bajos
    and $0F
    
    ; Invertir porque Game Boy usa lógica inversa (0=pulsado)
    cpl
    and $0F
    
    ; Guardar en los 4 bits altos de B
    swap a
    ld b, a
    
    ; Leer botones
    ld a, P1F_GET_BTN
    ld [rP1], a
    
    ; Leer varias veces para estabilizar
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    
    ; Guardar solo los 4 bits bajos
    and $0F
    
    ; Invertir
    cpl
    and $0F
    
    ; Combinar con bits de la cruceta
    or b
    
    ; Guardar estado
    ld [JoyState], a
    
    ; Restablecer P1
    ld a, P1F_GET_NONE
    ld [rP1], a
    
    ret

; InitVRAM: Inicializa VRAM y configura LCD
InitVRAM:
    ; Esperar VBlank
    call UI_WaitVBlank
    
    ; Apagar LCD para acceder a VRAM
    xor a
    ld [rLCDC], a
    
    ; Inicializar paleta
    ld a, %11100100  ; Negro, oscuro, claro, blanco
    ld [rBGP], a
    
    ; Limpiar VRAM
    ld hl, $8000
    ld bc, $2000
    xor a
    
.clearVRAM:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .clearVRAM
    
    ; Cargar fuente básica (omitido por brevedad)
    ; ...
    
    ; Activar LCD con flags
    ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_BGON
    ld [rLCDC], a
    
    ret

; ShowWarning: Muestra advertencia de seguridad
ShowWarning:
    ; Limpiar pantalla
    call UI_ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call UI_DrawBox
    
    ; Mostrar título de advertencia
    ld hl, WarningTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call UI_PrintInBox
    
    ; Mostrar mensaje de advertencia
    ld hl, WarningMsg1
    ld d, 5   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, WarningMsg2
    ld d, 7   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, WarningMsg3
    ld d, 9   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar mensaje para continuar
    ld hl, WarningPress
    ld d, 14  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Esperar botón A
    ld a, [JoyState]
    ld [JoyPrevState], a
    
.waitPress:
    call ReadJoypad
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    jr z, .waitPress
    
    ; Verificar si se presionó A
    ld a, [JoyState]
    bit BUTTON_A_BIT, a
    jr z, .waitPress
    
    ; Actualizar estado previo
    ld a, [JoyState]
    ld [JoyPrevState], a
    
    ; Reproducir sonido
    call PlayBeepConfirm
    
    ret

; SwitchBank: Cambia al banco ROM especificado
; Entrada: A = número de banco
SwitchBank:
    ld [CurrentBank], a
    ld [$2000], a  ; Registro de selección de banco
    ret

; SwitchBank0: Cambia al banco ROM 0
SwitchBank0:
    xor a
    ld [CurrentBank], a
    ld [$2000], a  ; Registro de selección de banco
    ret

; ExitGame: Rutina para "salir" del juego (soft reset)
ExitGame:
    ; Guardar datos
    call SRAM_Init
    
    ; Desactivar sonido
    xor a
    ld [rNR52], a
    
    ; Reiniciar
    jp $0000

; --- Variables en WRAM ---
SECTION "WramVars", WRAM0[$C000]
CursorIndex:    DS 1    ; Índice del cursor en menú
JoyState:       DS 1    ; Estado actual del joypad
JoyPrevState:   DS 1    ; Estado previo del joypad
CurrentBank:    DS 1    ; Banco ROM actual
EntryReason:    DS 1    ; Razón de entrada a un módulo (0=normal, 1=new)

; --- Datos y Mensajes ---
SECTION "MainData", ROM0
MenuTitle:      DB "DMG COLD WALLET", 0
MenuYStart:     DB 3
Arrow:          DB ">", 0

MenuPtrs:
    DW Item0
    DW Item1
    DW Item2
    DW Item3
    DW Item4
    DW Item5
    DW Item6

WarningTitle:   DB "ADVERTENCIA", 0
WarningMsg:     DB "SIN CIFRADO", 0
WarningMsg1:    DB "Esta billetera", 0
WarningMsg2:    DB "NO usa cifrado", 0
WarningMsg3:    DB "Solo para DEMO", 0
WarningPress:   DB "Pulsa A", 0

SECTION "Strings", ROM0
Item0:          DB "Nuevo TX", 0
Item1:          DB "Confirmar", 0
Item2:          DB "Gestionar W", 0
Item3:          DB "Enviar Link", 0
Item4:          DB "Mostrar QR", 0
Item5:          DB "Imprimir QR", 0
Item6:          DB "Salir", 0

; --- Puntos de entrada a otros módulos ---
SECTION "EntryPoints", ROM0
EntryPoints:
    DW Entry_Input
    DW Entry_Confirm
    DW Entry_SRAM
    DW Entry_LinkTest
    DW Entry_QR_Gen
    DW Entry_Printer
    DW ExitGame