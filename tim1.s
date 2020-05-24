; SPDX-License-Identifier: GPL-2.0-or-later
.module TIM1

; export
.globl _tim1_setup
.globl _tim1_uev_isr
.globl _tim1_cc_isr

; external
.globl _status
.globl _bit_mask
.globl _byte_value
.globl _byte_index
.globl _tx_message
.globl _led_ticks

.area CODE

_tim1_setup:

    ; set UEV on counter overflow only
    mov   0x5250, #0x04     ; TIM1_CR1 = _BV(TIM1_CR1_URS)
    ; set auto-reload to 5 periods
    mov   0x5262, #0x13     ; TIM1_ARRH = CLUNET_ARRH(5)
    mov   0x5263, #0xff     ; TIM1_ARRL = CLUNET_ARRL(5)
    ; set TIM1_CCR3 to 2 periods (TIM1_SR1_CC3IF use as bit cost)
    mov   0x5269, #0x08     ; TIM1_CCR3H = CLUNET_CCRH(2)
    mov   0x526a, #0x00     ; TIM1_CCR3L = CLUNET_CCRL(2)
    ; TRC: source - TI1F_ED, reset timer on both TI1 edges
    mov   0x5252, #0x44     ; TIM1_SMCR = (0b100 << TIM1_SMCR_TS0) | (0b100 << TIM1_SMCR_SMS0)
    ; CC1: input/capture mode, IC1 is mapped to TI1FP1, TI1 filter by 16 clocks (1 us)
    mov   0x5258, #0x51     ; TIM1_CCMR1 = (0b0101 << TIM1_CCMR1_IC1F0) | (0b01 << TIM1_CCMR1_CC1S0)
    ; CC2: input/capture mode, IC2 is mapped to TI1FP2
    mov   0x5259, #0x02     ; TIM1_CCMR2 = (0b10 << TIM1_CCMR2_CC2S0)
    ; enable captures: CC1 - on falling-edges, CC2 - on rising-edges
    mov   0x525c, #0x13     ; TIM1_CCER1 = _BV(TIM1_CCER1_CC2E) | _BV(TIM1_CCER1_CC1P) | _BV(TIM1_CCER1_CC1E)
    ; irq: initially overflow only for interframe detection
    mov   0x5254, #0x01     ; TIM1_IER = _BV(TIM1_IER_UIE)
    ; start timer: UEV on counter overflow
    mov   0x5250, #0x05     ; TIM1_CR1 = _BV(TIM1_CR1_URS) | _BV(TIM1_CR1_CEN)
    ret

_tim1_uev_isr:
    
    btjf 0x500b, #6, 00001$ ; !CLUNET_IS_READ_FREE(). line is busy too long ->
    
    ; reset receiver/transmitter

    mov  0x5255, #0x01      ; TIM1_SR1 = _BV(TIM1_SR1_UIF)
    mov  0x5254, #0x02      ; TIM1_IER = _BV(TIM1_IER_CC1IE)
    mov  _bit_mask, #0x02   ; bit_mask = 0b10
    clr  _byte_value        ; byte_value = 0
    clr  _byte_index        ; byte_index = 0
    clr  _tx_message+255    ; checksum = 0
    
    ld   a, _status
    bcp  a, #0x11           ; CLUSR_RXNE | CLUSR_TXE
    jrne 00002$             ; start transmit condition is false ->

    ; planning transmit

    mov  0x5306, #0x01      ; TIM2_EGR = _BV(TIM2_EGR_UG)
    mov  0x5300, #0x05      ; TIM2_CR1 = _BV(TIM2_CR1_URS) | _BV(TIM2_CR1_CEN)
    mov  0x530f, #0x13      ; TIM2_ARRH = CLUNET_ARRH(CLUNET_CONFIG_PERIOD_PRE_TX)
    mov  0x5310, #0xff      ; TIM2_ARRL = CLUNET_ARRL(CLUNET_CONFIG_PERIOD_PRE_TX)
    
    ld   a, _tx_message+0
    and  a, #0x03
    ld   _byte_value, a     ; byte_value = tx_message.priority & 0b11
    
    iret

00001$:
    mov  0x5255, #0x00      ; TIM1_SR1 = 0
    mov  0x5254, #0x01      ; TIM1_IER = _BV(TIM1_IER_UIE)

00002$:
    iret

_tim1_cc_isr:

    ld    a, 0x5255                 ; flags = TIM1_SR1

    mov   0x5255, #0x00             ; TIM1_SR1 = 0
    mov   0x5254, #0x07             ; TIM1_IER = _BV(TIM1_IER_CC2IE) | _BV(TIM1_IER_CC1IE) | _BV(TIM1_IER_UIE)
    
    btjt  0x500b, #5, 00001$        ; we busy the bus. return ->
    
    btjt  _status, #0, 00003$       ; status & CLUSR_RXNE: overrun error ->

    bcp   a, #0x04                  ; flags & _BV(TIM1_SR1_CC2IF)
    jrne  00004$                    ; bus is free. dominant signal has been ->

    ; BUS IS BUSY BY ANOTHER DEVICE

    btjf  0x5300, #0, 00001$        ; !CLUNET_IS_TX_ACTIVE(). return ->

    mov   0x5306, #0x01             ; TIM2_EGR = _BV(TIM2_EGR_UG)
    mov   0x5307, #0x50             ; TIM2_CCMR1 = (0b101 << TIM2_CCMR1_OC1M0)
    mov   0x5307, #0x20             ; TIM2_CCMR1 = (0b010 << TIM2_CCMR1_OC1M0)
    mov   0x5304, #0x00             ; TIM2_SR1 = 0

    ld    a, _bit_mask
    and   a, _byte_value
    jreq  00002$                    ; bit is '1' ->

    mov   0x5311, #0x0c             ; TIM2_CCR1H = CLUNET_CCRH(3)
    mov   0x5312, #0x00             ; TIM2_CCR1L = CLUNET_CCRL(3)
    mov   0x530f, #0x0f             ; TIM2_ARRH = CLUNET_ARRH(4)
    mov   0x5310, #0xff             ; TIM2_ARRL = CLUNET_ARRL(4)
00001$:
    iret

00002$:
    mov   0x5311, #0x04             ; TIM2_CCR1H = CLUNET_CCRH(1)
    mov   0x5312, #0x00             ; TIM2_CCR1L = CLUNET_CCRL(1)
    mov   0x530f, #0x07             ; TIM2_ARRH = CLUNET_ARRH(2)
    mov   0x5310, #0xff             ; TIM2_ARRL = CLUNET_ARRL(2)
    iret

    ; # RX OVERRUN ERROR #

00003$:
    bset  _status, #1               ; status |= CLUSR_RXOV
    bset  0x500f, #4                ; ERR_LED_ON(8ms); PD_ODR |= _BV(4);
    mov   _led_ticks+1, #4          ; 8ms
    jp    00014$                    ; overrun error ->

    ; BUS IS FREE

00004$:
    btjt  0x5300, #0, 00007$        ; TIM2_CR1 & _BV(TIM2_CR1_CEN); TX =>

    ; READING BIT VALUE BY TIM1_SR1_CC3IF
    bcp   a, #0x08
    jreq  00005$
    ld    a, _bit_mask
    or    a, _byte_value            ; byte_value |= bit_mask
    jp    00006$
00005$:
    ld    a, _bit_mask
    cpl   a
    and   a, _byte_value            ; byte_value &= ~bit_mask
00006$:
    ld    _byte_value, a

00007$:
    srl   _bit_mask
    jrne  00011$                    ; not whole byte received. return ->

    ; # NEW BYTE RECEIVED #
    
    ; STORE RECEIVED BYTE TO BUFFER
    clrw  x
    ld    a, _byte_index
    ld    xl, a
    ld    a, _byte_value
    ld    (_rx_message, x), a       ; *((uint8_t *)rx_message + byte_index) = byte_value
    
    tnz   _byte_index
    jreq  00008$                    ; skip priority byte ->
    
    ; UPDATE CHECKSUM
    xor   a, _tx_message+255
    ld    xl, a
    ld    a, (crc8_table, x)
    ld    _tx_message+255, a        ; checksum = maxim_table[checksum ^ byte_value]

00008$:
    ld    a, _byte_index
    mov   _bit_mask, #0x80          ; bit_mask = 0x80
    inc   _byte_index               ; byte_index++
    cp    a, #4
    jrc   00010$                    ; byte_index < 5 =>
    jrne  00009$                    ; byte_index > 5 =>
    
    ld    a, _rx_message+2
    cp    a, #255
    jreq  00015$                    ; ERROR: SOURCE ADDRESS IS BROADCAST ->

    ld    a, _rx_message+4
    cp    a, #251
    jrnc  00015$                    ; ERROR: PAYLOAD SIZE IS TOO MUCH ->

00009$:
    ld    a, _byte_index
    sub   a, #5
    cp    a, _rx_message+4
    jrugt 00013$                    ; MESSAGE RX/TX COMPLETED =>
    
    ; # MESSAGE NOT WHOLE #

    jreq  00012$                    ; CRC BYTE =>
00010$:
    ld    a, _byte_index
    ld    xl, a
    ld    a, (_tx_message, x)
    ld    _byte_value, a            ; byte_value = *((uint8_t *)tx_message + byte_index)
00011$:
    iret
00012$:    
    mov   _byte_value, _tx_message+255
    iret

    ; # RX/TX COMPLETE #

00013$:
    btjt  0x5300, #0, 00017$        ; TIM2_CR1 & _BV(TIM2_CR1_CEN); TX =>
    tnz   _tx_message+255
    jrne  00016$                    ; ERROR: checksum is wrong =>
    
    ; # RX COMPLETE #

    bset  _status, #0               ; status |= CLUSR_RXNE
    bset  0x500f, #5                ; RX_LED_ON(8ms); PD_ODR |= _BV(5);
    mov   _led_ticks+0, #4          ; 8ms
00014$:
    bset  0x500a, #3                ; PC_ODR |= _BV(3) [IRQ_ON]
    mov   0x5254, #0x01             ; TIM1_IER = _BV(TIM1_IER_UIE)
    iret

    ; # MESSAGE ERROR #

00015$:
    btjt  0x5300, #0, 00018$        ; TIM2_CR1 & _BV(TIM2_CR1_CEN); TX =>
00016$:
    bset  _status, #2               ; status |= CLUSR_RXER
    bset  0x500f, #4                ; ERR_LED_ON(8ms); PD_ODR |= _BV(4);
    mov   _led_ticks+1, #4          ; 8ms
    jp    00014$                    ; FINAL =>

    ; # TX FINISH #

00017$:
    bset  _status, #5               ; status |= CLUSR_TXF
00018$:
    bset  _status, #4               ; status |= CLUSR_TXE
    mov   0x5300, #0x04             ; TIM2_CR1 = _BV(TIM2_CR1_URS)
    bres  0x500f, #6                ; TX_LED_OFF(); PD_ODR &= ~_BV(6);
    jp    00014$                    ; FINAL =>

.area CONST

crc8_table:

.db 0x00,0x5E,0xBC,0xE2,0x61,0x3F,0xDD,0x83,0xC2,0x9C,0x7E,0x20,0xA3,0xFD,0x1F,0x41
.db 0x9D,0xC3,0x21,0x7F,0xFC,0xA2,0x40,0x1E,0x5F,0x01,0xE3,0xBD,0x3E,0x60,0x82,0xDC
.db 0x23,0x7D,0x9F,0xC1,0x42,0x1C,0xFE,0xA0,0xE1,0xBF,0x5D,0x03,0x80,0xDE,0x3C,0x62
.db 0xBE,0xE0,0x02,0x5C,0xDF,0x81,0x63,0x3D,0x7C,0x22,0xC0,0x9E,0x1D,0x43,0xA1,0xFF
.db 0x46,0x18,0xFA,0xA4,0x27,0x79,0x9B,0xC5,0x84,0xDA,0x38,0x66,0xE5,0xBB,0x59,0x07
.db 0xDB,0x85,0x67,0x39,0xBA,0xE4,0x06,0x58,0x19,0x47,0xA5,0xFB,0x78,0x26,0xC4,0x9A
.db 0x65,0x3B,0xD9,0x87,0x04,0x5A,0xB8,0xE6,0xA7,0xF9,0x1B,0x45,0xC6,0x98,0x7A,0x24
.db 0xF8,0xA6,0x44,0x1A,0x99,0xC7,0x25,0x7B,0x3A,0x64,0x86,0xD8,0x5B,0x05,0xE7,0xB9
.db 0x8C,0xD2,0x30,0x6E,0xED,0xB3,0x51,0x0F,0x4E,0x10,0xF2,0xAC,0x2F,0x71,0x93,0xCD
.db 0x11,0x4F,0xAD,0xF3,0x70,0x2E,0xCC,0x92,0xD3,0x8D,0x6F,0x31,0xB2,0xEC,0x0E,0x50
.db 0xAF,0xF1,0x13,0x4D,0xCE,0x90,0x72,0x2C,0x6D,0x33,0xD1,0x8F,0x0C,0x52,0xB0,0xEE
.db 0x32,0x6C,0x8E,0xD0,0x53,0x0D,0xEF,0xB1,0xF0,0xAE,0x4C,0x12,0x91,0xCF,0x2D,0x73
.db 0xCA,0x94,0x76,0x28,0xAB,0xF5,0x17,0x49,0x08,0x56,0xB4,0xEA,0x69,0x37,0xD5,0x8B
.db 0x57,0x09,0xEB,0xB5,0x36,0x68,0x8A,0xD4,0x95,0xCB,0x29,0x77,0xF4,0xAA,0x48,0x16
.db 0xE9,0xB7,0x55,0x0B,0x88,0xD6,0x34,0x6A,0x2B,0x75,0x97,0xC9,0x4A,0x14,0xF6,0xA8
.db 0x74,0x2A,0xC8,0x96,0x15,0x4B,0xA9,0xF7,0xB6,0xE8,0x0A,0x54,0xD7,0x89,0x6B,0x35
