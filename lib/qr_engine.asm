; ====================================================================
; qr_engine.asm - QR Code Generation Engine for Game Boy
; ====================================================================
; Implements QR Version 1 (21x21) with Error Correction Level L
; Supports alphanumeric mode encoding
;
; Public API:
;   EncodeAlphaNumeric - Encode input string to QR format
;   BuildMatrix        - Construct QR matrix with patterns
;   ApplyMask          - Apply mask pattern to QR matrix
;   GetModule          - Get module value at (D,E) coordinates
;   PadToByte          - Pad bit buffer to byte boundary
;   PadDataBytes       - Add padding bytes to data
;
; ====================================================================

INCLUDE "hardware.inc"
INCLUDE "constants.inc"

; --- External dependencies ---
EXTERN QR_InputBuf, QR_BitBuf, QR_Matrix

; --- QR Constants ---
QR_MODE_NUMERIC       EQU 1
QR_MODE_ALPHANUMERIC  EQU 2
QR_MODE_BYTE          EQU 4

QR_V1_SIZE            EQU 21
QR_V1_CAPACITY        EQU 17
QR_V1_TOTAL           EQU 24  ; 17 data + 7 ECC

; Alphanumeric character set
ALPHANUM_CHARS: DB "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:",0

SECTION "QREngine", ROM0

; ====================================================================
; EncodeAlphaNumeric - Encode alphanumeric string to QR format
; ====================================================================
; Input:  HL = pointer to null-terminated input string (QR_InputBuf)
; Output: Carry set if data too long
;         QR_BitBuf contains encoded data
; Modifies: AF, BC, DE, HL
; ====================================================================
EncodeAlphaNumeric:
    push hl

    ; Count string length
    call .CountLength
    ld a, c
    cp QR_V1_CAPACITY + 1
    jr nc, .too_long

    ; Initialize bit buffer
    ld hl, QR_BitBuf
    ld bc, QR_V1_TOTAL
    xor a
    call .FillBytes

    pop hl
    push hl

    ; Write mode indicator (0010 for alphanumeric)
    ld hl, QR_BitBuf
    ld de, 0  ; Bit position
    ld a, QR_MODE_ALPHANUMERIC
    ld b, 4
    call .WriteBits

    ; Write character count (9 bits for V1)
    pop hl
    push hl
    call .CountLength
    ld a, c
    ld b, 9
    call .WriteBits

    ; Encode character pairs
    pop hl
.encode_loop:
    ld a, [hl]
    or a
    jr z, .encode_done

    ; Get first character value
    push hl
    call .GetAlphaValue
    jr c, .invalid_char
    ld c, a  ; Save first char value

    pop hl
    inc hl
    ld a, [hl]
    or a
    jr z, .encode_single

    ; Encode pair: value = (first * 45) + second
    push hl
    call .GetAlphaValue
    jr c, .invalid_char
    ld b, a  ; Second char value

    ; Calculate first * 45
    ld a, c
    ld h, 0
    ld l, a
    add hl, hl  ; *2
    add hl, hl  ; *4
    add hl, hl  ; *8
    ld d, h
    ld e, l     ; Save *8
    add hl, hl  ; *16
    add hl, hl  ; *32
    add hl, de  ; *32 + *8 = *40
    ld d, 0
    ld e, c
    add hl, de  ; + original = *45
    add hl, de  ; *45 + original = *45
    ld a, l
    add b       ; Add second character

    ; Write 11 bits
    ld b, 11
    call .WriteBits

    pop hl
    inc hl
    jr .encode_loop

.encode_single:
    ; Encode single character (6 bits)
    ld a, c
    ld b, 6
    call .WriteBits
    jr .encode_done

.encode_done:
    xor a  ; Success
    ret

.too_long:
    pop hl
    scf    ; Set carry = error
    ret

.invalid_char:
    pop hl
    scf
    ret

; ====================================================================
; Helper: Count string length
; Input:  HL = string pointer
; Output: C = length
; ====================================================================
.CountLength:
    ld c, 0
.count_loop:
    ld a, [hl+]
    or a
    ret z
    inc c
    jr .count_loop

; ====================================================================
; Helper: Fill bytes with value A
; Input:  HL = dest, BC = count, A = value
; ====================================================================
.FillBytes:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    ret z
    ld a, [hl]
    xor a
    jr .FillBytes

; ====================================================================
; Helper: Get alphanumeric character value (0-44)
; Input:  A = character
; Output: A = value (0-44), Carry set if invalid
; ====================================================================
.GetAlphaValue:
    push hl
    push bc
    ld b, a
    ld hl, ALPHANUM_CHARS
    ld c, 0
.search_loop:
    ld a, [hl+]
    or a
    jr z, .not_found
    cp b
    jr z, .found
    inc c
    jr .search_loop
.found:
    ld a, c
    pop bc
    pop hl
    xor a  ; Clear carry
    ret
.not_found:
    pop bc
    pop hl
    scf    ; Set carry
    ret

; ====================================================================
; Helper: Write bits to buffer
; Input:  A = value, B = bit count, DE = bit position
;         QR_BitBuf = target buffer
; Output: DE = updated bit position
; ====================================================================
.WriteBits:
    push hl
    push bc

.write_bit_loop:
    dec b
    push bc

    ; Get byte offset and bit position
    ld h, d
    ld l, e
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l  ; Divide by 8

    ld bc, QR_BitBuf
    add hl, bc

    ; Get bit to write
    pop bc
    push bc
    ld c, b
    push af
.shift_loop:
    ld a, c
    or a
    jr z, .shift_done
    pop af
    srl a
    push af
    dec c
    jr .shift_loop
.shift_done:
    pop af
    and $01

    ; Set bit if needed
    or a
    jr z, .skip_set
    ld a, [hl]
    or $80
    ld [hl], a
.skip_set:

    ; Increment bit position
    inc de

    pop bc
    ld a, b
    or a
    jr nz, .write_bit_loop

    pop bc
    pop hl
    ret

; ====================================================================
; PadToByte - Pad bit stream to byte boundary
; ====================================================================
; Input:  DE = current bit position
; Output: DE = padded bit position
; ====================================================================
PadToByte:
    ; Round up to next multiple of 8
    ld a, e
    and $07
    ret z  ; Already aligned

    ld a, 8
    sub a
    ld b, a  ; Bits to pad
    xor a
.pad_loop:
    call .WriteBits
    ret

; ====================================================================
; PadDataBytes - Add padding bytes to fill capacity
; ====================================================================
; Input:  None (uses QR_BitBuf)
; Output: None
; ====================================================================
PadDataBytes:
    ld hl, QR_BitBuf
    ld a, QR_V1_CAPACITY

    ; Find first unused byte
    ld b, 0
.find_loop:
    ld a, [hl]
    or a
    jr z, .found_empty
    inc hl
    inc b
    ld a, b
    cp QR_V1_CAPACITY
    jr nz, .find_loop
    ret  ; Buffer full

.found_empty:
    ; Alternate between $EC and $11
    ld c, $EC
.pad_byte_loop:
    ld a, b
    cp QR_V1_CAPACITY
    ret z
    ld a, c
    ld [hl+], a
    inc b
    ld a, c
    cp $EC
    jr nz, .use_ec
    ld c, $11
    jr .pad_byte_loop
.use_ec:
    ld c, $EC
    jr .pad_byte_loop

; ====================================================================
; BuildMatrix - Construct QR matrix with all patterns
; ====================================================================
; Input:  QR_BitBuf contains data+ECC
; Output: QR_Matrix contains QR code
; ====================================================================
BuildMatrix:
    ; Clear matrix
    ld hl, QR_Matrix
    ld bc, QR_V1_SIZE * QR_V1_SIZE
    xor a
    call .FillBytes

    ; Place finder patterns (3 corners)
    call .PlaceFinderPatterns

    ; Place timing patterns
    call .PlaceTimingPatterns

    ; Place format information
    call .PlaceFormatInfo

    ; Place data modules
    call .PlaceDataModules

    ret

; ====================================================================
; PlaceFinderPatterns - Draw 3 finder patterns
; ====================================================================
.PlaceFinderPatterns:
    ; Top-left
    ld d, 0
    ld e, 0
    call .DrawFinderPattern

    ; Top-right
    ld d, 0
    ld e, 14
    call .DrawFinderPattern

    ; Bottom-left
    ld d, 14
    ld e, 0
    call .DrawFinderPattern

    ret

.DrawFinderPattern:
    ; Draw 7x7 finder pattern at (D,E)
    push de
    ld b, 7
.fp_row:
    push bc
    ld c, 7
.fp_col:
    push bc
    push de

    ; Determine if module should be dark
    ld a, b
    dec a
    cp 1
    jr c, .fp_dark
    cp 5
    jr nc, .fp_dark
    ld a, c
    dec a
    cp 1
    jr c, .fp_dark
    cp 5
    jr nc, .fp_dark

    ; Check if in center (3,3)
    ld a, b
    cp 4
    jr nz, .fp_white
    ld a, c
    cp 4
    jr nz, .fp_white

.fp_dark:
    ld a, 1
    jr .fp_set
.fp_white:
    xor a
.fp_set:
    call .SetModule

    pop de
    pop bc
    inc e
    dec c
    jr nz, .fp_col

    pop bc
    pop de
    push de
    inc d
    dec b
    jr nz, .fp_row

    pop de
    ret

; ====================================================================
; PlaceTimingPatterns - Draw timing patterns
; ====================================================================
.PlaceTimingPatterns:
    ld b, 8
    ld d, 6  ; Row 6
.timing_h:
    ld e, b
    ld a, b
    and $01
    call .SetModule
    inc b
    ld a, b
    cp 13
    jr nz, .timing_h

    ld b, 8
    ld e, 6  ; Col 6
.timing_v:
    ld d, b
    ld a, b
    and $01
    call .SetModule
    inc b
    ld a, b
    cp 13
    jr nz, .timing_v

    ret

; ====================================================================
; PlaceFormatInfo - Place format information
; ====================================================================
.PlaceFormatInfo:
    ; Format info for Level L, Mask 0: 01000010001010000
    ; This is simplified - normally calculated from ECC level and mask
    ld hl, .FormatBits
    ld b, 15

.format_loop:
    ld a, [hl+]
    push hl
    push bc

    ; Place in two locations (simplified)
    ld d, 8
    ld a, b
    cp 9
    jr c, .format_top
    sub 9
    ld d, a
    ld e, 8
    jr .format_place
.format_top:
    ld e, b

.format_place:
    ld a, [hl]
    call .SetModule

    pop bc
    pop hl
    dec b
    jr nz, .format_loop

    ret

.FormatBits:
    DB 0,1,0,0,0,0,1,0,0,0,1,0,1,0,0  ; Format for Level L, Mask 0

; ====================================================================
; PlaceDataModules - Place data and ECC in matrix
; ====================================================================
.PlaceDataModules:
    ld hl, QR_BitBuf
    ld b, 0  ; Byte counter

.data_byte_loop:
    ld a, b
    cp QR_V1_TOTAL
    ret z

    ld a, [hl+]
    push hl
    ld c, a  ; Current byte
    ld d, 8  ; Bit counter

.data_bit_loop:
    ; Simplified zigzag placement
    ; This should be replaced with proper zigzag algorithm
    push bc
    ld a, c
    and $80
    srl a
    srl a
    srl a
    srl a
    srl a
    srl a
    srl a  ; Get top bit

    ; Calculate position (simplified)
    ld d, b
    ld e, b
    call .SetModule

    pop bc
    sla c  ; Shift to next bit
    dec d
    jr nz, .data_bit_loop

    pop hl
    inc b
    jr .data_byte_loop

; ====================================================================
; SetModule - Set module value at (D,E) coordinates
; ====================================================================
; Input:  D = row (0-20), E = col (0-20), A = value (0 or 1)
; ====================================================================
.SetModule:
    push hl
    push de
    push bc
    push af

    ; Calculate offset: row * 21 + col
    ld a, d
    ld h, 0
    ld l, a
    ld b, h
    ld c, l
    add hl, hl  ; *2
    add hl, hl  ; *4
    add hl, bc  ; *5
    add hl, hl  ; *10
    add hl, hl  ; *20
    add hl, bc  ; *21

    ld b, 0
    ld c, e
    add hl, bc

    ld bc, QR_Matrix
    add hl, bc

    pop af
    ld [hl], a

    pop bc
    pop de
    pop hl
    ret

; ====================================================================
; ApplyMask - Apply mask pattern to data modules
; ====================================================================
; Input:  A = mask pattern (0-7)
; ====================================================================
ApplyMask:
    ; Mask 0: (row + col) mod 2 == 0
    ld b, 0  ; Row
.mask_row:
    ld c, 0  ; Col
.mask_col:
    ; Skip function patterns (simplified)
    ld a, b
    cp 9
    jr c, .mask_skip
    ld a, c
    cp 9
    jr c, .mask_skip

    ; Calculate mask condition
    ld a, b
    add c
    and $01
    jr nz, .mask_skip

    ; Toggle module
    push bc
    ld d, b
    ld e, c
    call GetModule
    xor $01
    ld d, b
    ld e, c
    call .SetModule
    pop bc

.mask_skip:
    inc c
    ld a, c
    cp QR_V1_SIZE
    jr nz, .mask_col

    inc b
    ld a, b
    cp QR_V1_SIZE
    jr nz, .mask_row

    ret

; ====================================================================
; GetModule - Get module value at coordinates
; ====================================================================
; Input:  D = row (0-20), E = col (0-20)
; Output: A = module value (0 or 1)
; ====================================================================
GetModule:
    push hl
    push de
    push bc

    ; Calculate offset: row * 21 + col
    ld a, d
    ld h, 0
    ld l, a
    ld b, h
    ld c, l
    add hl, hl  ; *2
    add hl, hl  ; *4
    add hl, bc  ; *5
    add hl, hl  ; *10
    add hl, hl  ; *20
    add hl, bc  ; *21

    ld b, 0
    ld c, e
    add hl, bc

    ld bc, QR_Matrix
    add hl, bc

    ld a, [hl]

    pop bc
    pop de
    pop hl
    ret
