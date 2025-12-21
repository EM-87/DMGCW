; ====================================================================
; File: src/main.asm - Módulo Principal (Refactorizado)
; ====================================================================

; --- Inclusiones y Declaraciones Externas ---
INCLUDE "hardware.inc"
INCLUDE "constants.inc"

; --- Declaración de funciones externas ---

; ====================================================================
; Vectores de Interrupción y Entry Point
; ====================================================================
SECTION "Reset", ROM0[$0000]
    jp Start

SECTION "VBlank", ROM0[$0040]
    jp VBlankHandler

; ... (otras interrupciones sin cambios) ...
SECTION "LCDStat", ROM0[$0048]
    reti
SECTION "Timer", ROM0[$0050]
    reti
SECTION "Serial", ROM0[$0058]
    reti
SECTION "Joypad", ROM0[$0060]
    reti

; ====================================================================
; Código Principal
; ====================================================================
SECTION "MainCode", ROM0[$0150]

Start:
    di
    ld sp, $DFFF
    call InitGlobalVars
    call InitSubsystems
    call ShowWarning

MainLoop:
    call DrawMenu
    call WaitVBlank
.read_input_loop:
    call ReadJoypadWithDebounce
    ld a, [JoyState]
    bit BUTTON_UP_BIT, a
    jr nz, .move_up
    bit BUTTON_DOWN_BIT, a
    jr nz, .move_down
    bit BUTTON_A_BIT, a
    jr nz, .select_item
    jr .read_input_loop

.move_up:
    ld a, [CursorIndex]
    or a
    jr z, .read_input_loop
    dec a
    ld [CursorIndex], a
    call PlayBeepNav
    jp MainLoop
.move_down:
    ld a, [CursorIndex]
    cp MENU_ITEMS - 1
    jr z, .read_input_loop
    inc a
    ld [CursorIndex], a
    call PlayBeepNav
    jp MainLoop

.select_item:
    call PlayBeepConfirm
    ld a, ENTRY_NEW
    ld [EntryReason], a
    ld a, 1
    call SwitchBank
    ld a, [CursorIndex]
    ld c, a
    ld b, 0
    ld hl, EntryPoints
    add hl, bc
    add hl, bc
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de
    ret

; --- Rutinas de Inicialización ---
InitGlobalVars:
    xor a
    ld [CursorIndex], a
    ld [JoyState], a
    ld [JoyPrevState], a
    ld [EntryReason], a
    ret

InitSubsystems:
    call InitSound
    call SRAM_Init
    call InitVRAM
    call InitInterrupts
    ret

InitInterrupts:
    di
    xor a
    ld [rIF], a
    ld a, (1 << IEF_VBLANK)
    ld [rIE], a
    ei
    ret

InitVRAM:
    push af
    push bc
    push hl
    call WaitVBlank
    xor a
    ld [rLCDC], a
    ld hl, $8000
    ld bc, $1800
    call FillMemory
    call LoadFont
    ld a, %11100100
    ld [rBGP], a
    ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_BGON
    ld [rLCDC], a
    pop af
    pop bc
    pop hl
    ret

LoadFont:
    push af
    push bc
    push de
    push hl
    ld hl, FontData
    ld de, $8000 + (" " * 16)
    ld bc, 96 * 16
    call CopyString
    pop af
    pop bc
    pop de
    pop hl
    ret

; --- Flujo y UI ---
VBlankHandler:
    push af
    push bc
    push de
    push hl
    ld a, [FrameCounter]
    inc a
    ld [FrameCounter], a
    ; Sound_Update podría ir aquí
    pop af
    pop bc
    pop de
    pop hl
    reti

SwitchBank:
    ld [CurrentBank], a
    ld [$2000], a
    ret

ExitGame:
    call SRAM_Init
    xor a
    ld [rNR52], a
    jp $0000

ShowWarning:
    push af
    push bc
    push de
    push hl
    call UI_ClearScreen
    ld a, 2
    ld b, 4
    ld c, 16
    ld d, 10
    call UI_DrawBox
    ld hl, WarningTitle
    ld c, 2
    ld d, 4
    ld e, 16
    call UI_PrintInBox
    ld hl, WarningMsg1
    ld d, 7
    ld e, 4
    call UI_PrintStringAtXY
    ld hl, WarningMsg2
    ld d, 8
    ld e, 4
    call UI_PrintStringAtXY
    ld hl, WarningMsg3
    ld d, 9
    ld e, 4
    call UI_PrintStringAtXY
    ld hl, WarningPress
    ld d, 12
    ld e, 6
    call UI_PrintStringAtXY
    ld a, (1 << BUTTON_A_BIT)
    call WaitButton
    call PlayBeepConfirm
    pop af
    pop bc
    pop de
    pop hl
    ret

DrawMenu:
    push af
    push bc
    push de
    push hl
    call UI_ClearScreen
    ld a, 1
    ld b, 1
    ld c, 18
    ld d, 16
    call UI_DrawBox
    ld hl, MenuTitle
    ld c, 1
    ld d, 1
    ld e, 18
    call UI_PrintInBox
    ld b, 0
.draw_items_loop:
    ld a, b
    cp MENU_ITEMS
    jr z, .draw_instr
    push bc
    push hl
    ld a, b
    add a
    add 4
    push af          ; Save Y coordinate for later
    ld a, [CursorIndex]
    cp b
    jr nz, .no_cursor
    ld a, $3E  ; ASCII '>'
    ld e, 2
    call UI_PrintAtXY
.no_cursor:
    ld hl, MenuPtrs
    ld a, b
    ld c, b
    ld b, 0
    add hl, bc
    add hl, bc
    ld e, [hl]
    inc hl
    ld d, [hl]
    push de  ; Swap DE and HL (Game Boy compatible)
    pop hl
    pop af           ; Restore Y coordinate
    ld d, a
    ld e, 4
    call UI_PrintStringAtXY
    pop hl
    pop bc
    inc b
    jr .draw_items_loop
.draw_instr:
    ld hl, MenuInstr
    ld d, 15
    ld e, 2
    call UI_PrintStringAtXY
    pop af
    pop bc
    pop de
    pop hl
    ret

; ====================================================================
; Variables Globales y Buffers Compartidos
; ====================================================================
SECTION "MainVars", WRAM0[$C000]
CursorIndex::     DS 1
JoyState::        DS 1
JoyPrevState::    DS 1
CurrentBank::     DS 1
EntryReason::     DS 1
FrameCounter::    DS 1

SECTION "SharedBuffers", WRAM0[$C100]
AddressBuf::      DS 24
AmountBuf::       DS 10
CurrentWalletName:: DS WALLET_NAME_LEN
CurrentWalletAddr:: DS WALLET_ADDR_LEN

; ====================================================================
; Datos y Constantes
; ====================================================================
SECTION "MainData", ROM0
MenuTitle: DB "DMG COLD WALLET",0
MenuInstr: DB "A:Sel B:Salir",0
WarningTitle: DB "ADVERTENCIA",0
WarningMsg1: DB "Esta billetera",0
WarningMsg2: DB "NO usa cifrado",0
WarningMsg3: DB "Solo para DEMO",0
WarningPress: DB "Pulsa A",0
MenuPtrs: DW Item0, Item1, Item2, Item3, Item4, Item5, Item6
Item0: DB "Nuevo TX",0
Item1: DB "Confirmar",0
Item2: DB "Gestionar W",0
Item3: DB "Enviar Link",0
Item4: DB "Mostrar QR",0
Item5: DB "Imprimir QR",0
Item6: DB "Salir",0

SECTION "EntryPoints", ROM0
EntryPoints: DW Entry_Input, Entry_Confirm, Entry_SRAM, Entry_LinkTest, Entry_QR_Gen, Entry_Printer, ExitGame

SECTION "FontData", ROM0
FontData:
; Basic 8x8 ASCII font for Game Boy (characters 32-127)
; Each character is 16 bytes (2 bytes per row, 8 rows)
; Format: 2bpp tile data for Game Boy

; Character 32: Space
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Character 33: !
DB $18,$18,$18,$18,$18,$18,$00,$00,$18,$18,$00,$00,$00,$00,$00,$00
; Character 34: "
DB $6C,$6C,$6C,$6C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Character 35: #
DB $36,$36,$7F,$7F,$36,$36,$7F,$7F,$36,$36,$00,$00,$00,$00,$00,$00
; Character 36: $
DB $0C,$0C,$3E,$3E,$03,$03,$1E,$1E,$30,$30,$1F,$1F,$0C,$0C,$00,$00
; Character 37: %
DB $00,$00,$63,$63,$33,$33,$18,$18,$0C,$0C,$66,$66,$63,$63,$00,$00
; Character 38: &
DB $1C,$1C,$36,$36,$1C,$1C,$6E,$6E,$3B,$3B,$33,$33,$6E,$6E,$00,$00
; Character 39: '
DB $06,$06,$06,$06,$03,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Character 40: (
DB $18,$18,$0C,$0C,$06,$06,$06,$06,$06,$06,$0C,$0C,$18,$18,$00,$00
; Character 41: )
DB $06,$06,$0C,$0C,$18,$18,$18,$18,$18,$18,$0C,$0C,$06,$06,$00,$00
; Character 42: *
DB $00,$00,$66,$66,$3C,$3C,$FF,$FF,$3C,$3C,$66,$66,$00,$00,$00,$00
; Character 43: +
DB $00,$00,$0C,$0C,$0C,$0C,$3F,$3F,$0C,$0C,$0C,$0C,$00,$00,$00,$00
; Character 44: ,
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0C,$0C,$0C,$0C,$06,$06
; Character 45: -
DB $00,$00,$00,$00,$00,$00,$3F,$3F,$00,$00,$00,$00,$00,$00,$00,$00
; Character 46: .
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0C,$0C,$0C,$0C,$00,$00
; Character 47: /
DB $60,$60,$30,$30,$18,$18,$0C,$0C,$06,$06,$03,$03,$01,$01,$00,$00
; Character 48: 0
DB $3E,$3E,$63,$63,$73,$73,$7B,$7B,$6F,$6F,$67,$67,$3E,$3E,$00,$00
; Character 49: 1
DB $0C,$0C,$0E,$0E,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$3F,$3F,$00,$00
; Character 50: 2
DB $1E,$1E,$33,$33,$30,$30,$1C,$1C,$06,$06,$33,$33,$3F,$3F,$00,$00
; Character 51: 3
DB $1E,$1E,$33,$33,$30,$30,$1C,$1C,$30,$30,$33,$33,$1E,$1E,$00,$00
; Character 52: 4
DB $38,$38,$3C,$3C,$36,$36,$33,$33,$7F,$7F,$30,$30,$78,$78,$00,$00
; Character 53: 5
DB $3F,$3F,$03,$03,$1F,$1F,$30,$30,$30,$30,$33,$33,$1E,$1E,$00,$00
; Character 54: 6
DB $1C,$1C,$06,$06,$03,$03,$1F,$1F,$33,$33,$33,$33,$1E,$1E,$00,$00
; Character 55: 7
DB $3F,$3F,$33,$33,$30,$30,$18,$18,$0C,$0C,$0C,$0C,$0C,$0C,$00,$00
; Character 56: 8
DB $1E,$1E,$33,$33,$33,$33,$1E,$1E,$33,$33,$33,$33,$1E,$1E,$00,$00
; Character 57: 9
DB $1E,$1E,$33,$33,$33,$33,$3E,$3E,$30,$30,$18,$18,$0E,$0E,$00,$00
; Character 58: :
DB $00,$00,$0C,$0C,$0C,$0C,$00,$00,$0C,$0C,$0C,$0C,$00,$00,$00,$00
; Character 59: ;
DB $00,$00,$0C,$0C,$0C,$0C,$00,$00,$0C,$0C,$0C,$0C,$06,$06,$00,$00
; Character 60: <
DB $18,$18,$0C,$0C,$06,$06,$03,$03,$06,$06,$0C,$0C,$18,$18,$00,$00
; Character 61: =
DB $00,$00,$00,$00,$3F,$3F,$00,$00,$3F,$3F,$00,$00,$00,$00,$00,$00
; Character 62: >
DB $06,$06,$0C,$0C,$18,$18,$30,$30,$18,$18,$0C,$0C,$06,$06,$00,$00
; Character 63: ?
DB $1E,$1E,$33,$33,$30,$30,$18,$18,$0C,$0C,$00,$00,$0C,$0C,$00,$00
; Character 64: @
DB $3E,$3E,$63,$63,$7B,$7B,$7B,$7B,$7B,$7B,$03,$03,$1E,$1E,$00,$00
; Character 65: A
DB $0C,$0C,$1E,$1E,$33,$33,$33,$33,$3F,$3F,$33,$33,$33,$33,$00,$00
; Character 66: B
DB $3F,$3F,$66,$66,$66,$66,$3E,$3E,$66,$66,$66,$66,$3F,$3F,$00,$00
; Character 67: C
DB $3C,$3C,$66,$66,$03,$03,$03,$03,$03,$03,$66,$66,$3C,$3C,$00,$00
; Character 68: D
DB $1F,$1F,$36,$36,$66,$66,$66,$66,$66,$66,$36,$36,$1F,$1F,$00,$00
; Character 69: E
DB $7F,$7F,$46,$46,$16,$16,$1E,$1E,$16,$16,$46,$46,$7F,$7F,$00,$00
; Character 70: F
DB $7F,$7F,$46,$46,$16,$16,$1E,$1E,$16,$16,$06,$06,$0F,$0F,$00,$00
; Character 71: G
DB $3C,$3C,$66,$66,$03,$03,$03,$03,$73,$73,$66,$66,$7C,$7C,$00,$00
; Character 72: H
DB $33,$33,$33,$33,$33,$33,$3F,$3F,$33,$33,$33,$33,$33,$33,$00,$00
; Character 73: I
DB $1E,$1E,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$1E,$1E,$00,$00
; Character 74: J
DB $78,$78,$30,$30,$30,$30,$30,$30,$33,$33,$33,$33,$1E,$1E,$00,$00
; Character 75: K
DB $67,$67,$66,$66,$36,$36,$1E,$1E,$36,$36,$66,$66,$67,$67,$00,$00
; Character 76: L
DB $0F,$0F,$06,$06,$06,$06,$06,$06,$46,$46,$66,$66,$7F,$7F,$00,$00
; Character 77: M
DB $63,$63,$77,$77,$7F,$7F,$7F,$7F,$6B,$6B,$63,$63,$63,$63,$00,$00
; Character 78: N
DB $63,$63,$67,$67,$6F,$6F,$7B,$7B,$73,$73,$63,$63,$63,$63,$00,$00
; Character 79: O
DB $1C,$1C,$36,$36,$63,$63,$63,$63,$63,$63,$36,$36,$1C,$1C,$00,$00
; Character 80: P
DB $3F,$3F,$66,$66,$66,$66,$3E,$3E,$06,$06,$06,$06,$0F,$0F,$00,$00
; Character 81: Q
DB $1E,$1E,$33,$33,$33,$33,$33,$33,$3B,$3B,$1E,$1E,$38,$38,$00,$00
; Character 82: R
DB $3F,$3F,$66,$66,$66,$66,$3E,$3E,$36,$36,$66,$66,$67,$67,$00,$00
; Character 83: S
DB $1E,$1E,$33,$33,$07,$07,$0E,$0E,$38,$38,$33,$33,$1E,$1E,$00,$00
; Character 84: T
DB $3F,$3F,$2D,$2D,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$1E,$1E,$00,$00
; Character 85: U
DB $33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$3F,$3F,$00,$00
; Character 86: V
DB $33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$1E,$1E,$0C,$0C,$00,$00
; Character 87: W
DB $63,$63,$63,$63,$63,$63,$6B,$6B,$7F,$7F,$77,$77,$63,$63,$00,$00
; Character 88: X
DB $63,$63,$63,$63,$36,$36,$1C,$1C,$36,$36,$63,$63,$63,$63,$00,$00
; Character 89: Y
DB $33,$33,$33,$33,$33,$33,$1E,$1E,$0C,$0C,$0C,$0C,$1E,$1E,$00,$00
; Character 90: Z
DB $7F,$7F,$63,$63,$31,$31,$18,$18,$4C,$4C,$66,$66,$7F,$7F,$00,$00
; Character 91: [
DB $1E,$1E,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$1E,$1E,$00,$00
; Character 92: \
DB $03,$03,$06,$06,$0C,$0C,$18,$18,$30,$30,$60,$60,$40,$40,$00,$00
; Character 93: ]
DB $1E,$1E,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$1E,$1E,$00,$00
; Character 94: ^
DB $08,$08,$1C,$1C,$36,$36,$63,$63,$00,$00,$00,$00,$00,$00,$00,$00
; Character 95: _
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00
; Character 96: `
DB $0C,$0C,$0C,$0C,$18,$18,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Character 97: a
DB $00,$00,$00,$00,$1E,$1E,$30,$30,$3E,$3E,$33,$33,$6E,$6E,$00,$00
; Character 98: b
DB $07,$07,$06,$06,$06,$06,$3E,$3E,$66,$66,$66,$66,$3B,$3B,$00,$00
; Character 99: c
DB $00,$00,$00,$00,$1E,$1E,$33,$33,$03,$03,$33,$33,$1E,$1E,$00,$00
; Character 100: d
DB $38,$38,$30,$30,$30,$30,$3E,$3E,$33,$33,$33,$33,$6E,$6E,$00,$00
; Character 101: e
DB $00,$00,$00,$00,$1E,$1E,$33,$33,$3F,$3F,$03,$03,$1E,$1E,$00,$00
; Character 102: f
DB $1C,$1C,$36,$36,$06,$06,$0F,$0F,$06,$06,$06,$06,$0F,$0F,$00,$00
; Character 103: g
DB $00,$00,$00,$00,$6E,$6E,$33,$33,$33,$33,$3E,$3E,$30,$30,$1F,$1F
; Character 104: h
DB $07,$07,$06,$06,$36,$36,$6E,$6E,$66,$66,$66,$66,$67,$67,$00,$00
; Character 105: i
DB $0C,$0C,$00,$00,$0E,$0E,$0C,$0C,$0C,$0C,$0C,$0C,$1E,$1E,$00,$00
; Character 106: j
DB $30,$30,$00,$00,$30,$30,$30,$30,$30,$30,$33,$33,$33,$33,$1E,$1E
; Character 107: k
DB $07,$07,$06,$06,$66,$66,$36,$36,$1E,$1E,$36,$36,$67,$67,$00,$00
; Character 108: l
DB $0E,$0E,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$1E,$1E,$00,$00
; Character 109: m
DB $00,$00,$00,$00,$33,$33,$7F,$7F,$7F,$7F,$6B,$6B,$63,$63,$00,$00
; Character 110: n
DB $00,$00,$00,$00,$1F,$1F,$33,$33,$33,$33,$33,$33,$33,$33,$00,$00
; Character 111: o
DB $00,$00,$00,$00,$1E,$1E,$33,$33,$33,$33,$33,$33,$1E,$1E,$00,$00
; Character 112: p
DB $00,$00,$00,$00,$3B,$3B,$66,$66,$66,$66,$3E,$3E,$06,$06,$0F,$0F
; Character 113: q
DB $00,$00,$00,$00,$6E,$6E,$33,$33,$33,$33,$3E,$3E,$30,$30,$78,$78
; Character 114: r
DB $00,$00,$00,$00,$3B,$3B,$6E,$6E,$66,$66,$06,$06,$0F,$0F,$00,$00
; Character 115: s
DB $00,$00,$00,$00,$3E,$3E,$03,$03,$1E,$1E,$30,$30,$1F,$1F,$00,$00
; Character 116: t
DB $08,$08,$0C,$0C,$3E,$3E,$0C,$0C,$0C,$0C,$2C,$2C,$18,$18,$00,$00
; Character 117: u
DB $00,$00,$00,$00,$33,$33,$33,$33,$33,$33,$33,$33,$6E,$6E,$00,$00
; Character 118: v
DB $00,$00,$00,$00,$33,$33,$33,$33,$33,$33,$1E,$1E,$0C,$0C,$00,$00
; Character 119: w
DB $00,$00,$00,$00,$63,$63,$6B,$6B,$7F,$7F,$7F,$7F,$36,$36,$00,$00
; Character 120: x
DB $00,$00,$00,$00,$63,$63,$36,$36,$1C,$1C,$36,$36,$63,$63,$00,$00
; Character 121: y
DB $00,$00,$00,$00,$33,$33,$33,$33,$33,$33,$3E,$3E,$30,$30,$1F,$1F
; Character 122: z
DB $00,$00,$00,$00,$3F,$3F,$19,$19,$0C,$0C,$26,$26,$3F,$3F,$00,$00
; Character 123: {
DB $38,$38,$0C,$0C,$0C,$0C,$07,$07,$0C,$0C,$0C,$0C,$38,$38,$00,$00
; Character 124: |
DB $18,$18,$18,$18,$18,$18,$00,$00,$18,$18,$18,$18,$18,$18,$00,$00
; Character 125: }
DB $07,$07,$0C,$0C,$0C,$0C,$38,$38,$0C,$0C,$0C,$0C,$07,$07,$00,$00
; Character 126: ~
DB $6E,$6E,$3B,$3B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Character 127: (unused)
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
