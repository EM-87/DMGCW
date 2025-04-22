; printer.asm - Interfaz de comunicación con Game Boy Printer
INCLUDE "hardware.inc"

SECTION "PrinterModule", ROM1[$5800]

; --- Constantes ---
; Constantes del protocolo de impresión
PRINTER_INIT    EQU $01  ; Inicialización
PRINTER_PRINT   EQU $02  ; Comando de impresión
PRINTER_DATA    EQU $04  ; Comando de envío de datos
PRINTER_STATUS  EQU $0F  ; Comando de solicitud de estado

PRINTER_READY   EQU $00  ; Printer lista
PRINTER_BUSY    EQU $01  ; Printer ocupada
PRINTER_ERROR   EQU $FF  ; Error genérico

; Tamaños de cabecera y datos
HEADER_SIZE     EQU 4    ; Tamaño de cabecera (comando, comprensión, len_lo, len_hi)
FOOTER_SIZE     EQU 2    ; Tamaño de pie (checksum lo, hi)
DATA_PACKET_SIZE EQU 640  ; Tamaño máximo de datos por paquete (640 bytes)

; Cabecera de trama Game Boy Printer
PRINTER_SYNC_1  EQU $88  ; Byte 1 de sincronización
PRINTER_SYNC_2  EQU $33  ; Byte 2 de sincronización

; Dimensiones para imprimir QR
QR_TILES_WIDTH  EQU 8    ; Ancho del QR en tiles (8 tiles = 64 píxeles)
QR_TILES_HEIGHT EQU 8    ; Alto del QR en tiles
QR_MARGIN       EQU 2    ; Margen alrededor del QR en tiles

; Configuración de márgenes de impresión
PRINTER_MARGINS  EQU $00  ; Sin márgenes adicionales

; Tiempo de espera para timeout
PRINTER_TIMEOUT  EQU 1000  ; Ciclos para timeout

; --- Entry Point ---
Entry_Printer:
    push af
    push bc
    push de
    push hl
    
    ; Verificar si hay datos para imprimir
    ld a, [AddressBuf]
    or a
    jr z, .no_data

    ; Mostrar pantalla "Imprimiendo..."
    call DrawPrinterScreen
    
    ; Inicializar comunicación con la impresora
    call InitPrinterComm
    jr nz, .comm_error
    
    ; Preparar buffer de impresión
    call PrepareQRPrintBuffer
    
    ; Enviar comando de inicio
    call PrinterSendInit
    jr nz, .comm_error
    
    ; Enviar datos del QR en bloques
    call PrinterSendQRData
    jr nz, .comm_error
    
    ; Enviar comando de impresión
    call PrinterSendPrint
    jr nz, .comm_error
    
    ; Mostrar mensaje de éxito
    call ShowPrintSuccess
    jr .wait_exit
    
.comm_error:
    ; Mostrar error de comunicación
    call ShowPrinterError
    jr .wait_exit
    
.no_data:
    ; Mostrar mensaje de "No hay datos"
    call ShowNoDataError
    
.wait_exit:
    ; Esperar a que se pulse B para volver
    call WaitButtonB
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; --- Rutinas de comunicación con la impresora ---

; InitPrinterComm: Inicializa la comunicación con la impresora
; Salida: Z=1 si OK, Z=0 si error
InitPrinterComm:
    ; Configurar puerto serie
    xor a
    ld [rSB], a      ; Limpiar buffer
    ld a, $80        ; Velocidad normal, modo interno, transferencias detenidas
    ld [rSC], a
    
    ; Verificar si la impresora está conectada y lista
    call GetPrinterStatus
    cp PRINTER_READY
    ret

; GetPrinterStatus: Obtiene el estado de la impresora
; Salida: A = estado (0=OK, otros valores=error)
GetPrinterStatus:
    push bc
    push de
    push hl
    
    ; Crear paquete de consulta de estado
    ld hl, PrinterPacket
    
    ; Cabecera de sincronización
    ld a, PRINTER_SYNC_1
    ld [hl+], a
    ld a, PRINTER_SYNC_2
    ld [hl+], a
    
    ; Comando STATUS
    ld a, PRINTER_STATUS
    ld [hl+], a
    
    ; Compresión desactivada
    xor a
    ld [hl+], a
    
    ; Longitud de datos (0)
    ld [hl+], a
    ld [hl+], a
    
    ; Calcular checksum (solo de los 4 bytes de comando+datos)
    ld hl, PrinterPacket+2  ; Saltar bytes de sincronización
    ld bc, 4                ; Checksumear comando + compresión + longitud
    call CalculateChecksum
    
    ; Guardar checksum al final del paquete
    ld hl, PrinterPacket+6
    ld [hl], c      ; Byte bajo del checksum
    inc hl
    ld [hl], b      ; Byte alto del checksum
    
    ; Enviar paquete (8 bytes: 2 sync + 4 comando + 2 checksum)
    ld hl, PrinterPacket
    ld bc, 8
    call SendToPrinter
    jr nz, .status_error
    
    ; Esperar y recibir respuesta (6 bytes: 2 sync + 3 estado + 1 checksum)
    ld bc, 6
    ld de, PrinterResponse
    call ReceiveFromPrinter
    jr nz, .status_error
    
    ; Verificar bytes de sincronización
    ld a, [PrinterResponse]
    cp PRINTER_SYNC_1
    jr nz, .status_error
    
    ld a, [PrinterResponse+1]
    cp PRINTER_SYNC_2
    jr nz, .status_error
    
    ; Leer byte de estado (tercer byte después de la sincronización)
    ld a, [PrinterResponse+4]  ; Status byte está en la posición 4
    
    ; Verificar si hay error de papel, batería, temperatura, etc.
    and $F0         ; Máscara para bits de error
    jr nz, .status_error
    
    ; Todo bien, devolver READY
    ld a, PRINTER_READY
    jr .status_done
    
.status_error:
    ; Devolver error
    ld a, PRINTER_ERROR
    
.status_done:
    pop hl
    pop de
    pop bc
    ret

; SendToPrinter: Envía datos a la impresora
; Entrada: HL = puntero a datos, BC = longitud
; Salida: Z=1 si OK, Z=0 si error
SendToPrinter:
    push af
    push de
    
.send_loop:
    ; Verificar si quedan bytes por enviar
    ld a, b
    or c
    jr z, .send_done
    
    ; Enviar byte actual
    ld a, [hl+]
    call SendByte
    jr nz, .send_error
    
    ; Decrementar contador
    dec bc
    jr .send_loop
    
.send_done:
    ; Todo enviado correctamente
    xor a           ; Establecer Z=1
    jr .send_end
    
.send_error:
    ; Error de envío
    or 1            ; Establecer Z=0
    
.send_end:
    pop de
    pop af
    ret

; ReceiveFromPrinter: Recibe datos de la impresora
; Entrada: BC = longitud máxima, DE = buffer destino
; Salida: Z=1 si OK, Z=0 si error
ReceiveFromPrinter:
    push af
    push hl
    
    ; Guardar puntero a buffer
    ld h, d
    ld l, e
    
.recv_loop:
    ; Verificar si quedan bytes por recibir
    ld a, b
    or c
    jr z, .recv_done
    
    ; Recibir byte
    call ReceiveByte
    jr nz, .recv_error
    
    ; Guardar byte en el buffer
    ld [hl+], a
    
    ; Decrementar contador
    dec bc
    jr .recv_loop
    
.recv_done:
    ; Todo recibido correctamente
    xor a           ; Establecer Z=1
    jr .recv_end
    
.recv_error:
    ; Error de recepción
    or 1            ; Establecer Z=0
    
.recv_end:
    pop hl
    pop af
    ret

; SendByte: Envía un byte por el puerto serie
; Entrada: A = byte a enviar
; Salida: Z=1 si OK, Z=0 si timeout
SendByte:
    push bc
    push hl
    
    ; Enviar byte
    ld [rSB], a
    ld a, $81        ; Iniciar transferencia (internal clock)
    ld [rSC], a
    
    ; Esperar que termine la transferencia
    ld bc, PRINTER_TIMEOUT
.wait_send:
    ld a, [rSC]
    bit 7, a         ; Comprobar bit de transferencia en curso
    jr z, .send_ok   ; Si es 0, transferencia completada
    
    ; Decrementar contador de timeout
    dec bc
    ld a, b
    or c
    jr nz, .wait_send
    
    ; Timeout, error
    or 1             ; Establecer Z=0
    jr .send_end
    
.send_ok:
    ; Pequeña pausa para dar tiempo a la impresora
    ld bc, 20
.delay:
    dec bc
    ld a, b
    or c
    jr nz, .delay
    
    ; Transferencia exitosa
    xor a            ; Establecer Z=1
    
.send_end:
    pop hl
    pop bc
    ret

; ReceiveByte: Recibe un byte del puerto serie
; Salida: A = byte recibido, Z=1 si OK, Z=0 si timeout
ReceiveByte:
    push bc
    push de
    push hl
    
    ; Preparar para recibir
    xor a
    ld [rSB], a
    ld a, $80        ; Modo recepción
    ld [rSC], a
    
    ; Esperar datos o timeout
    ld bc, PRINTER_TIMEOUT
.wait_receive:
    ld a, [rSC]
    bit 7, a         ; Comprobar bit de transferencia en curso
    jr z, .receive_ok
    
    ; Decrementar contador timeout
    dec bc
    ld a, b
    or c
    jr nz, .wait_receive
    
    ; Timeout ocurrido
    ld a, $FF        ; Valor de error
    or a             ; Establecer Z=0
    jr .receive_end
    
.receive_ok:
    ; Leer byte recibido
    ld a, [rSB]
    cp a             ; Establecer Z=1
    
.receive_end:
    pop hl
    pop de
    pop bc
    ret

; CalculateChecksum: Calcula el checksum de un bloque de datos
; Entrada: HL = inicio de datos, BC = longitud
; Salida: BC = checksum (B = alto, C = bajo)
CalculateChecksum:
    push af
    push de
    push hl
    
    ; Inicializar checksum
    ld de, 0
    
.checksum_loop:
    ; Verificar si quedan bytes
    ld a, b
    or c
    jr z, .checksum_done
    
    ; Añadir byte actual a checksum
    ld a, [hl+]
    add e
    ld e, a
    
    ; Propagar carry
    ld a, d
    adc 0
    ld d, a
    
    ; Decrementar contador
    dec bc
    jr .checksum_loop
    
.checksum_done:
    ; Convertir DE a BC
    ld b, d
    ld c, e
    
    pop hl
    pop de
    pop af
    ret

; --- Rutinas para preparar e imprimir datos ---

; PrinterSendInit: Envía comando de inicialización
; Salida: Z=1 si OK, Z=0 si error
PrinterSendInit:
    push af
    push bc
    push de
    push hl
    
    ; Preparar paquete
    ld hl, PrinterPacket
    
    ; Cabecera de sincronización
    ld a, PRINTER_SYNC_1
    ld [hl+], a
    ld a, PRINTER_SYNC_2
    ld [hl+], a
    
    ; Comando INIT
    ld a, PRINTER_INIT
    ld [hl+], a
    
    ; Compresión desactivada
    xor a
    ld [hl+], a
    
    ; Longitud de datos (0)
    ld [hl+], a
    ld [hl+], a
    
    ; Calcular checksum
    ld hl, PrinterPacket+2  ; Saltar bytes de sincronización
    ld bc, 4                ; Checksumear comando + compresión + longitud
    call CalculateChecksum
    
    ; Guardar checksum al final del paquete
    ld hl, PrinterPacket+6
    ld [hl], c      ; Byte bajo del checksum
    inc hl
    ld [hl], b      ; Byte alto del checksum
    
    ; Enviar paquete completo
    ld hl, PrinterPacket
    ld bc, 8         ; 2 sync + 4 comando + 2 checksum
    call SendToPrinter
    jr nz, .send_error
    
    ; Esperar respuesta (ignoramos contenido)
    ld bc, 6         ; 2 sync + 3 estado + 1 checksum
    ld de, PrinterResponse
    call ReceiveFromPrinter
    
.send_error:
    ; El flag Z ya está configurado por SendToPrinter o ReceiveFromPrinter
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; PrepareQRPrintBuffer: Rellena el buffer con datos del QR
; Modifica: AF, BC, DE, HL
PrepareQRPrintBuffer:
    push af
    push bc
    push de
    push hl
    
    ; Inicializar buffer con ceros (blanco)
    ld hl, PrintBuffer
    ld bc, QR_TILES_WIDTH * QR_TILES_HEIGHT * 16  ; 16 bytes por tile
    xor a
.clear_loop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .clear_loop
    
    ; Crear imagen del QR a partir de la matriz de datos
    ; Convertir la matriz QR a tiles de 8x8 para la impresora
    call ConvertQRToTiles
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; ConvertQRToTiles: Convierte matriz QR a formato de tiles para impresora
; Modifica: AF, BC, DE, HL
ConvertQRToTiles:
    push af
    push bc
    push de
    push hl
    
    ; QR_SIZE es 21x21 píxeles, pero lo escalamos a la impresora
    ; Cada celda del QR se convierte en un cuadrado de 3x3 píxeles
    
    ; Recorrer la matriz QR
    ld b, 0      ; Contador Y
.row_loop:
    ld c, 0      ; Contador X
.col_loop:
    ; Obtener valor de celda: HL = QR_Matrix + y * QR_SIZE + x
    push bc
    
    ; Calcular offset en la matriz QR: 
    ; offset = y * QR_SIZE + x
    ld h, 0
    ld l, b
    ld de, QR_SIZE
    call MultiplyHLByDE   ; HL = y * QR_SIZE
    
    ld a, l
    add c
    ld l, a
    ld a, h
    adc 0
    ld h, a                ; HL += x
    
    ; Añadir dirección base de matriz QR
    ld de, QR_Matrix
    add hl, de
    
    ; Leer valor de celda
    ld a, [hl]
    
    ; Convertir valor (0/1) a patrón para la impresora
    ; 0 = blanco, 1 = negro
    push af
    
    ; Convertir coordenadas QR a coordenadas de tile en el buffer
    pop af
    pop bc
    
    ; Decidir si dibujar un bloque negro o blanco
    cp 0
    jr z, .skip_pixel      ; Si es 0 (blanco), no hacer nada
    
    ; Dibujar un bloque negro (3x3 píxeles) en buffer de impresora
    push bc
    call DrawQRPixelBlock
    pop bc
    
.skip_pixel:
    ; Siguiente columna
    inc c
    ld a, c
    cp QR_SIZE
    jr c, .col_loop
    
    ; Siguiente fila
    inc b
    ld a, b
    cp QR_SIZE
    jr c, .row_loop
    
    pop hl
    pop de
    pop bc
    pop af
    ret

; DrawQRPixelBlock: Dibuja un bloque de 3x3 píxeles negros para un punto QR
; Entrada: B = y, C = x en matriz QR
; Modifica: AF, DE, HL
DrawQRPixelBlock:
    push af
    push bc
    push de
    
    ; Calcular coordenadas escaladas en el buffer (3x3)
    ; Cada celda QR se convierte en 3x3 píxeles
    ld a, b
    add a
    add b            ; A = y * 3
    ld d, a          ; D = y * 3
    
    ld a, c
    add a
    add c            ; A = x * 3
    ld e, a          ; E = x * 3
    
    ; Tenemos que convertir coordenadas de píxel a posición en buffer de tiles
    ; Cada tile es 8x8 píxeles
    
    ; Calcular tile y offset dentro del tile
    ; Tile Y = píxel Y / 8
    ; Tile X = píxel X / 8
    ; Offset Y = píxel Y % 8
    ; Offset X = píxel X % 8
    
    ; Tile Y = D / 8
    ld a, d
    srl a
    srl a
    srl a
    ld h, a
    
    ; Tile X = E / 8
    ld a, e
    srl a
    srl a
    srl a
    ld l, a
    
    ; Offset Y = D % 8
    ld a, d
    and %00000111
    ld b, a
    
    ; Offset X = E % 8
    ld a, e
    and %00000111
    ld c, a
    
    ; Calcular offset en el buffer de tiles
    ; Offset = (Tile Y * QR_TILES_WIDTH + Tile X) * 16
    push hl
    ld d, 0
    ld e, h
    ld h, 0
    ld l, QR_TILES_WIDTH
    call MultiplyHLByDE   ; HL = Tile Y * QR_TILES_WIDTH
    
    pop de
    ld d, 0            ; DE = Tile X
    add hl, de         ; HL = Tile Y * QR_TILES_WIDTH + Tile X
    
    ; Multiplicar por 16 bytes por tile
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl         ; HL *= 16
    
    ; Añadir dirección base del buffer
    ld de, PrintBuffer
    add hl, de         ; HL = PrintBuffer + (Tile Y * QR_TILES_WIDTH + Tile X) * 16
    
    ; Añadir offset dentro del tile
    ; Cada línea del tile son 2 bytes
    ld a, b            ; A = Offset Y
    add a              ; A *= 2
    ld d, 0
    ld e, a
    add hl, de         ; HL += Offset Y * 2
    
    ; Ahora HL apunta a los 2 bytes del tile donde está nuestro píxel
    ; Necesitamos activar el bit correspondiente al Offset X
    ld a, c            ; A = Offset X
    
    ; Convertir Offset X a máscara de bit (7-OffsetX para invertir dirección)
    ld b, 7
    sub b
    neg                ; A = 7 - Offset X
    
    ; Crear máscara de bit
    ld b, 1
.shift_loop:
    or a
    jr z, .got_mask
    sla b
    dec a
    jr .shift_loop
    
.got_mask:
    ; B ahora contiene la máscara de bit (00000001 << (7-OffsetX))
    ; Activar el bit en el byte del tile
    ld a, [hl]
    or b
    ld [hl], a
    
    ; Dibujar los 9 píxeles (3x3) que forman el bloque
    ; Esto requeriría repetir este proceso para los 9 píxeles
    ; Por simplicidad, solo dibujamos el pixel central aquí
    
    pop de
    pop bc
    pop af
    ret

; PrinterSendQRData: Envía datos del QR a la impresora
; Salida: Z=1 si OK, Z=0 si error
PrinterSendQRData:
    push af
    push bc
    push de
    push hl
    
    ; Calcular tamaño total de datos
    ld bc, QR_TILES_WIDTH * QR_TILES_HEIGHT * 16  ; 16 bytes por tile
    
    ; Inicializar puntero a buffer
    ld hl, PrintBuffer
    
    ; Contador de bloques
    ld d, 0
    
.send_block_loop:
    ; Verificar si quedan datos
    ld a, b
    or c
    jr z, .send_complete
    
    ; Determinar tamaño de este bloque (máximo DATA_PACKET_SIZE)
    push hl
    
    ; Si bc > DATA_PACKET_SIZE, enviar DATA_PACKET_SIZE bytes
    ld hl, DATA_PACKET_SIZE
    call CompareBCWithHL    ; Compara BC con HL
    pop hl
    
    jr nc, .block_fits      ; Si BC <= HL, el bloque cabe completo
    
    ; Bloque más grande que DATA_PACKET_SIZE, limitamos
    ld a, DATA_PACKET_SIZE & $FF
    ld e, a
    ld a, DATA_PACKET_SIZE >> 8
    ld d, a
    jr .got_block_size
    
.block_fits:
    ; El bloque cabe completo
    ld e, c
    ld d, b
    
.got_block_size:
    ; DE = tamaño de este bloque
    
    ; Preparar cabecera
    push bc
    push de
    push hl
    
    ld hl, PrinterPacket
    
    ; Cabecera de sincronización
    ld a, PRINTER_SYNC_1
    ld [hl+], a
    ld a, PRINTER_SYNC_2
    ld [hl+], a
    
    ; Comando DATA
    ld a, PRINTER_DATA
    ld [hl+], a
    
    ; Compresión desactivada
    xor a
    ld [hl+], a
    
    ; Longitud de datos
    ld a, e            ; Byte bajo
    ld [hl+], a
    ld a, d            ; Byte alto
    ld [hl+], a
    
    pop hl              ; Recuperar puntero a datos
    pop de              ; Recuperar tamaño de bloque
    
    ; Copiar datos del buffer al paquete
    push hl
    ld hl, PrinterPacket + HEADER_SIZE  ; Saltar cabecera
    ex de, hl           ; DE = destino, HL = tamaño
    pop bc              ; BC = origen (antes en HL)
    
    ; Copiar BC -> DE, longitud = HL
    ld a, h
    ld h, b
    ld b, a
    ld a, l
    ld l, c
    ld c, a             ; Intercambiar HL y BC
    
    ; Ahora HL = origen, BC = longitud, DE = destino
    ; Copiar datos
.copy_loop:
    ld a, b
    or c
    jr z, .copy_done
    
    ld a, [hl+]
    ld [de], a
    inc de
    
    dec bc
    jr .copy_loop
    
.copy_done:
    ; Calcular checksum solo de los datos + cabecera (sin sync)
    push de             ; Guardar puntero final
    
    ld hl, PrinterPacket + 2  ; Saltar bytes de sincronización
    ld bc, HEADER_SIZE - 2 + DATA_PACKET_SIZE  ; Cabecera + datos
    call CalculateChecksum
    
    pop hl              ; HL = puntero al final de datos
    
    ; Añadir checksum
    ld [hl], c          ; Checksum byte bajo
    inc hl
    ld [hl], b          ; Checksum byte alto
    
    ; Enviar paquete completo
    ld hl, PrinterPacket
    ld bc, HEADER_SIZE + DATA_PACKET_SIZE + FOOTER_SIZE
    call SendToPrinter
    jr nz, .send_error
    
    ; Esperar respuesta (ignoramos contenido)
    ld bc, 6            ; 2 sync + 3 estado + 1 checksum
    ld de, PrinterResponse
    call ReceiveFromPrinter
    jr nz, .send_error
    
    ; Verificar estado en respuesta
    ld a, [PrinterResponse+4]  ; Status byte
    cp PRINTER_READY
    jr nz, .send_error
    
    ; Actualizar punteros y contadores para siguiente bloque
    pop bc              ; Recuperar contador de bytes restantes
    
    ; Restar longitud enviada
    ld a, c
    sub e
    ld c, a
    ld a, b
    sbc d
    ld b, a
    
    ; Actualizar puntero a datos
    ld a, h
    add d
    ld h, a
    ld a, l
    add e
    ld l, a
    
    ; Incrementar contador de bloques
    inc d
    
    ; Pequeña pausa entre bloques
    push bc
    push hl
    ld bc, 100
.pause_loop:
    dec bc
    ld a, b
    or c
    jr nz, .pause_loop
    pop hl
    pop bc
    
    jr .send_block_loop
    
.send_complete:
    ; Todos los bloques enviados correctamente
    xor a             ; Z=1
    jr .done
    
.send_error:
    ; Error de envío
    or 1              ; Z=0
    
.done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; PrinterSendPrint: Envía comando de impresión
; Salida: Z=1 si OK, Z=0 si error
PrinterSendPrint:
    push af
    push bc
    push de
    push hl
    
    ; Preparar paquete
    ld hl, PrinterPacket
    
    ; Cabecera de sincronización
    ld a, PRINTER_SYNC_1
    ld [hl+], a
    ld a, PRINTER_SYNC_2
    ld [hl+], a
    
    ; Comando PRINT
    ld a, PRINTER_PRINT
    ld [hl+], a
    
    ; Compresión desactivada
    xor a
    ld [hl+], a
    
    ; Longitud de datos (1 byte para configuración de margen)
    ld a, 1
    ld [hl+], a
    xor a
    ld [hl+], a
    
    ; Datos (1 byte): configuración de márgenes
    ld a, PRINTER_MARGINS
    ld [hl+], a
    
    ; Calcular checksum
    ld hl, PrinterPacket+2  ; Saltar bytes de sincronización
    ld bc, 5                ; 4 bytes cabecera + 1 byte datos
    call CalculateChecksum
    
    ; Guardar checksum
    ld hl, PrinterPacket+7
    ld [hl], c              ; Byte bajo
    inc hl
    ld [hl], b              ; Byte alto
    
    ; Enviar paquete
    ld hl, PrinterPacket
    ld bc, 9                ; 2 sync + 4 comando + 1 datos + 2 checksum
    call SendToPrinter
    jr nz, .print_error
    
    ; Esperar respuesta
    ld bc, 6                ; 2 sync + 3 estado + 1 checksum
    ld de, PrinterResponse
    call ReceiveFromPrinter
    jr nz, .print_error
    
    ; Verificar estado
    ld a, [PrinterResponse+4]
    cp PRINTER_READY
    jr nz, .print_error
    
    ; Impresión exitosa
    xor a                  ; Z=1
    jr .print_done
    
.print_error:
    ; Error de impresión
    or 1                   ; Z=0
    
.print_done:
    pop hl
    pop de
    pop bc
    pop af
    ret

; CompareBCWithHL: Compara BC con HL
; Salida: Carry=1 si BC > HL, Carry=0 si BC <= HL
CompareBCWithHL:
    ; Comparar bytes altos
    ld a, b
    cp h
    ret nz                ; Si B != H, devuelve resultado de comparación
    
    ; Si B == H, comparar bytes bajos
    ld a, c
    cp l
    ret

; MultiplyHLByDE: Multiplica HL por DE
; Entrada: HL, DE = multiplicando y multiplicador
; Salida: HL = resultado
MultiplyHLByDE:
    push bc
    
    ld b, h
    ld c, l        ; BC = HL (original)
    ld hl, 0       ; HL = 0 (acumulador)
    
    ; Si DE es 0, el resultado es 0
    ld a, d
    or e
    jr z, .multiply_done
    
    ; Si BC es 0, el resultado es 0
    ld a, b
    or c
    jr z, .multiply_done
    
.multiply_loop:
    ; Sumar BC a HL tantas veces como indique DE
    add hl, bc
    
    ; Decrementar DE
    dec de
    ld a, d
    or e
    jr nz, .multiply_loop
    
.multiply_done:
    pop bc
    ret

; --- Rutinas de UI ---

; DrawPrinterScreen: Dibuja la pantalla de impresión
DrawPrinterScreen:
    ; Limpiar pantalla
    call ClearScreen
    
    ; Dibujar caja
    ld a, 1   ; x
    ld b, 1   ; y
    ld c, 18  ; width
    ld d, 16  ; height
    call DrawBox
    
    ; Dibujar título
    ld hl, PrinterTitle
    ld c, 1   ; box_x
    ld d, 1   ; box_y
    ld e, 18  ; box_width
    call PrintInBox
    
    ; Mostrar mensaje "Preparando..."
    ld hl, PrinterPreparing
    ld d, 5   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Mostrar mensaje de espera
    ld hl, PrinterWait
    ld d, 7   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; ShowPrintSuccess: Muestra mensaje de impresión exitosa
ShowPrintSuccess:
    ; Limpiar área de mensaje
    ld d, 5   ; y
    ld e, 3   ; x
    ld b, 15  ; longitud
    call ClearLine
    
    ; Mostrar mensaje de éxito
    ld hl, PrinterSuccess
    ld d, 5   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; ShowPrinterError: Muestra mensaje de error de impresora
ShowPrinterError:
    ; Limpiar área de mensaje
    ld d, 5   ; y
    ld e, 3   ; x
    ld b, 15  ; longitud
    call ClearLine
    
    ; Mostrar mensaje de error
    ld hl, PrinterError
    ld d, 5   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Mostrar instrucciones
    ld hl, PrinterErrorHelp
    ld d, 7   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; ShowNoDataError: Muestra mensaje de error "No hay datos"
ShowNoDataError:
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
    ld hl, NoDataMsg
    ld d, 7   ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ret

; WaitButtonB: Espera hasta que se presione el botón B
WaitButtonB:
    ; Mostrar instrucción
    ld hl, PressButtonB
    ld d, 14  ; y
    ld e, 3   ; x
    call PrintStringAtXY
    
    ; Guardar estado actual
    ld a, [JoyState]
    ld [JoyPrevState], a
    
.wait_loop:
    ; Leer joypad
    call ReadJoypad
    ld a, [JoyState]
    
    ; Comprobar si se ha pulsado B
    bit 5, a  ; PADB_B = 5
    jr z, .wait_loop
    
    ; Comprobar si es un cambio de estado
    ld b, a
    ld a, [JoyPrevState]
    bit 5, a
    jr nz, .update_prev  ; Si ya estaba pulsado, no es un nuevo pulso
    
    ; Reproducir sonido
    call PlayBeepNav
    
    ; Salir
    ret
    
.update_prev:
    ; Actualizar estado previo
    ld a, b
    ld [JoyPrevState], a
    jr .wait_loop

; ClearLine: Limpia una línea de texto en la pantalla
; Entrada: D = y, E = x inicial, B = número de caracteres a limpiar
ClearLine:
    push af
    push hl
    
    ; Calcular posición en VRAM
    ld h, 0
    ld l, d
    ld a, 32
    call MultiplyAByHL  ; HL = y * 32
    
    ld a, e
    ld e, a
    ld d, 0
    add hl, de         ; HL += x
    
    ld de, _SCRN0
    add hl, de         ; HL += _SCRN0
    
    ; Limpiar con espacios
    ld a, " "
    
.clear_loop:
    ld [hl+], a
    dec b
    jr nz, .clear_loop
    
    pop hl
    pop af
    ret

; MultiplyAByHL: Multiplica A por HL
; Entrada: A = multiplicando, HL = multiplicador
; Salida: HL = resultado
MultiplyAByHL:
    push bc
    push de
    
    ld b, a
    ld de, 0        ; DE = acumulador
    
    ; Si B o HL son 0, el resultado es 0
    ld a, b
    or a
    jr z, .mult_done
    
    ld a, h
    or l
    jr z, .mult_done
    
.loop:
    add hl, de      ; HL += DE
    dec b
    jr nz, .loop
    
.mult_done:
    pop de
    pop bc
    ret

; --- Datos y constantes ---
SECTION "PrinterData", ROM1[$5F00]
PrinterTitle:       DB "IMPRESORA GB", 0
PrinterPreparing:   DB "Preparando...", 0
PrinterWait:        DB "Espere por favor", 0
PrinterSuccess:     DB "QR impreso!", 0
PrinterError:       DB "Error impresora", 0
PrinterErrorHelp:   DB "Revise conexion", 0
ErrorTitle:         DB "ERROR", 0
NoDataMsg:          DB "No hay datos", 0
PressButtonB:       DB "B: Volver", 0

; --- Variables en WRAM ---
SECTION "PrinterVars", WRAM0[$CC00]
PrinterPacket:      DS 648  ; 2 sync + 4 header + 640 data + 2 checksum
PrinterResponse:    DS 16   ; Buffer para respuestas
PrintBuffer:        DS QR_TILES_WIDTH * QR_TILES_HEIGHT * 16  ; Buffer para tiles
JoyState:           DS 1
JoyPrevState:       DS 1
;