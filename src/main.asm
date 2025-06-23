; ====================================================================
; File: src/main.asm - Módulo Principal (Refactorizado)
; ====================================================================

; --- Inclusiones y Declaraciones Externas ---
INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"

; --- Declaración de funciones externas ---
EXTERN CopyString, FillMemory, WaitButton, WaitVBlank, ReadJoypadWithDebounce, ReadJoypad
EXTERN UI_ClearScreen, UI_DrawBox, UI_PrintInBox, UI_PrintStringAtXY, UI_PrintAtXY
EXTERN InitSound, PlayBeepNav, PlayBeepConfirm
EXTERN InitSRAM
EXTERN Entry_Input, Entry_Confirm, Entry_SRAM, Entry_LinkTest, Entry_QR_Gen, Entry_Printer

; ====================================================================
; Vectores de Interrupción y Entry Point
; ====================================================================
SECTION "Reset", ROM0[$0000]
    jp Start

SECTION "VBlank", ROM0[$0040]
    jp VBlankHandler

; ... (otras interrupciones sin cambios) ...
SECTION "LCDStat", ROM0[$0048], reti
SECTION "Timer", ROM0[$0050], reti
SECTION "Serial", ROM0[$0058], reti
SECTION "Joypad", ROM0[$0060], reti

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
    bit BUTTON_UP_BIT, a,   jr nz, .move_up
    bit BUTTON_DOWN_BIT, a, jr nz, .move_down
    bit BUTTON_A_BIT, a,    jr nz, .select_item
    jr .read_input_loop

.move_up:
    ld a, [CursorIndex], or a, jr z, .read_input_loop
    dec a, ld [CursorIndex], a, call PlayBeepNav, jp MainLoop
.move_down:
    ld a, [CursorIndex], cp MENU_ITEMS - 1, jr z, .read_input_loop
    inc a, ld [CursorIndex], a, call PlayBeepNav, jp MainLoop

.select_item:
    call PlayBeepConfirm
    ld a, ENTRY_NEW, ld [EntryReason], a
    ld a, 1, call SwitchBank
    ld a, [CursorIndex], ld c, a, ld b, 0, ld hl, EntryPoints, add hl, bc, add hl, bc
    ld e, [hl], inc hl, ld d, [hl], push de, ret

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
    call InitSRAM
    call InitVRAM
    call InitInterrupts
    ret

InitInterrupts:
    di, xor a, ld [rIF], a, ld a, (1 << IEF_VBLANK), ld [rIE], a, ei, ret

InitVRAM:
    push af, bc, hl
    call WaitVBlank
    xor a, ld [rLCDC], a
    ld hl, $8000, ld bc, $1800, call FillMemory
    call LoadFont
    ld a, %11100100, ld [rBGP], a
    ld a, LCDCF_ON | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_BGON, ld [rLCDC], a
    pop hl, bc, af, ret

LoadFont:
    push af, bc, de, hl
    ld hl, FontData, ld de, $8000 + (" " * 16), ld bc, 96 * 16, call CopyString
    pop hl, de, bc, af, ret

; --- Flujo y UI ---
VBlankHandler:
    push af, bc, de, hl
    ld a, [FrameCounter], inc a, ld [FrameCounter], a
    ; Sound_Update podría ir aquí
    pop hl, de, bc, af, reti

SwitchBank:
    ld [CurrentBank], a, ld [$2000], a, ret

ExitGame:
    call SRAM_Init, xor a, ld [rNR52], a, jp $0000

ShowWarning:
    push af, bc, de, hl
    call UI_ClearScreen, ld a, 2, ld b, 4, ld c, 16, ld d, 10, call UI_DrawBox
    ld hl, WarningTitle, ld c, 2, ld d, 4, ld e, 16, call UI_PrintInBox
    ld hl, WarningMsg1, ld d, 7, ld e, 4, call UI_PrintStringAtXY
    ld hl, WarningMsg2, ld d, 8, ld e, 4, call UI_PrintStringAtXY
    ld hl, WarningMsg3, ld d, 9, ld e, 4, call UI_PrintStringAtXY
    ld hl, WarningPress, ld d, 12, ld e, 6, call UI_PrintStringAtXY
    ld a, (1 << BUTTON_A_BIT), call WaitButton, call PlayBeepConfirm
    pop hl, de, bc, af, ret

DrawMenu:
    push af, bc, de, hl
    call UI_ClearScreen, ld a, 1, ld b, 1, ld c, 18, ld d, 16, call UI_DrawBox
    ld hl, MenuTitle, ld c, 1, ld d, 1, ld e, 18, call UI_PrintInBox
    ld b, 0
.draw_items_loop:
    ld a, b, cp MENU_ITEMS, jr z, .draw_instr
    push bc, push hl, ld a, b, add a, add 4, ld d, a
    ld a, [CursorIndex], cp b, jr nz, .no_cursor
    ld a, '>', ld e, 2, call UI_PrintAtXY
.no_cursor:
    ld hl, MenuPtrs, ld a, b, ld c, b, ld b, 0, add hl, bc, add hl, bc
    ld e, [hl], inc hl, ld d, [hl], ex de, hl
    ld d, [sp], ld e, 4, call UI_PrintStringAtXY
    pop hl, pop bc, inc b, jr .draw_items_loop
.draw_instr:
    ld hl, MenuInstr, ld d, 15, ld e, 2, call UI_PrintStringAtXY
    pop hl, de, bc, af, ret

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
WarningMsg1: DB "Esta billetera",0, WarningMsg2: DB "NO usa cifrado",0, WarningMsg3: DB "Solo para DEMO",0, WarningPress: DB "Pulsa A",0
MenuPtrs: DW Item0, Item1, Item2, Item3, Item4, Item5, Item6
Item0: DB "Nuevo TX",0, Item1: DB "Confirmar",0, Item2: DB "Gestionar W",0, Item3: DB "Enviar Link",0, Item4: DB "Mostrar QR",0, Item5: DB "Imprimir QR",0, Item6: DB "Salir",0

SECTION "EntryPoints", ROM0
EntryPoints: DW Entry_Input, Entry_Confirm, Entry_SRAM, Entry_LinkTest, Entry_QR_Gen, Entry_Printer, ExitGame

SECTION "FontData", ROM0
FontData:
; (sin cambios, la fuente es grande y se mantiene igual)
