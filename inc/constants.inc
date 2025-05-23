; constants.inc - Definiciones globales para DMG Cold Wallet

; --- Constantes del sistema ---
MAX_LOG_ENTRIES    EQU 5      ; Máximo de entradas en el log de transacciones
TX_LOG_LEN         EQU 32     ; Longitud de cada entrada de log
MAX_WALLETS        EQU 5      ; Número máximo de wallets almacenados
WALLET_NAME_LEN    EQU 12     ; Longitud máxima de nombre de wallet
WALLET_ADDR_LEN    EQU 24     ; Longitud máxima de dirección
WALLET_DATA_LEN    EQU WALLET_NAME_LEN + WALLET_ADDR_LEN + 1

; --- Flags y estados ---
WALLET_ACTIVE      EQU 1      ; Flag de wallet activo
WALLET_DELETED     EQU 0      ; Flag de wallet eliminado
EXIT_CANCEL        EQU 0      ; Código de salida: cancelar
EXIT_CONFIRM       EQU 1      ; Código de salida: confirmar
ENTRY_NORMAL       EQU 0      ; Entrada normal a un módulo
ENTRY_NEW          EQU 1      ; Entrada nueva a un módulo (limpiar)

; --- Configuración de UX ---
DEBOUNCE_FRAMES    EQU 2      ; Frames para debounce de input
CURSOR_BLINK_RATE  EQU 30     ; Frames entre parpadeos de cursor

; --- Offsets SRAM ---
ADDR_INPUT_OFFSET    EQU 0
AMOUNT_INPUT_OFFSET  EQU (ADDR_INPUT_OFFSET + 24)
TX_LOG_OFFSET        EQU (AMOUNT_INPUT_OFFSET + 10)
TX_COUNT_OFFSET      EQU (TX_LOG_OFFSET + MAX_LOG_ENTRIES * TX_LOG_LEN)
CHECKSUM_OFFSET      EQU (TX_COUNT_OFFSET + 1)
WALLET_COUNT_OFFSET  EQU (CHECKSUM_OFFSET + 1)
WALLET_DATA_OFFSET   EQU (WALLET_COUNT_OFFSET + 1)
WALLET_CHECKSUM_OFFSET EQU (WALLET_DATA_OFFSET + (MAX_WALLETS * WALLET_DATA_LEN))

; --- Validaciones SRAM ---
; Verificar que los datos caben en la SRAM (8KB = $2000 bytes)
IF (WALLET_CHECKSUM_OFFSET + 1) > $1FFF
    FAIL "ERROR: Los datos exceden el tamaño de la SRAM (8KB)"
ENDC

; --- QR ---
QR_SIZE            EQU 21    ; Tamaño de QR Version 1 (21x21)
QR_CAPACITY        EQU 17    ; Capacidad máxima en bytes (QR V1, EC L)
QR_EC_SIZE         EQU 7     ; Tamaño error correction para EC L
MODE_ALPHANUMERIC  EQU 2     ; Modo alfanumérico

; --- Link ---
TIMEOUT_SHORT      EQU $0800  ; Timeout corto (~2048 ciclos)
TIMEOUT_LONG       EQU $8000  ; Timeout largo (~32768 ciclos)
MAX_RETRIES        EQU 3     ; Reintentos de envío
START_BYTE         EQU $A5   ; Byte de inicio de trama
ACK_BYTE           EQU $5A   ; Confirmación positiva
NACK_BYTE          EQU $FF   ; Confirmación negativa
MAX_PAYLOAD        EQU 64    ; Tamaño máximo de payload

; --- Códigos de error ---
LINK_ERR_NONE      EQU 0     ; Sin error
LINK_ERR_TIMEOUT   EQU 1     ; Error de timeout
LINK_ERR_RETRY     EQU 2     ; Error después de reintentos
LINK_ERR_LENGTH    EQU 3     ; Error de longitud
LINK_ERR_CHECKSUM  EQU 4     ; Error de checksum

; --- Bits de botones ---
BUTTON_RIGHT_BIT   EQU 0
BUTTON_LEFT_BIT    EQU 1
BUTTON_UP_BIT      EQU 2
BUTTON_DOWN_BIT    EQU 3
BUTTON_A_BIT       EQU 4
BUTTON_B_BIT       EQU 5
BUTTON_SELECT_BIT  EQU 6
BUTTON_START_BIT   EQU 7

; --- Macros útiles ---
; Verifica si un registro tiene un bit activado
; Uso: IF_BIT_SET registro, bit, etiqueta
IF_BIT_SET: MACRO
    bit \2, \1
    jr nz, \3
ENDM

; Verifica si un registro tiene un bit desactivado
; Uso: IF_BIT_RESET registro, bit, etiqueta
IF_BIT_RESET: MACRO
    bit \2, \1
    jr z, \3
ENDM

; Copia una cadena de caracteres con límite
; Uso: STRCPY origen, destino, longitud
STRCPY: MACRO
    ld hl, \1
    ld de, \2
    ld bc, \3
    call CopyString
ENDM
