; SPDX-License-Identifier: GPL-2.0-or-later
.module TIM4

.globl _tim4_setup
.globl _tim4_isr
.globl _led_ticks
.globl _fan_power

.area DATA

_fan_power:
    .ds 1
_led_ticks:
    .ds 2
fan_counter:
    .ds 1

.area CODE

_tim4_setup:

    mov    0x5347, #0x07    ; TIM4_PSCR = 7
    mov    0x5340, #0x01    ; TIM4_CR1 = _BV(TIM4_CR1_CEN)
    mov    0x5343, #0x01    ; TIM4_IER = _BV(TIM4_IER_UIE)
    ret

_tim4_isr:

    mov    0x5344, #0x00    ; TIM4_SR = 0

    ; PWM FAN control block
    ld     a, fan_counter
    cp     a, _fan_power
    bccm   0x500f, #3       ; PD_ODR.3 = CF
    inc    a
    and    a, #0b11
    ld     fan_counter, a

    tnz    _led_ticks+0
    jreq   $00001
    dec    _led_ticks+0
    jrne   $00001
    bres   0x500f, #5       ; PD_ODR &= ~_BV(5)

$00001:
    tnz    _led_ticks+1
    jreq   $00002
    dec    _led_ticks+1
    jrne   $00002
    bres   0x500f, #4       ; PD_ODR &= ~_BV(4)

$00002:
    iret
