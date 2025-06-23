; hardware.inc - Definiciones de registros y constantes de hardware para Game Boy
; Versión 3.0 - Actualizado para DMG Cold Wallet

; VRAM adicional para soportar Game Boy Color
IF !DEF(HARDWARE_INC)
HARDWARE_INC = 1

; Cartridge type flags
CART_ROM              EQU $00
CART_ROM_MBC1         EQU $01
CART_ROM_MBC1_RAM     EQU $02
CART_ROM_MBC1_RAM_BAT EQU $03
CART_ROM_MBC2         EQU $05
CART_ROM_MBC2_BAT     EQU $06
CART_ROM_RAM          EQU $08
CART_ROM_RAM_BAT      EQU $09
CART_MMM01            EQU $0B
CART_MMM01_RAM        EQU $0C
CART_MMM01_RAM_BAT    EQU $0D
CART_ROM_MBC3_BAT_RTC EQU $0F
CART_ROM_MBC3_RAM_BAT_RTC EQU $10
CART_ROM_MBC3         EQU $11
CART_ROM_MBC3_RAM     EQU $12
CART_ROM_MBC3_RAM_BAT EQU $13
CART_ROM_MBC5         EQU $19
CART_ROM_MBC5_BAT     EQU $1A
CART_ROM_MBC5_RAM_BAT EQU $1B
CART_ROM_MBC5_RUMBLE  EQU $1C
CART_ROM_MBC5_RAM_RUMBLE EQU $1D
CART_ROM_MBC5_RAM_BAT_RUMBLE EQU $1E
CART_POCKET_CAMERA    EQU $FC
CART_BANDAI_TAMA5     EQU $FD
CART_HUC3             EQU $FE
CART_HUC1_RAM_BAT     EQU $FF

; ROM size flags
ROM_32K               EQU $00 ; no ROM banking
ROM_64K               EQU $01 ; 4 banks
ROM_128K              EQU $02 ; 8 banks
ROM_256K              EQU $03 ; 16 banks
ROM_512K              EQU $04 ; 32 banks
ROM_1M                EQU $05 ; 64 banks
ROM_2M                EQU $06 ; 128 banks
ROM_4M                EQU $07 ; 256 banks
ROM_8M                EQU $08 ; 512 banks
ROM_1M1               EQU $52 ; 64 banks
ROM_1M2               EQU $53 ; 64 banks
ROM_1M3               EQU $54 ; 64 banks

; RAM size flags
RAM_NONE              EQU $00
RAM_2K                EQU $01
RAM_8K                EQU $02
RAM_32K               EQU $03
RAM_128K              EQU $04
RAM_64K               EQU $05

; License code
LICENSE_NONE          EQU $00
LICENSE_NINTENDO      EQU $01
LICENSE_CAPCOM        EQU $08
LICENSE_BANDAI        EQU $0A
LICENSE_UBISOFT       EQU $41
LICENSE_RARE          EQU $51
LICENSE_ELECTRONIC_ARTS EQU $69

; Memory Map

; ROM
SECTION "ROM Bank 0", ROM0[$0000]
SECTION "ROM Bank 1", ROMX[$4000], BANK[1]

; VRAM
SECTION "VRAM", VRAM[$8000], BANK[0]
SECTION "VRAM Bank 1", VRAM[$8000], BANK[1]

; External RAM
SECTION "WRAM", WRAM0[$C000]
SECTION "WRAM Bank 1", WRAMX[$D000], BANK[1]

; OAM
SECTION "OAM", OAM[$FE00]

; High RAM
SECTION "HRAM", HRAM[$FF80]

; Memory-mapped I/O
; JOYPAD
rP1 EQU $FF00
P1F_5 EQU %00100000 ; P15 out port
P1F_4 EQU %00010000 ; P14 out port
P1F_3 EQU %00001000 ; P13 in port
P1F_2 EQU %00000100 ; P12 in port
P1F_1 EQU %00000010 ; P11 in port
P1F_0 EQU %00000001 ; P10 in port

P1F_GET_DPAD EQU P1F_5
P1F_GET_BTN  EQU P1F_4
P1F_GET_NONE EQU P1F_4 | P1F_5

; SERIAL
rSB EQU $FF01 ; Serial transfer data
rSC EQU $FF02 ; Serial Transfer Control
SCF_START EQU %10000000 ; Transfer Start Flag (1=Transfer in progress, or requested)
SCF_SPEED EQU %00000010 ; Clock Speed (0=Normal, 1=Fast) ** Link Cable Only **
SCF_SOURCE EQU %00000001 ; Clock Source (0=External, 1=Internal) ** Link Cable Only **

; TIMER
rDIV EQU $FF04 ; Divider Register
rTIMA EQU $FF05 ; Timer counter
rTMA EQU $FF06 ; Timer Modulo
rTAC EQU $FF07 ; Timer Control
TACF_64KHZ EQU %00000001 ; 64KHz
TACF_256KHZ EQU %00000010 ; 256KHz

; INTERRUPT FLAGS
rIF EQU $FF0F ; Interrupt Flag
rIE EQU $FFFF ; Interrupt Enable

; INTERRUPT FLAGS (BIT NO)
IEF_HILO   EQU 0 ; Transition from High to Low of Pin number P10-P13
IEF_SERIAL EQU 1 ; Serial I/O transfer end
IEF_TIMER  EQU 2 ; Timer Overflow
IEF_LCDC   EQU 3 ; LCDC (see STAT)
IEF_VBLANK EQU 4 ; V-Blank

; LCD
rLCDC EQU $FF40 ; LCD Control
LCDCF_OFF     EQU %00000000 ; LCD Control Operation
LCDCF_ON      EQU %10000000 ; LCD Control Operation
LCDCF_WIN9800 EQU %00000000 ; Window Tile Map Display Select
LCDCF_WIN9C00 EQU %01000000 ; Window Tile Map Display Select
LCDCF_WINOFF  EQU %00000000 ; Window Display
LCDCF_WINON   EQU %00100000 ; Window Display
LCDCF_BG8800  EQU %00000000 ; BG & Window Tile Data Select
LCDCF_BG8000  EQU %00010000 ; BG & Window Tile Data Select
LCDCF_BG9800  EQU %00000000 ; BG Tile Map Display Select
LCDCF_BG9C00  EQU %00001000 ; BG Tile Map Display Select
LCDCF_OBJ8    EQU %00000000 ; OBJ Construction
LCDCF_OBJ16   EQU %00000100 ; OBJ Construction
LCDCF_OBJOFF  EQU %00000000 ; OBJ Display
LCDCF_OBJON   EQU %00000010 ; OBJ Display
LCDCF_BGOFF   EQU %00000000 ; BG Display
LCDCF_BGON    EQU %00000001 ; BG Display

rSTAT EQU $FF41 ; LCDC Status
STATF_LYC     EQU %01000000 ; LYCEQULY Coincidence (Selectable)
STATF_MODE10  EQU %00100000 ; Mode 10 (Selectable)
STATF_MODE01  EQU %00010000 ; Mode 01 (Selectable)
STATF_MODE00  EQU %00001000 ; Mode 00 (Selectable)
STATF_LYCF    EQU %00000100 ; Coincidence Flag
STATF_HBL     EQU %00000000 ; H-Blank
STATF_VBL     EQU %00000001 ; V-Blank
STATF_OAM     EQU %00000010 ; OAM-RAM is used by system
STATF_LCD     EQU %00000011 ; Both OAM and VRAM used by system
STATF_BUSY    EQU %00000010 ; When set, VRAM access is unsafe

rSCY  EQU $FF42 ; Scroll Y
rSCX  EQU $FF43 ; Scroll X
rLY   EQU $FF44 ; LCDC Y-Coordinate
rLYC  EQU $FF45 ; LY Compare
rDMA  EQU $FF46 ; DMA Transfer and Start Address
rBGP  EQU $FF47 ; BG Palette Data
rOBP0 EQU $FF48 ; Object Palette 0 Data
rOBP1 EQU $FF49 ; Object Palette 1 Data
rWY   EQU $FF4A ; Window Y Position
rWX   EQU $FF4B ; Window X Position

; Game Boy Color registers
rKEY1 EQU $FF4D ; GBC speed switch
rVBK  EQU $FF4F ; GBC VRAM bank select
rHDMA1 EQU $FF51 ; GBC HDMA source high
rHDMA2 EQU $FF52 ; GBC HDMA source low
rHDMA3 EQU $FF53 ; GBC HDMA destination high
rHDMA4 EQU $FF54 ; GBC HDMA destination low
rHDMA5 EQU $FF55 ; GBC HDMA length/mode/start
rRP   EQU $FF56 ; GBC infrared port
rBGPI EQU $FF68 ; GBC BG palette index
rBGPD EQU $FF69 ; GBC BG palette data
rOBPI EQU $FF6A ; GBC OBJ palette index
rOBPD EQU $FF6B ; GBC OBJ palette data

; Sound
rNR10 EQU $FF10 ; Sound Channel 1, Sweep register
rNR11 EQU $FF11 ; Sound Channel 1, Sound length/wave pattern duty
rNR12 EQU $FF12 ; Sound Channel 1, Volume envelope
rNR13 EQU $FF13 ; Sound Channel 1, Frequency low
rNR14 EQU $FF14 ; Sound Channel 1, Frequency high

rNR21 EQU $FF16 ; Sound Channel 2, Sound length/wave pattern duty
rNR22 EQU $FF17 ; Sound Channel 2, Volume envelope
rNR23 EQU $FF18 ; Sound Channel 2, Frequency low
rNR24 EQU $FF19 ; Sound Channel 2, Frequency high

rNR30 EQU $FF1A ; Sound Channel 3, Sound on/off
rNR31 EQU $FF1B ; Sound Channel 3, Sound length
rNR32 EQU $FF1C ; Sound Channel 3, Select output level
rNR33 EQU $FF1D ; Sound Channel 3, Frequency low
rNR34 EQU $FF1E ; Sound Channel 3, Frequency high

rNR41 EQU $FF20 ; Sound Channel 4, Sound length
rNR42 EQU $FF21 ; Sound Channel 4, Volume envelope
rNR43 EQU $FF22 ; Sound Channel 4, Polynomial counter
rNR44 EQU $FF23 ; Sound Channel 4, Counter/consecutive; Initial

rNR50 EQU $FF24 ; Channel control / ON-OFF / Volume
rNR51 EQU $FF25 ; Sound output terminal selection
rNR52 EQU $FF26 ; Sound on/off

; SRAM enable
CART_SRAM_ENABLE  EQU $0A
CART_SRAM_DISABLE EQU $00

; Keypad
PADF_DOWN   EQU $80
PADF_UP     EQU $40
PADF_LEFT   EQU $20
PADF_RIGHT  EQU $10
PADF_START  EQU $08
PADF_SELECT EQU $04
PADF_B      EQU $02
PADF_A      EQU $01

PADB_DOWN   EQU $7
PADB_UP     EQU $6
PADB_LEFT   EQU $5
PADB_RIGHT  EQU $4
PADB_START  EQU $3
PADB_SELECT EQU $2
PADB_B      EQU $1
PADB_A      EQU $0

; Screen dimensions
SCRN_X    EQU 160 ; Width of screen in pixels
SCRN_Y    EQU 144 ; Height of screen in pixels
SCRN_X_B  EQU 20  ; Width of screen in bytes
SCRN_Y_B  EQU 18  ; Height of screen in bytes

SCRN_VX   EQU 256 ; Virtual width of screen in pixels
SCRN_VY   EQU 256 ; Virtual height of screen in pixels
SCRN_VX_B EQU 32  ; Virtual width of screen in bytes
SCRN_VY_B EQU 32  ; Virtual height of screen in bytes

; Base addresses for VRAM objects
_VRAM     EQU $8000 ; VRAM base address
_SCRN0    EQU $9800 ; BG screen 0 base address
_SCRN1    EQU $9C00 ; BG screen 1 base address
_SRAM     EQU $A000 ; SRAM base address
_RAM      EQU $C000 ; RAM base address
_OAMRAM   EQU $FE00 ; OAM base address
_HRAM     EQU $FF80 ; HRAM base address

; OAM related constants
OAM_COUNT   EQU 40  ; Number of OAM entries in OAM RAM
OAM_SIZE    EQU 4   ; Size of each OAM entry in bytes

; Color constants
BLACK       EQU %00
DARK_GRAY   EQU %01
LIGHT_GRAY  EQU %10
WHITE       EQU %11

; SRAM bank constants
SRAM_BANKS  EQU 4   ; Number of SRAM banks available
START EQU %00000100 ; Timer Start
TACF_STOP  EQU %00000000 ; Timer Stop
TACF_4KHZ  EQU %00000000 ; 4KHz
TACF_16KHZ EQU %00000011 ; 16KHz
; TACF_
