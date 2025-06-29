; ====================================================================
; File: src/sram.asm - UI de Gestión de Wallets (Refactorizado)
; ====================================================================

INCLUDE "inc/hardware.inc"
INCLUDE "inc/constants.inc"
INCLUDE "lib/utils.asm"      ; <<<--- INCLUIR LAS UTILIDADES CENTRALIZADAS

; --- Constantes del Módulo ---
SRAM_MENU_ITEMS     EQU 4      ; Crear, Seleccionar, Borrar, Volver
LIST_MODE_SELECT    EQU 0
LIST_MODE_DELETE    EQU 1

; --- Dependencias Externas ---
EXTERN JoyState, CurrentWalletName, InputPromptAddr, InputDestBufAddr, InputMaxLen
EXTERN PlayBeepNav, PlayBeepConfirm, PlayBeepError
EXTERN UI_ClearScreen, UI_PrintStringAtXY, UI_PrintAtXY
EXTERN SRAM_GetWalletCount, SRAM_LoadWallet, SRAM_CreateWallet, SRAM_DeleteWallet, WALLET_NAME, WALLET_ADDR
EXTERN Entry_Input

; --- Variables WRAM ---
SECTION "SramUIVars", WRAM0[$C300]
    sram_menu_cursor_pos:   DS 1
    sram_wallet_count:      DS 1
    sram_list_cursor_pos:   DS 1
    sram_list_mode:         DS 1
    sram_wallet_names_buffer: DS (WALLET_NAME_LEN + 1) * MAX_WALLETS
    NewWalletNameBuffer:    DS WALLET_NAME_LEN + 1
    NewWalletAddrBuffer:    DS WALLET_ADDR_LEN + 1

; --- Strings ---
SECTION "SramStrings", ROM1
SramMenuTitle:       DB "Gestion de Wallets",0
MenuOptionCreate:    DB "Crear Wallet",0, MenuOptionSelect: DB "Seleccionar Wallet",0, MenuOptionDelete: DB "Eliminar Wallet",0, MenuOptionBack: DB "Volver",0
CreateNamePrompt:    DB "Nombre wallet:",0, CreateAddrPrompt: DB "Direccion wallet:",0
NoWalletsMsg:        DB "No hay wallets.",0, LimitErrorMsg: DB "Limite de wallets.",0
ListTitleSelect:     DB "Seleccionar Wallet",0, ListTitleDelete: DB "Eliminar Wallet",0
ConfirmDeletePrompt: DB "Borrar? A=Si B=No",0
MsgCreated:          DB "Wallet creado.",0, MsgDeleted: DB "Wallet eliminado.",0, MsgSelected: DB "Wallet seleccionado.",0

; ====================================================================
; Entry Point y Lógica del Menú Principal
; ====================================================================
SECTION "SramMenuCode", ROM1

Entry_SRAM:
    xor a
    ld [sram_menu_cursor_pos], a
.loop_menu:
    call DrawSramMenu
    call ReadJoypadWithDebounce
    ld a, [JoyState]
    bit BUTTON_UP_BIT, a
    jr nz, .move_up
    bit BUTTON_DOWN_BIT, a
    jr nz, .move_down
    bit BUTTON_A_BIT, a
    jr nz, .select_option
    bit BUTTON_B_BIT, a
    ret
    jr .loop_menu

.move_up:
    ld a, [sram_menu_cursor_pos]
    or a
    jr z, .wrap_bottom
    dec a
    jr .update_cursor
.wrap_bottom: ld a, SRAM_MENU_ITEMS - 1
.update_cursor:
    ld [sram_menu_cursor_pos], a
    call PlayBeepNav
    jr .loop_menu

.move_down:
    ld a, [sram_menu_cursor_pos]
    inc a
    cp SRAM_MENU_ITEMS
    jr c, .update_cursor
    xor a
    jr .update_cursor

.select_option:
    call PlayBeepConfirm
    ld a, [sram_menu_cursor_pos]
    cp 0
    jp z, CreateWalletFlow
    cp 1
    jp z, SelectWalletFlow
    cp 2
    jp z, DeleteWalletFlow
    ret

; ====================================================================
; Flujos de Lógica: Crear, Seleccionar, Borrar
; ====================================================================
CreateWalletFlow:
    call SRAM_GetWalletCount
    cp MAX_WALLETS
    jr nc, .limit_error
    ld hl, CreateNamePrompt
    ld de, NewWalletNameBuffer
    ld c, WALLET_NAME_LEN
    call GetText
    ld hl, CreateAddrPrompt
    ld de, NewWalletAddrBuffer
    ld c, WALLET_ADDR_LEN
    call GetText
    ld hl, NewWalletNameBuffer
    ld de, WALLET_NAME
    ld bc, WALLET_NAME_LEN
    call CopyString
    ld hl, NewWalletAddrBuffer
    ld de, WALLET_ADDR
    ld bc, WALLET_ADDR_LEN
    call CopyString
    call SRAM_CreateWallet
    ld hl, MsgCreated
    call ShowMessage
    jp Entry_SRAM
.limit_error:
    ld hl, LimitErrorMsg
    call ShowMessage
    jp Entry_SRAM

SelectWalletFlow:
    ld a, LIST_MODE_SELECT
    call WalletList_Show
    jp Entry_SRAM
DeleteWalletFlow:
    ld a, LIST_MODE_DELETE
    call WalletList_Show
    jp Entry_SRAM

WalletList_Show:
    ld [sram_list_mode], a
    call SRAM_GetWalletCount
    or a
    jr z, .no_wallets
    ld [sram_wallet_count], a
    ld b, 0
    ld c, a
    ld hl, sram_wallet_names_buffer
.load_loop:
    ld a, b
    cp c
    jr z, .loaded
    push hl
    push bc
    ld a, b
    call SRAM_LoadWallet
    pop bc
    pop hl
    ld de, WALLET_NAME
.copy_name:
    ld a, [de+]
    ld [hl+], a
    or a
    jr nz, .copy_name
    inc b
    jr .load_loop
.loaded:
    xor a
    ld [sram_list_cursor_pos], a
.list_loop:
    call DrawWalletList
    call ReadJoypadWithDebounce
    ld a, [JoyState]
    bit BUTTON_UP_BIT, a
    jr nz, .list_up
    bit BUTTON_DOWN_BIT, a
    jr nz, .list_down
    bit BUTTON_A_BIT, a
    jr nz, .list_select
    bit BUTTON_B_BIT, a
    jr z, .list_loop
    ret

.no_wallets:
    ld hl, NoWalletsMsg
    call ShowMessage
    ret
.list_up:
    ld a, [sram_list_cursor_pos]
    or a
    jr z, .list_wrap_bot
    dec a
    jr .list_upd
.list_wrap_bot: ld a, [sram_wallet_count], dec a
.list_upd:
    ld [sram_list_cursor_pos], a
    call PlayBeepNav
    jr .list_loop
.list_down:
    ld a, [sram_list_cursor_pos]
    inc a
    ld b, a
    ld a, [sram_wallet_count]
    cp b
    jr c, .list_upd
    xor a
    jr .list_upd
.list_select:
    call PlayBeepConfirm
    ld a, [sram_list_mode]
    cp LIST_MODE_DELETE
    jr z, .delete_wallet
    ld a, [sram_list_cursor_pos]
    call SRAM_LoadWallet
    ld hl, MsgSelected
    call ShowMessage
    ret
.delete_wallet:
    call ConfirmDelete
    or a
    jr z, .list_loop
    ld a, [sram_list_cursor_pos]
    call SRAM_DeleteWallet
    ld hl, MsgDeleted
    call ShowMessage
    ret

; ====================================================================
; Subrutinas y UI
; ====================================================================
GetText: ; Entrada: HL=Prompt, DE=DestBuffer, C=MaxLen
    push de
    push bc
    ld a, h
    ld [InputPromptAddr+1], a
    ld a, l
    ld [InputPromptAddr], a
    ld a, e
    ld [InputDestBufAddr+1], a
    ld a, d
    ld [InputDestBufAddr], a
    pop af
    ld [InputMaxLen], a
    call Entry_Input
    pop de
    pop bc
    ret

DrawSramMenu:
    call UI_ClearScreen
    ld hl, SramMenuTitle
    ld d, 2
    ld e, 2
    call UI_PrintStringAtXY
    ld hl, MenuOptionCreate
    ld d, 5
    ld e, 3
    ld a, 0
    call DrawMenuItem
    ld hl, MenuOptionSelect
    ld d, 6
    ld e, 3
    ld a, 1
    call DrawMenuItem
    ld hl, MenuOptionDelete
    ld d, 7
    ld e, 3
    ld a, 2
    call DrawMenuItem
    ld hl, MenuOptionBack
    ld d, 8
    ld e, 3
    ld a, 3
    call DrawMenuItem
    ret
DrawMenuItem:
    push af
    ld a, [sram_menu_cursor_pos]
    cp [sp+2]
    jr nz, .no_cursor
    ld a, '>'
    ld b, e
    dec b
    push de
    ld e, b
    call UI_PrintAtXY
    pop de
.no_cursor:
    call UI_PrintStringAtXY
    pop af
    ret

DrawWalletList:
    call UI_ClearScreen
    ld a, [sram_list_mode]
    or a
    jr z, .title_select
    ld hl, ListTitleDelete
    jr .draw_title
.title_select:
    ld hl, ListTitleSelect
.draw_title:
    ld d, 2
    ld e, 2
    call UI_PrintStringAtXY
    ld c, [sram_wallet_count]
    ld hl, sram_wallet_names_buffer
    xor b
.loop_draw:
    ld a, b
    cp c
    jr z, .done_draw
    push hl
    ld a, b
    add 5
    ld d, a
    ld a, [sram_list_cursor_pos]
    cp b
    jr nz, .no_cursor_list
    ld a, '>'
    ld e, 1
    call UI_PrintAtXY
.no_cursor_list:
    ld e, 3
    call UI_PrintStringAtXY
    pop hl
.skip_name:
    ld a, [hl+]
    or a
    jr nz, .skip_name
    inc b
    jr .loop_draw
.done_draw:
    ret

ConfirmDelete:
    ld hl, ConfirmDeletePrompt
    call ShowMessageNoWait
.wait_confirm:
    call ReadJoypad
    ld a, [JoyState]
    ld c, a
    and (1 << BUTTON_A_BIT) | (1 << BUTTON_B_BIT)
    cp c
    jr z, .wait_confirm
    ld a, [JoyState]
    bit BUTTON_A_BIT, a
    ret

ShowMessage:
    call ShowMessageNoWait
    ld a, (1 << BUTTON_A_BIT) | (1 << BUTTON_B_BIT)
    call WaitButton
    ret
ShowMessageNoWait:
    call UI_ClearScreen
    ld d, 8
    ld e, 3
    call UI_PrintStringAtXY
    ret
