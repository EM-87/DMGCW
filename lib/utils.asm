; utils.asm - Rutinas de utilidades para DMG Cold Wallet
INCLUDE "../inc/hardware.inc"
INCLUDE "../inc/constants.inc"

EXPORT CopyMemory

; ------------------------------------------------------------
; CopyMemory: Copia BC bytes desde HL a DE
; Entradas: HL=origen, DE=destino, BC=cantidad
; Modifica: AF, BC, DE, HL
; ------------------------------------------------------------
CopyMemory:
    push af
    push bc
    push de
    push hl
.loop:
    ld a, b
    or c
    jr z, .done
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    jr .loop
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; End of utils.asm
