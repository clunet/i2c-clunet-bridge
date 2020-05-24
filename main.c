/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <stdint.h>
#include "stm8s.h"
#include "clunet.h"
#include "tim1.h"
#include "tim2.h"
#include "tim4.h"
#include "i2c.h"

/* main global buffers */
clunet_message_t rx_message;        /* rx message buffer */
clunet_message_t tx_message;        /* tx message buffer */

/* driver global vars */
uint8_t status = _BV(CLUSR_TXE);    /* status */
uint8_t bit_mask;                   /* bit mask */
uint8_t byte_value;                 /* current byte */
uint8_t byte_index;                 /* byte index */

void
main(void)
{
#ifdef STM8S001J3
    stm8s001j3_config_unused_pins();
    stm8s001j3_swim_delay_5s();
    /* disable SWIM. set ISRs only activate level */
    CFG_GCR = _BV(CFG_GCR_SWD) | _BV(CFG_GCR_AL);
    /* enable clock to: TIM1, TIM2, I2C */
    CLK_PCKENR1 = 0b10100001;
    CLK_PCKENR2 = 0;
    /* Setup PORTB pins: SCL(PB4) and SDA(PB5) */
    PB_CR1 |= (0b11 << 4);
    /* Setup PORTC pins: TIM1_CH1(PC6), TIM2_CH1(PC5), IRQ(PC3) */
    PC_DDR |= (0b01 << 5);
    PC_CR1 |= (0b11 << 5);
    /* Setup PORTD pins: IRQ(PD6) */
    PD_DDR |= _BV(6);
    PD_CR1 |= _BV(6);
#else
    /* set ISRs only activate level */
    CFG_GCR = _BV(CFG_GCR_AL);
    /* enable clock to: TIM1, TIM2, TIM4, I2C */
    CLK_PCKENR1 = 0b10110001;
    CLK_PCKENR2 = 0;
    /* Setup PORTA pins: unused */
    PA_DDR = (0b111 << 1);
    PA_CR1 = (0b111 << 1);
    /* Setup PORTB pins: SCL(PB4) and SDA(PB5) */
    PB_CR1 = (0b11 << 4);
    /* Setup PORTC pins: TIM1_CH1(PC6), TIM2_CH1(PC5), IRQ(PC3) */
    PC_DDR = (0b10111 << 3);
    PC_CR1 = (0b11111 << 3);
    /* Setup PORTD pins: LEDS(PD6:4), FAN(PD3), SWIM(PD1) */
    PD_DDR = (0b111110 << 1);
    PD_CR1 = (0b111111 << 1);
    /* setup TIM4 */
    tim4_setup();
#endif

    /* F_CPU = 16 MHz */
    CLK_CKDIVR = 0;

    tim1_setup();
    tim2_setup();
    i2c_setup();

    wfi();
}
