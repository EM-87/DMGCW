; sound.asm - Módulo de efectos de sonido para DMG Cold Wallet
INCLUDE "hardware.inc"

SECTION "SoundModule", ROM0[$3000]

; --- Constantes ---
; Registros de audio
NR10 EQU rNR10  ; $FF10 - Canal 1 Sweep
NR11 EQU rNR11  ; $FF11 - Canal 1 Longitud/Patrón
NR12 EQU rNR12  ; $FF12 - Canal 1 Control de volumen
NR13 EQU rNR13  ; $FF13 - Canal 1 Frecuencia baja
NR14 EQU rNR14  ; $FF14 - Canal 1 Frecuencia alta/Control

NR21 EQU rNR21  ; $FF16 - Canal 2 Longitud/Patrón
NR22 EQU rNR22  ; $FF17 - Canal 2 Control de volumen
NR23 EQU rNR23  ; $FF18 - Canal 2 Frecuencia baja
NR24 EQU rNR24  ; $FF19 - Canal 2 Frecuencia alta/Control

NR30 EQU rNR30  ; $FF1A - Canal 3 Activar/Desactivar
NR31 EQU rNR31  ; $FF1B - Canal 3 Longitud
NR32 EQU rNR32  ; $FF1C - Canal 3 Control de volumen
NR33 EQU rNR33  ; $FF1D - Canal 3 Frecuencia baja
NR34 EQU rNR34  ; $FF1E - Canal 3 Frecuencia alta/Control

NR41 EQU rNR41  ; $FF20 - Canal 4 Longitud
NR42 EQU rNR42  ; $FF21 - Canal 4 Control de volumen
NR43 EQU rNR43  ; $FF22 - Canal 4 Polinomio
NR44 EQU rNR44  ; $FF23 - Canal 4 Control

NR50 EQU rNR50  ; $FF24 - Control de volumen maestro
NR51 EQU rNR51  ; $FF25 - Selección de salida de canales
NR52 EQU rNR52  ; $FF26 - Control activación/desactivación de sonido

; --- Inicialización del sistema de sonido ---
InitSound:
    ; Encender sistema de sonido
    ld a, $80
    ld [NR52], a
    
    ; Establecer volumen maestro
    ld a, $77       ; Volumen máximo para ambos canales (L/R)
    ld [NR50], a
    
    ; Habilitar todos los canales en ambos altavoces (L/R)
    ld a, $FF
    ld [NR51], a
    
    ; Apagar todos los canales para inicializar
    xor a
    ld [NR12], a    ; Canal 1 volumen
    ld [NR22], a    ; Canal 2 volumen
    ld [NR32], a    ; Canal 3 volumen
    ld [NR42], a    ; Canal 4 volumen
    
    ; Detener todos los canales
    ld a, $80       ; Bit 7 = iniciar canal
    ld [NR14], a    ; Detener canal 1
    ld [NR24], a    ; Detener canal 2
    ld [NR34], a    ; Detener canal 3
    ld [NR44], a    ; Detener canal 4
    
    ret

; --- Efectos de sonido ---

; PlayBeepNav: Sonido para navegación de menú (click suave)
; Utiliza Canal 1 (onda cuadrada)
PlayBeepNav:
    push af
    
    ; Desactivar sweep
    ld a, $00
    ld [NR10], a
    
    ; Longitud del sonido y duty cycle (50%)
    ld a, $80
    ld [NR11], a
    
    ; Volumen y envolvente
    ld a, $72       ; Volumen inicial 7, aumentar, velocidad 2
    ld [NR12], a
    
    ; Frecuencia (tono medio-alto)
    ld a, $A0
    ld [NR13], a
    ld a, $85       ; Bit 7 = iniciar sonido, Bit 6 = uso de longitud
    ld [NR14], a
    
    pop af
    ret

; PlayBeepConfirm: Sonido para confirmación (beep ascendente)
; Utiliza Canal 2 (onda cuadrada)
PlayBeepConfirm:
    push af
    
    ; Longitud y duty cycle (50%)
    ld a, $80
    ld [NR21], a
    
    ; Volumen y envolvente
    ld a, $B0       ; Volumen inicial B, sin cambio
    ld [NR22], a
    
    ; Frecuencia (tono medio)
    ld a, $30
    ld [NR23], a
    ld a, $87       ; Bit 7 = iniciar sonido, Bit 6 = uso de longitud
    ld [NR24], a
    
    ; Pequeña pausa
    ld b, 10
.delay1:
    push bc
    call WaitVBlank
    pop bc
    dec b
    jr nz, .delay1
    
    ; Segunda nota (más alta)
    ld a, $B0       ; Volumen
    ld [NR22], a
    ld a, $50
    ld [NR23], a
    ld a, $87
    ld [NR24], a
    
    pop af
    ret

; PlayBeepError: Sonido para errores (beep descendente)
; Utiliza Canal 4 (ruido)
PlayBeepError:
    push af
    push bc
    
    ; Primera parte: ruido corto y agudo
    ; Longitud
    ld a, $1F
    ld [NR41], a
    
    ; Volumen y envolvente
    ld a, $F2       ; Volumen inicial F, decrementar, velocidad 2
    ld [NR42], a
    
    ; Características del ruido
    ld a, $51       ; Frecuencia mediana, patrón corto
    ld [NR43], a
    
    ; Iniciar sonido
    ld a, $80       ; Bit 7 = iniciar sonido
    ld [NR44], a
    
    ; Pequeña pausa
    ld b, 8
.delay1:
    push bc
    call WaitVBlank
    pop bc
    dec b
    jr nz, .delay1
    
    ; Segunda parte: ruido más grave
    ; Longitud
    ld a, $1F
    ld [NR41], a
    
    ; Volumen y envolvente
    ld a, $F3       ; Volumen inicial F, decrementar, velocidad 3
    ld [NR42], a
    
    ; Características del ruido
    ld a, $73       ; Frecuencia baja, patrón largo
    ld [NR43], a
    
    ; Iniciar sonido
    ld a, $80       ; Bit 7 = iniciar sonido
    ld [NR44], a
    
    pop bc
    pop af
    ret

; PlayStartupSound: Sonido para inicio de la aplicación
; Utiliza Canales 1 y 2
PlayStartupSound:
    push af
    push bc
    
    ; ---- Canal 1: Barrido ascendente ----
    ; Configurar sweep ascendente
    ld a, $27       ; Tiempo=2, Dirección=ascendente, Cambio=7
    ld [NR10], a
    
    ; Longitud y duty
    ld a, $80
    ld [NR11], a
    
    ; Volumen y envolvente
    ld a, $F3       ; Volumen inicial F, decrementar, velocidad 3
    ld [NR12], a
    
    ; Frecuencia base (baja)
    ld a, $00
    ld [NR13], a
    ld a, $85
    ld [NR14], a
    
    ; Pequeña pausa
    ld b, 20
.delay1:
    push bc
    call WaitVBlank
    pop bc
    dec b
    jr nz, .delay1
    
    ; ---- Canal 2: Tono final ----
    ; Longitud y duty
    ld a, $80
    ld [NR21], a
    
    ; Volumen y envolvente
    ld a, $93       ; Volumen inicial 9, decrementar, velocidad 3
    ld [NR22], a
    
    ; Frecuencia (tono alto)
    ld a, $C0
    ld [NR23], a
    ld a, $87
    ld [NR24], a
    
    pop bc
    pop af
    ret

; PlayShutdownSound: Sonido para apagado de la aplicación
; Utiliza Canales 1 y 2
PlayShutdownSound:
    push af
    push bc
    
    ; ---- Canal 1: Tono inicial ----
    ; Sin sweep
    ld a, $00
    ld [NR10], a
    
    ; Longitud y duty
    ld a, $80
    ld [NR11], a
    
    ; Volumen y envolvente
    ld a, $93       ; Volumen inicial 9, decrementar, velocidad 3
    ld [NR12], a
    
    ; Frecuencia (tono alto)
    ld a, $C0
    ld [NR13], a
    ld a, $85
    ld [NR14], a
    
    ; Pequeña pausa
    ld b, 10
.delay1:
    push bc
    call WaitVBlank
    pop bc
    dec b
    jr nz, .delay1
    
    ; ---- Canal 2: Barrido descendente ----
    ; Longitud y duty
    ld a, $80
    ld [NR21], a
    
    ; Volumen y envolvente
    ld a, $F3       ; Volumen inicial F, decrementar, velocidad 3
    ld [NR22], a
    
    ; Frecuencia (tono medio-alto)
    ld a, $00
    ld [NR23], a
    
    ; Iniciar con frecuencia alta
    ld a, $C7       ; Bit 7 = iniciar, Bit 6 = uso de longitud, Bits 0-2 = frecuencia alta
    ld [NR24], a
    
    ; Ir bajando la frecuencia manualmente
    ld b, 16
.freqLoop:
    push bc
    call WaitVBlank
    pop bc
    
    ; Decrementar frecuencia
    ld a, b
    sla a
    sla a
    sla a           ; Multiplicar por 8
    ld [NR23], a
    ld a, $87
    ld [NR24], a
    
    dec b
    jr nz, .freqLoop
    
    pop bc
    pop af
    ret