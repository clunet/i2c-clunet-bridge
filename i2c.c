/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "stm8s.h"
#include "clunet.h"

extern clunet_message_t rx_message;
extern clunet_message_t tx_message;
extern uint8_t status;
extern uint8_t fan_power;

static void * const
i2c_banks[] = {
    &i2c_bank0,
    &rx_message,
    &tx_message,
    &fan_power
};

#define I2C_STATUS_INIT     0
#define I2C_STATUS_BANK     1
#define I2C_STATUS_DATA     2
#define I2C_BANK_STATUS     0
#define I2C_BANK_RX_MSG     1
#define I2C_BANK_TX_MSG     2
#define I2C_BANK_FAN        3

static uint8_t i2c_status;
static uint8_t i2c_bank;
static uint8_t *i2c_current;
static struct {
    uint8_t status;     /* copy of driver status byte */
    uint8_t rx_size;    /* size of received message in rx buffer */
} i2c_bank0;

void
i2c_setup(void)
{
    /* set i2c frequency value in MHz */
    I2C_FREQR = 16;
    /* set slave address */
    I2C_OARL = (I2C_ADDRESS << 1);
    /* set 7-bit address mode */
    I2C_OARH = _BV(I2C_OARH_ADDCONF);
    /* enable all i2c interrupts */
    I2C_ITR = _BV(I2C_ITR_ITBUFEN) | _BV(I2C_ITR_ITEVTEN) | _BV(I2C_ITR_ITERREN);
    /* enable i2c peripheral */
    I2C_CR1 = _BV(I2C_CR1_PE);
    /* enable i2c acknowledgement */
    I2C_CR2 = _BV(I2C_CR2_ACK);
}

static void
tx_try(void)
{
    if (!CLUNET_IS_TX_FORBIDDEN() && CLUNET_IS_IDLE())
    {
        /* start UEV ISR for planning transmit */
        TIM1_IER = _BV(TIM1_IER_UIE);
    }
}

static void
status_latch(void)
{
    /* IRQ pin OFF */
    PC_ODR &= ~_BV(3);

    /* switch i2c memory bank */
    i2c_status = I2C_STATUS_BANK;
    i2c_bank = I2C_BANK_STATUS;
    i2c_current = (uint8_t *)&i2c_bank0;

    /* latch clunet status data */
    i2c_bank0.status = status;
    i2c_bank0.rx_size = 0;
    
    /* reset all flags except buffer flags */
    status &= _BV(CLUSR_TXE) | _BV(CLUSR_RXNE);

    /* set reading size of rx buffer [bank 1] */
    if (status & _BV(CLUSR_RXNE))
    {
        i2c_bank0.rx_size = rx_message.size + 5;
    }
}

/* i2c error */
inline void
i2c_error(void)
{
    /* reset i2c state */
    i2c_status = I2C_STATUS_INIT;
}

/* master "read-only" transaction started or "write-read" continued */
inline void
i2c_tx_started(void)
{
    /* status bank is default for "read-only" transaction */
    if (i2c_status == I2C_STATUS_INIT)
    {
        status_latch();
    }
    
    else if (i2c_bank == I2C_BANK_RX_MSG)
    {
        /* master start reading of rx message (2 priority bits). try start transmit */
        /* it is safely: speed of CLUNET is much less than I2C */
        status &= ~_BV(CLUSR_RXNE);
        tx_try();
    }
}

/* give next byte to the master */
static void
i2c_tx_byte(void)
{
    I2C_DR = *i2c_current;
    i2c_current++;
}

/* master "read-only" or "write-read" transaction ended */
inline void
i2c_tx_ended(void)
{
    /* reset i2c state */
    i2c_status = I2C_STATUS_INIT;
}

/* master "write-only" or "write-read" transaction started */
inline void
i2c_rx_started(void)
{
    /* reset i2c state */
    i2c_status = I2C_STATUS_INIT;
}

/* new byte from master received */
static void
i2c_rx_byte(void)
{
    uint8_t data = I2C_DR;

    if (i2c_status >= I2C_STATUS_BANK)
    {
        if (i2c_status == I2C_STATUS_BANK &&
                                i2c_bank == I2C_BANK_TX_MSG)
        {
            /* TX_LED_ON() */
            PD_ODR |= _BV(6);

            /* master write first byte of tx message (2 priority bits). try start transmit */
            /* it is safely: speed of CLUNET is much less than I2C */
            status &= ~_BV(CLUSR_TXE);
            tx_try();
        }
        
        i2c_status = I2C_STATUS_DATA;
        
        if (i2c_bank >= I2C_BANK_TX_MSG)
        {
            *i2c_current++ = data;
        }
        
        return;
    }
    
    if (data > I2C_BANK_FAN)
    {
        data = I2C_BANK_STATUS;
    }
    
    if (data == I2C_BANK_STATUS)
    {
        status_latch();
        return;
    }
    
    i2c_status = I2C_STATUS_BANK;
    i2c_bank = data;
    i2c_current = i2c_banks[data];
}

/* master "write-only" transaction ended */
inline void
i2c_rx_ended(void)
{
    i2c_status = I2C_STATUS_INIT;
}

void
i2c_isr(void) __interrupt(I2C_ISR)
{
    const uint8_t sr1 = I2C_SR1;
    const uint8_t sr3 = I2C_SR3;
    const uint8_t sr2 = I2C_SR2;
    
    I2C_SR2 = 0;

    /* in our case may be bus error only. lines are released by hardware */
    if (sr2 & _BV(I2C_SR2_BERR))
    {
        i2c_error();
        
        return;
    }

    if (sr3 & _BV(I2C_SR3_TRA))
    {
        /* SLAVE TRANSMITTER MODE */

        /* EV1 */
        if (sr1 & _BV(I2C_SR1_ADDR))
        {
            i2c_tx_started();
        }

        /* EV3 */
        if (sr1 & _BV(I2C_SR1_TXE))
        {
            i2c_tx_byte();

            /* EV3-1 */
            if (sr1 & _BV(I2C_SR1_BTF))
            {
                i2c_tx_byte();
            }
        }

        /* EV3-2 */
        if (sr2 & _BV(I2C_SR2_AF))
        {
            i2c_tx_ended();
        }

        return;
    }

    /* SLAVE RECEIVER MODE */

    /* EV1 */
    if (sr1 & _BV(I2C_SR1_ADDR))
    {
        i2c_rx_started();
    }

    /* EV2 */
    if (sr1 & _BV(I2C_SR1_RXNE))
    {
        i2c_rx_byte();

        /* EV2 */
        if (sr1 & _BV(I2C_SR1_BTF))
        {
            i2c_rx_byte();
        }
    }
    
    /* EV4 */
    if (sr1 & _BV(I2C_SR1_STOPF))
    {
        I2C_CR2 = _BV(I2C_CR2_ACK);
        i2c_rx_ended();
    }
}
