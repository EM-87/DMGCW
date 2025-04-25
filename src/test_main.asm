; test_main.asm - Framework básico de pruebas para DMG Cold Wallet
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

SECTION "Tests", ROM0[$0150]

TestMain:
    ; Inicializar sistema
    di
    ld sp, $FFFE
    
    ; Inicializar módulos necesarios
    call InitVRAM
    call ShowTestHeader
    
    ; Ejecutar pruebas unitarias
    call TestMemoryRoutines
    call TestSRAMFunctions
    call TestLinkProtocol
    
    ; Mostrar resultados
    call ShowTestResults
    
    ; Bucle infinito
.wait_forever:
    halt
    jr .wait_forever

; --- Pruebas de memoria ---
TestMemoryRoutines:
    push af
    push bc
    push de
    push hl
    
    ; Probar CopyMemory
    ld hl, TestString1
    ld de, TestBuffer
    ld bc, 10
    call CopyMemory
    
    ; Verificar resultado
    ld hl, TestString1
    ld de, TestBuffer
    ld bc, 10
    call CompareMemory
    jr nz, .copy_failed
    
    ; Incrementar contador de éxito
    ld a, [TestsPassedCount]
    inc a
    ld [TestsPassedCount], a
    jr .next_test
    
.copy_failed:
    ; Incrementar contador de fallos
    ld a, [TestsFailedCount]
    inc a
    ld [TestsFailedCount], a
    
.next_test:
    ; Probar FillMemory
    ld hl, TestBuffer
    ld bc, 10
    ld a, $AA
    call FillMemory
    
    ; Verificar resultado
    ld hl, TestBuffer
    ld b, 10
.check_fill:
    ld a, [hl+]
    cp $AA
    jr nz, .fill_failed
    dec b
    jr nz, .check_fill
    
    ; Incrementar contador de éxito
    ld a, [TestsPassedCount]
    inc a
    ld [TestsPassedCount], a
    jr .done
    
.fill_failed:
    ; Incrementar contador de fallos
    ld a, [TestsFailedCount]
    inc a
    ld [TestsFailedCount], a
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Pruebas de SRAM ---
TestSRAMFunctions:
    push af
    push bc
    push de
    push hl
    
    ; Inicializar SRAM
    call SRAM_Init
    
    ; Probar escritura y lectura
    ld hl, TestWalletName
    ld de, WALLET_NAME
    ld bc, WALLET_NAME_LEN
    call CopyMemory
    
    ld hl, TestWalletAddr
    ld de, WALLET_ADDR
    ld bc, WALLET_ADDR_LEN
    call CopyMemory
    
    ; Guardar wallet
    xor a
    call SRAM_SaveWallet
    or a
    jr nz, .save_failed
    
    ; Leer wallet
    xor a
    call SRAM_LoadWallet
    or a
    jr nz, .load_failed
    
    ; Verificar datos
    ld hl, WALLET_NAME
    ld de, TestWalletName
    ld bc, WALLET_NAME_LEN
    call CompareMemory
    jr nz, .verify_failed
    
    ; Incrementar contador de éxito
    ld a, [TestsPassedCount]
    inc a
    ld [TestsPassedCount], a
    jr .done
    
.save_failed:
.load_failed:
.verify_failed:
    ; Incrementar contador de fallos
    ld a, [TestsFailedCount]
    inc a
    ld [TestsFailedCount], a
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Pruebas de Link ---
TestLinkProtocol:
    ; Implementación básica para probar el protocolo link
    ret

; --- UI de pruebas ---
ShowTestHeader:
    call UI_ClearScreen
    
    ld hl, TestTitle
    ld d, 1
    ld e, 5
    call UI_PrintStringAtXY
    
    ret

ShowTestResults:
    ld hl, TestsPassedMsg
    ld d, 5
    ld e, 3
    call UI_PrintStringAtXY
    
    ld a, [TestsPassedCount]
    add "0"
    ld d, 5
    ld e, 15
    call UI_PrintAtXY
    
    ld hl, TestsFailedMsg
    ld d, 7
    ld e, 3
    call UI_PrintStringAtXY
    
    ld a, [TestsFailedCount]
    add "0"
    ld d, 7
    ld e, 15
    call UI_PrintAtXY
    
    ret

; --- Datos de prueba ---
SECTION "TestData", ROM0
TestTitle:      DB "DMG Wallet Tests", 0
TestsPassedMsg: DB "Passed: ", 0
TestsFailedMsg: DB "Failed: ", 0
TestString1:    DB "Test12345", 0
TestWalletName: DB "TestWallet", 0
TestWalletAddr: DB "ABC123XYZ", 0

; --- Variables de prueba ---
SECTION "TestVars", WRAM0[$C800]
TestsPassedCount:  DS 1
TestsFailedCount:  DS 1
TestBuffer:        DS 32
