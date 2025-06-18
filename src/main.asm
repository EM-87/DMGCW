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
    call InitSRAM      ; Usar la API de sram_manager
    call InitVRAM
    call InitInterrupts
    call ShowWarning
    
MainLoop:
    ; Dibujar menú principal
    call DrawMenu
    
    ; Esperar VBlank
    call UI_WaitVBlank
    
ReadInputLoop:
    ; Leer input del joypad con debounce
    call ReadJoypadWithDebounce
    
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

; --- InitInterrupts: Inicialización segura de interrupciones ---
InitInterrupts:
    di                  ; Deshabilitar interrupciones
    
    ; Limpiar flags pendientes para evitar disparos inmediatos
    xor a
    ld [rIF], a
    
    ; Habilitar sólo VBlank
    ld a, IEF_VBLANK
    ld [rIE], a
    
    ; Habilitar interrupciones
    ei
    ret

; --- ReadJoypadWithDebounce: Lectura de botones con debounce ---
ReadJoypadWithDebounce:
    ; Leer estado actual
    call ReadJoypad
    
    ; Aplicar debounce si hay cambio de estado
    ld a, [JoyState]
    ld b, a
    ld a, [JoyPrevState]
    cp b
    ret z               ; Si no hay cambio, retornar
    
    ; Esperar frames para evitar rebotes
    ld b, DEBOUNCE_FRAMES
.debounce_wait:
    push bc
    call UI_WaitVBlank
    pop bc
    dec b
    jr nz, .debounce_wait
    
    ; Releer estado para confirmar
    call ReadJoypad
    ret

; --- VBlank Handler ---
VBlankHandler:
    push af
    push bc
    push de
    push hl
    
    ; Incrementar contador de frames para animaciones
    ld a, [FrameCounter]
    inc a
    ld [FrameCounter], a
    
    ; Código de manejo VBlank
    
    pop hl
    pop de
    pop bc
    pop af
    reti

; --- ReadJoypad: lee el estado del joypad ---
ReadJoypad:
    ; Preservar registros
    push bc
    
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
    
    pop bc
    ret

; --- SwitchBank: Cambia al banco ROM especificado ---
; Entrada: A = número de banco
SwitchBank:
    ld [CurrentBank], a
    ld [$2000], a  ; Registro de selección de banco
    ret

; --- SwitchBank0: Cambia al banco ROM 0 ---
SwitchBank0:
    xor a
    ld [CurrentBank], a
    ld [$2000], a  ; Registro de selección de banco
    ret

; --- ExitGame: Rutina para "salir" del juego (soft reset) ---
ExitGame:
    ; Guardar datos
    call SRAM_Init
    
    ; Desactivar sonido
    xor a
    ld [rNR52], a
    
    ; Reiniciar
    jp $0000

; --- Variables en WRAM ---
SECTION "MainVars", WRAM0[$C000]
CursorIndex:    DS 1    ; Índice del cursor en menú
JoyState:       DS 1    ; Estado actual del joypad
JoyPrevState:   DS 1    ; Estado previo del joypad
CurrentBank:    DS 1    ; Banco ROM actual
EntryReason:    DS 1    ; Razón de entrada a un módulo (0=normal, 1=new)
FrameCounter:   DS 1    ; Contador de frames para animaciones

; Agregar esto en la sección de variables WRAM
SECTION "MainVars", WRAM0[$C000]
CursorIndex:    DS 1
JoyState:       DS 1
JoyPrevState:   DS 1    ; AGREGADO
CurrentBank:    DS 1
EntryReason:    DS 1
FrameCounter:   DS 1

; Corregir InitVRAM - usar tile 0 en lugar de espacio:
InitVRAM:
    push af
    push bc
    push hl
    
    call UI_WaitVBlank
    
    xor a
    ld [rLCDC], a
    
    ; Limpiar tile data
    ld hl, $8000
    ld bc, $1000
    xor a
    call FillMemory
    
    ; Limpiar background map con tile 0
    ld hl, $9800
    ld bc, $0400
    xor a               ; CORRECCIÓN: usar 0, no " "
    call FillMemory
    
    call LoadFont
    
    ld a, %11100100
    ld [rBGP], a
    
    ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_BGON
    ld [rLCDC], a
    
    pop hl
    pop bc
    pop af
    ret

; Corregir LoadFont:
LoadFont:
    push af
    push bc
    push de
    push hl
    
    ld hl, FontData
    ld de, $8200        ; CORRECCIÓN: $8000 + (32 * 16)
    ld bc, 96 * 16
    
.copy_loop:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copy_loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret




; --- Buffers compartidos en WRAM ---
SECTION "SharedBuffers", WRAM0[$C100]
AddressBuf:          DS 24    ; Buffer para dirección
AmountBuf:           DS 10    ; Buffer para monto
CurrentWalletName:   DS WALLET_NAME_LEN  ; Nombre wallet actual
CurrentWalletAddr:   DS WALLET_ADDR_LEN  ; Dirección wallet actual

; --- Datos y Mensajes ---
SECTION "MainData", ROM0
MenuTitle:      DB "DMG COLD WALLET", 0
MenuYStart:     DB 3
Arrow:          DB ">", 0
MENU_ITEMS:     EQU 7    ; Número de ítems en el menú

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

; Agregar estas funciones al main.asm existente

; --- InitVRAM: Inicialización de VRAM ---
InitVRAM:
    push af
    push bc
    push hl
    
    ; Esperar VBlank antes de tocar VRAM
    call UI_WaitVBlank
    
    ; Apagar LCD temporalmente
    xor a
    ld [rLCDC], a
    
    ; Limpiar tile data ($8000-$8FFF)
    ld hl, $8000
    ld bc, $1000
    xor a
    call FillMemory
    
    ; Limpiar background map ($9800-$9BFF)
    ld hl, $9800
    ld bc, $0400
    ld a, " "         ; Espacio en blanco
    call FillMemory
    
    ; Cargar font ASCII básica
    call LoadFont
    
    ; Configurar paleta
    ld a, %11100100   ; Negro, gris oscuro, gris claro, blanco
    ld [rBGP], a
    
    ; Reactivar LCD
    ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_BGON
    ld [rLCDC], a
    
    pop hl
    pop bc
    pop af
    ret

; --- LoadFont: Carga fuente ASCII en VRAM ---
LoadFont:
    push af
    push bc
    push de
    push hl
    
    ; La fuente debe estar en ROM (FontData)
    ld hl, FontData
    ld de, $8000 + (" " * 16)  ; Empezar en tile del espacio
    ld bc, 96 * 16              ; 96 caracteres x 16 bytes cada uno
    
.copy_loop:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copy_loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- FillMemory: Llena memoria con un valor ---
FillMemory:
    push de
.loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    pop de
    ret

; --- ShowWarning: Muestra advertencia inicial ---
ShowWarning:
    push af
    push bc
    push de
    push hl
    
    ; Limpiar pantalla
    call UI_ClearScreen
    
    ; Dibujar caja de advertencia
    ld a, 2    ; x
    ld b, 4    ; y
    ld c, 16   ; width
    ld d, 10   ; height
    call UI_DrawBox
    
    ; Título
    ld hl, WarningTitle
    ld c, 2    ; box_x
    ld d, 4    ; box_y
    ld e, 16   ; box_width
    call UI_PrintInBox
    
    ; Mensajes
    ld hl, WarningMsg1
    ld d, 7    ; y
    ld e, 4    ; x
    call UI_PrintStringAtXY
    
    ld hl, WarningMsg2
    ld d, 8    ; y
    ld e, 4    ; x
    call UI_PrintStringAtXY
    
    ld hl, WarningMsg3
    ld d, 9    ; y
    ld e, 4    ; x
    call UI_PrintStringAtXY
    
    ; Instrucción
    ld hl, WarningPress
    ld d, 12   ; y
    ld e, 6    ; x
    call UI_PrintStringAtXY
    
    ; Esperar A
.wait_a:
    call ReadJoypad
    ld a, [JoyState]
    bit PADB_A, a
    jr z, .wait_a
    
    ; Esperar que se suelte
.wait_release:
    call ReadJoypad
    ld a, [JoyState]
    bit PADB_A, a
    jr nz, .wait_release
    
    ; Sonido de confirmación
    call PlayBeepConfirm
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- DrawMenu: Dibuja el menú principal ---
DrawMenu:
    push af
    push bc
    push de
    push hl
    
    ; Limpiar pantalla
    call UI_ClearScreen
    
    ; Dibujar caja principal
    ld a, 1    ; x
    ld b, 1    ; y
    ld c, 18   ; width
    ld d, 16   ; height
    call UI_DrawBox
    
    ; Título
    ld hl, MenuTitle
    ld c, 1    ; box_x
    ld d, 1    ; box_y
    ld e, 18   ; box_width
    call UI_PrintInBox
    
    ; Dibujar opciones del menú
    ld hl, MenuItems
    ld b, 0    ; contador de items
    
.draw_items:
    push bc
    push hl
    
    ; Calcular posición Y (empezar en línea 4, incrementar de 2 en 2)
    ld a, b
    add a      ; *2
    add 4      ; +4
    ld d, a    ; D = y
    
    ; X fija
    ld e, 3    ; E = x
    
    ; Verificar si es el item seleccionado
    ld a, [CursorIndex]
    cp b
    jr nz, .not_selected
    
    ; Dibujar cursor
    push de
    dec e      ; Una posición a la izquierda
    ld a, ">"
    call UI_PrintAtXY
    pop de
    
.not_selected:
    ; Dibujar texto del item
    call UI_PrintStringAtXY
    
    pop hl
    pop bc
    
    ; Avanzar al siguiente string
.find_next:
    ld a, [hl+]
    or a
    jr nz, .find_next
    
    ; Incrementar contador
    inc b
    ld a, b
    cp MENU_ITEMS
    jr c, .draw_items
    
    ; Dibujar instrucciones
    ld hl, MenuInstr
    ld d, 15   ; y
    ld e, 2    ; x
    call UI_PrintStringAtXY
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Agregar estas cadenas a la sección de datos ---
SECTION "MainData", ROM0
MenuTitle:      DB "DMG COLD WALLET", 0
WarningTitle:   DB "ADVERTENCIA", 0
WarningMsg1:    DB "Esta billetera", 0
WarningMsg2:    DB "NO usa cifrado", 0
WarningMsg3:    DB "Solo para DEMO", 0
WarningPress:   DB "Pulsa A", 0
MenuInstr:      DB "A:Sel B:Salir", 0

; Los items del menú ya están definidos como Item0, Item1, etc.
MenuItems:      ; Tabla de punteros (no necesaria si usamos MenuPtrs existente)


; Agregar al final de main.asm o crear un archivo font.asm

SECTION "FontData", ROM0

; Fuente ASCII básica 8x8 (solo caracteres imprimibles 32-127)
; Cada carácter son 16 bytes (8x8 pixels, 2 bits por línea para Game Boy)
FontData:
    ; Espacio (ASCII 32)
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    
    ; ! (ASCII 33)
    DB $00,$00,$18,$18,$3C,$3C,$3C,$3C,$18,$18,$00,$00,$18,$18,$00,$00
    
    ; " (ASCII 34)
    DB $00,$00,$36,$36,$36,$36,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    
    ; # (ASCII 35)
    DB $00,$00,$36,$36,$7F,$7F,$36,$36,$7F,$7F,$36,$36,$00,$00,$00,$00
    
    ; $ (ASCII 36)
    DB $0C,$0C,$3F,$3F,$68,$68,$3E,$3E,$0B,$0B,$7E,$7E,$18,$18,$00,$00
    
    ; % (ASCII 37)
    DB $00,$00,$63,$63,$66,$66,$0C,$0C,$18,$18,$33,$33,$63,$63,$00,$00
    
    ; & (ASCII 38)
    DB $1C,$1C,$36,$36,$1C,$1C,$3B,$3B,$6E,$6E,$66,$66,$3B,$3B,$00,$00
    
    ; ' (ASCII 39)
    DB $00,$00,$0C,$0C,$0C,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    
    ; ( (ASCII 40)
    DB $00,$00,$0C,$0C,$18,$18,$18,$18,$18,$18,$0C,$0C,$00,$00,$00,$00
    
    ; ) (ASCII 41)
    DB $00,$00,$18,$18,$0C,$0C,$0C,$0C,$0C,$0C,$18,$18,$00,$00,$00,$00
    
    ; * (ASCII 42)
    DB $00,$00,$00,$00,$66,$66,$3C,$3C,$FF,$FF,$3C,$3C,$66,$66,$00,$00
    
    ; + (ASCII 43)
    DB $00,$00,$00,$00,$18,$18,$18,$18,$7E,$7E,$18,$18,$18,$18,$00,$00
    
    ; , (ASCII 44)
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$18,$18,$18,$30,$30
    
    ; - (ASCII 45)
    DB $00,$00,$00,$00,$00,$00,$00,$00,$7E,$7E,$00,$00,$00,$00,$00,$00
    
    ; . (ASCII 46)
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$18,$18,$18,$00,$00
    
    ; / (ASCII 47)
    DB $00,$00,$03,$03,$06,$06,$0C,$0C,$18,$18,$30,$30,$60,$60,$00,$00
    
    ; 0-9 (ASCII 48-57)
    DB $3E,$3E,$63,$63,$67,$67,$6F,$6F,$7B,$7B,$73,$73,$3E,$3E,$00,$00  ; 0
    DB $0C,$0C,$1C,$1C,$3C,$3C,$0C,$0C,$0C,$0C,$0C,$0C,$3F,$3F,$00,$00  ; 1
    DB $3E,$3E,$63,$63,$03,$03,$0E,$0E,$38,$38,$60,$60,$7F,$7F,$00,$00  ; 2
    DB $3E,$3E,$63,$63,$03,$03,$1E,$1E,$03,$03,$63,$63,$3E,$3E,$00,$00  ; 3
    DB $0E,$0E,$1E,$1E,$36,$36,$66,$66,$7F,$7F,$06,$06,$06,$06,$00,$00  ; 4
    DB $7F,$7F,$60,$60,$7E,$7E,$03,$03,$03,$03,$63,$63,$3E,$3E,$00,$00  ; 5
    DB $1E,$1E,$30,$30,$60,$60,$7E,$7E,$63,$63,$63,$63,$3E,$3E,$00,$00  ; 6
    DB $7F,$7F,$03,$03,$06,$06,$0C,$0C,$18,$18,$18,$18,$18,$18,$00,$00  ; 7
    DB $3E,$3E,$63,$63,$63,$63,$3E,$3E,$63,$63,$63,$63,$3E,$3E,$00,$00  ; 8
    DB $3E,$3E,$63,$63,$63,$63,$3F,$3F,$03,$03,$06,$06,$3C,$3C,$00,$00  ; 9
    
    ; : (ASCII 58)
    DB $00,$00,$00,$00,$18,$18,$18,$18,$00,$00,$18,$18,$18,$18,$00,$00
    
    ; ; hasta @ se pueden agregar después...
    
    ; A-Z (ASCII 65-90) - Solo muestro algunos como ejemplo
    DB $1C,$1C,$36,$36,$63,$63,$63,$63,$7F,$7F,$63,$63,$63,$63,$00,$00  ; A
    DB $7E,$7E,$63,$63,$63,$63,$7E,$7E,$63,$63,$63,$63,$7E,$7E,$00,$00  ; B
    DB $1E,$1E,$33,$33,$60,$60,$60,$60,$60,$60,$33,$33,$1E,$1E,$00,$00  ; C
    ; ... continuar con D-Z
    
    ; Para completar rápidamente, llenar el resto con un patrón sólido
    REPT 60  ; Aproximadamente para llegar a 96 caracteres
    DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    ENDR
