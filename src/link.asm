; link.asm - Comunicación por cable Link con protocolo robusto
; Protocolo: [0xA5][len][payload...][cs] -> ACK/NACK
INCLUDE "hardware.inc"
INCLUDE "../inc/constants.inc"

SECTION "LinkModule", ROM1[$6000]

; --- Entry point ---
Entry_LinkTest:
    push af
    push bc
    push de
    push hl
    
    ; Mostrar pantalla de prueba Link
    call UI_ClearScreen
    
    ; Dibujar caja para UI
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call UI_DrawBox
    
    ; Título
    ld hl, LinkTestTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y 
    ld e, 18  ; box_width
    call UI_PrintInBox
    
    ; Instrucciones
    ld hl, LinkInstruction
    ld d, 3   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Esperar botón A
    call WaitButtonA
    
    ; Mostrar "Enviando..."
    ld hl, LinkSending
    ld d, 5   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Preparar payload de prueba
    ld hl, LinkTestData    ; Origen
    ld de, LinkBuffer      ; Destino
    ld bc, LinkTestLen     ; Longitud
    call CopyMemory
    
    ; Enviar paquete de prueba
    ld hl, LinkBuffer
    ld a, [LinkTestLen]
    ld c, a                ; C = longitud
    call link_send_packet
    
    ; A=0 si éxito, A!=0 si error
    or a
    jr nz, .error
    
    ; Mostrar éxito
    ld hl, LinkSuccess
    ld d, 7   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar datos enviados
    ld hl, LinkDataSent
    ld d, 9   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ld hl, LinkBuffer
    ld d, 10  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    jr .wait_exit
    
.error:
    ; Mostrar error
    ld hl, LinkError
    ld d, 7   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Mostrar código de error
    ld hl, LinkErrorCode
    ld d, 9   ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Convertir código de error a ASCII y mostrar
    ld a, [LinkLastError]
    call ByteToHex
    ld d, 9   ; y
    ld e, 15  ; x
    call UI_PrintStringAtXY
    
.wait_exit:
    ; Instrucciones para salir
    ld hl, LinkPressB
    ld d, 14  ; y
    ld e, 3   ; x
    call UI_PrintStringAtXY
    
    ; Esperar botón B
    call WaitButtonB
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Rutinas Link ---

; link_init: Inicializa el subsistema Link
link_init:
    ; Configurar SB y SC para iniciar comunicación
    xor a
    ld [rSB], a      ; Limpiar buffer serie
    ld a, $80
    ld [rSC], a      ; Configurar como master, inactivo
    ret

; link_send_byte: Envía un byte con timeout
; Entrada: A = byte a enviar
; Salida: A = byte recibido, o $FF si timeout
; Modifica: BC
link_send_byte:
    push hl
    
    ; Guardar byte para timeout
    ld [LinkLastByte], a
    
    ; Enviar byte
    ld [rSB], a
    ld a, $81        ; Iniciar transferencia (master)
    ld [rSC], a
    
    ; Esperar a que se complete la transferencia o timeout
    ld bc, TIMEOUT_SHORT  ; Usar timeout parametrizado
.wait_send:
    ld a, [rSC]
    bit 7, a         ; Comprobar si transferencia en curso
    jr z, .send_complete
    
    ; Decrementar contador de timeout
    dec bc
    ld a, b
    or c
    jr nz, .wait_send
    
    ; Timeout ocurrido
    ld a, NACK_BYTE
    ld [LinkLastError], a
    pop hl
    ret
    
.send_complete:
    ; Leer byte recibido
    ld a, [rSB]
    
    pop hl
    ret

; link_receive_byte: Recibe un byte con timeout
; Salida: A = byte recibido, o $FF si timeout
; Modifica: BC
link_receive_byte:
    push hl
    
    ; Preparar para recibir
    xor a
    ld [rSB], a
    ld a, $80        ; Modo recepción
    ld [rSC], a
    
    ; Esperar dato o timeout
    ld bc, TIMEOUT_SHORT  ; Usar timeout parametrizado
.wait_receive:
    ld a, [rSC]
    bit 7, a
    jr z, .receive_complete
    
    ; Decrementar contador timeout
    dec bc
    ld a, b
    or c
    jr nz, .wait_receive
    
    ; Timeout ocurrido
    ld a, NACK_BYTE
    ld [LinkLastError], a
    pop hl
    ret
    
.receive_complete:
    ; Leer byte recibido
    ld a, [rSB]
    
    pop hl
    ret

; link_send_packet: Envía un paquete completo con protocolo
; Entrada: HL = puntero a datos, C = longitud
; Salida: A = 0 si éxito, otro valor si error
; Modifica: BC, DE
link_send_packet:
    push hl
    
    ; Guardar parámetros
    ld a, c
    ld [LinkPayloadLen], a
    ld [LinkPacketPtr], hl
    
    ; Inicializar contador de reintentos
    ld a, MAX_RETRIES
    ld [LinkRetryCount], a
    
.retry:
    ; Enviar byte de inicio
    ld a, START_BYTE
    call link_send_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Enviar longitud
    ld a, [LinkPayloadLen]
    call link_send_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Inicializar checksum con bytes ya enviados
    ld a, START_BYTE
    ld [LinkChecksum], a
    ld a, [LinkPayloadLen]
    ld b, a
    ld a, [LinkChecksum]
    xor b
    ld [LinkChecksum], a
    
    ; Enviar payload
    ld hl, [LinkPacketPtr]
    ld b, 0
    ld a, [LinkPayloadLen]
    ld c, a          ; BC = longitud
    
.send_loop:
    ; Verificar si quedan bytes
    ld a, c
    or a
    jr z, .send_checksum
    
    ; Enviar siguiente byte
    ld a, [hl]
    
    ; Actualizar checksum
    ld d, a          ; Guardar byte
    ld a, [LinkChecksum]
    xor d
    ld [LinkChecksum], a
    ld a, d          ; Restaurar byte
    
    ; Enviar byte
    call link_send_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Avanzar al siguiente byte
    inc hl
    dec c
    jr .send_loop
    
.send_checksum:
    ; Enviar checksum
    ld a, [LinkChecksum]
    call link_send_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Esperar ACK/NACK
    call link_receive_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Verificar si es ACK
    cp ACK_BYTE
    jr z, .success
    
    ; Es NACK, reintentar si quedan intentos
    ld a, [LinkRetryCount]
    dec a
    ld [LinkRetryCount], a
    jr z, .retry_error
    jr .retry
    
.timeout_error:
    ; Error de timeout
    ld a, LINK_ERR_TIMEOUT
    ld [LinkLastError], a
    pop hl
    ret
    
.retry_error:
    ; Agotados los reintentos
    ld a, LINK_ERR_RETRY
    ld [LinkLastError], a
    pop hl
    ret
    
.success:
    ; Éxito
    xor a
    ld [LinkLastError], a
    pop hl
    ret

; link_receive_packet: Recibe un paquete completo
; Entrada: HL = buffer donde almacenar
; Salida: A = 0 si éxito, otro valor si error
;         C = longitud de datos recibidos
link_receive_packet:
    push de
    
    ; Guardar puntero a buffer
    ld [LinkPacketPtr], hl
    
    ; Esperar byte de inicio
.wait_start:
    call link_receive_byte
    cp NACK_BYTE
    jr z, .timeout_error
    cp START_BYTE
    jr nz, .wait_start
    
    ; Recibir longitud
    call link_receive_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Guardar longitud
    ld [LinkPayloadLen], a
    ld c, a
    
    ; Inicializar checksum
    ld a, START_BYTE
    ld [LinkChecksum], a
    ld a, [LinkPayloadLen]
    ld b, a
    ld a, [LinkChecksum]
    xor b
    ld [LinkChecksum], a
    
    ; Verificar que la longitud no exceda el buffer
    ld a, c
    cp MAX_PAYLOAD + 1
    jr nc, .length_error
    
    ; Recibir payload
    ld hl, [LinkPacketPtr]
    ld b, 0          ; BC = longitud
    
.receive_loop:
    ; Verificar si quedan bytes
    ld a, c
    or a
    jr z, .receive_checksum
    
    ; Recibir byte
    call link_receive_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Guardar byte en buffer
    ld [hl+], a
    
    ; Actualizar checksum
    ld b, a
    ld a, [LinkChecksum]
    xor b
    ld [LinkChecksum], a
    
    ; Avanzar al siguiente byte
    dec c
    jr .receive_loop
    
.receive_checksum:
    ; Recibir checksum
    call link_receive_byte
    cp NACK_BYTE
    jr z, .timeout_error
    
    ; Verificar checksum
    ld b, a          ; B = checksum recibido
    ld a, [LinkChecksum]
    cp b
    jr nz, .checksum_error
    
    ; Checksum correcto, enviar ACK
    ld a, ACK_BYTE
    call link_send_byte
    
    ; Éxito
    xor a
    ld [LinkLastError], a
    ld a, [LinkPayloadLen]
    ld c, a          ; Devolver longitud en C
    pop de
    ret
    
.timeout_error:
    ; Error de timeout
    ld a, LINK_ERR_TIMEOUT
    ld [LinkLastError], a
    pop de
    ret
    
.length_error:
    ; Error de longitud
    ld a, LINK_ERR_LENGTH
    ld [LinkLastError], a
    
    ; Enviar NACK
    ld a, NACK_BYTE
    call link_send_byte
    
    pop de
    ret
    
.checksum_error:
    ; Error de checksum
    ld a, LINK_ERR_CHECKSUM
    ld [LinkLastError], a
    
    ; Enviar NACK
    ld a, NACK_BYTE
    call link_send_byte
    
    pop de
    ret

; WaitButtonA: Espera hasta que se pulse el botón A
WaitButtonA:
    push af
    
.wait_loop:
    ; Leer estado de botones
    call ReadJoypad
    ld a, [JoyState]
    bit PADB_A, a
    jr z, .wait_loop
    
    ; Esperar a que se suelte
.release_loop:
    call ReadJoypad
    ld a, [JoyState]
    bit PADB_A, a
    jr nz, .release_loop
    
    ; Reproducir sonido de confirmación
    call PlayBeepConfirm
    
    pop af
    ret

; WaitButtonB: Espera hasta que se pulse el botón B
WaitButtonB:
    push af
    
.wait_loop:
    ; Leer estado de botones
    call ReadJoypad
    ld a, [JoyState]
    bit PADB_B, a
    jr z, .wait_loop
    
    ; Esperar a que se suelte
.release_loop:
    call ReadJoypad
    ld a, [JoyState]
    bit PADB_B, a
    jr nz, .release_loop
    
    ; Reproducir sonido de cancelación
    call PlayBeepNav
    
    pop af
    ret

; --- Datos y mensajes ---
SECTION "LinkData", ROM1
LinkTestTitle:    DB "TEST DE LINK", 0
LinkInstruction:  DB "A: Enviar datos", 0
LinkSending:      DB "Enviando...", 0
LinkSuccess:      DB "Exito! ACK recibido", 0
LinkError:        DB "Error en Link!", 0
LinkErrorCode:    DB "Codigo error: ", 0
LinkDataSent:     DB "Datos enviados:", 0
LinkPressB:       DB "B: Volver al menu", 0

; Datos de prueba
LinkTestData:     DB "HOLA GAMEBOY DMGCOLD!", 0
LinkTestLen:      DB 21

; --- Variables en WRAM ---
SECTION "LinkVars", WRAM0[$C800]
LinkBuffer:       DS MAX_PAYLOAD    ; Buffer para datos
LinkPacketPtr:    DS 2              ; Puntero a paquete actual
LinkPayloadLen:   DS 1              ; Longitud de payload
LinkChecksum:     DS 1              ; Checksum calculado
LinkRetryCount:   DS 1              ; Contador de reintentos
LinkLastByte:     DS 1              ; Último byte enviado
LinkLastError:    DS 1              ; Último código de error
