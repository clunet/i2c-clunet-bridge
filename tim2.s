; SPDX-License-Identifier: GPL-2.0-or-later
.module TIM2

; export
.globl _tim2_setup
.globl _tim2_uev_isr

; external
.globl _status
.globl _bit_mask
.globl _byte_value

.area CODE

_tim2_setup:

    ; set timer UEV on counter overflow only
    mov   0x5300, #0x04         ; TIM2_CR1 = _BV(TIM2_CR1_URS)
    ; PC5[TIM2_CH1]: output compare mode, active high
    mov   0x530a, #0x01         ; TIM2_CCER1 = _BV(TIM2_CCER1_CC1E)
    ; enable overflow irq
    mov   0x5303, #0x01         ; TIM2_IER = _BV(TIM2_IER_UIE)
    ret

_tim2_uev_isr:

    mov   0x5304, #0x00         ; TIM2_SR1 = 0;
    
    btjf  0x500b, #6, 00002$    ; !CLUNET_IS_READ_FREE(). collision ->
    
    mov   0x5307, #0x50         ; TIM2_CCMR1 = (0b101 << TIM2_CCMR1_OC1M0)
    mov   0x5307, #0x20         ; TIM2_CCMR1 = (0b010 << TIM2_CCMR1_OC1M0)
    
    ld    a, _bit_mask
    bcp   a, _byte_value        ; byte_value & bit_mask
    jreq  00001$                ; bit is '0' ->

    ; bit is '1'
    mov   0x5311, #0x0c         ; TIM2_CCR1H = CLUNET_CCRH(3)
    mov   0x5312, #0x00         ; TIM2_CCR1L = CLUNET_CCRL(3)
    mov   0x530f, #0x0f         ; TIM2_ARRH = CLUNET_ARRH(4)
    mov   0x5310, #0xff         ; TIM2_ARRL = CLUNET_ARRL(4)
    iret

00001$:
    ; bit is '0'
    mov   0x5311, #0x04         ; TIM2_CCR1H = CLUNET_CCRH(1)
    mov   0x5312, #0x00         ; TIM2_CCR1L = CLUNET_CCRL(1)
    mov   0x530f, #0x07         ; TIM2_ARRH = CLUNET_ARRH(2)
    mov   0x5310, #0xff         ; TIM2_ARRL = CLUNET_ARRL(2)
    iret

00002$:
    ; # TX COLLISION ERROR #
    bset  0x500a, #3            ; PC_ODR |= _BV(3) [IRQ ON]
    mov   0x5300, #0x04         ; TIM2_CR1 = _BV(TIM2_CR1_URS)
    bset  _status, #6           ; CLUSR_TXC

    ; ERR_LED_ON(8ms)
    bset  0x500f, #4            ; PD_ODR |= _BV(4)
    mov   _led_ticks+1, #4      ; 8ms

    iret
