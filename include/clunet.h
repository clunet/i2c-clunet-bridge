/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef _CLUNET_H_
#define _CLUNET_H_

#include <stdint.h>
#include "stm8s.h"

/* Compile for STM8S001J3 MCU. Not working yet. */
//#define STM8S001J3

/* I2C address */
#define I2C_ADDRESS     0x60

/* CLUNET message type */
typedef struct clunet_message {
    uint8_t priority;           /* priority */
    uint8_t dst_address;        /* destination address */
    uint8_t src_address;        /* source address */
    uint8_t command;            /* command */
    uint8_t size;               /* size of payload data */
    uint8_t buffer[250];        /* buffer */
    uint8_t _crc_reserved;      /* reserved for checksum */
} clunet_message_t;

/* RX buffer Not Empty flag. Message received. Cleared by reading message. */
#define CLUSR_RXNE  0
/* RX Overload event flag. Packet has been lost. Cleared by status reading. */
#define CLUSR_RXOV  1
/* RX Error event flag. Error while packet receiving. Cleared by status reading. */
#define CLUSR_RXER  2
/* TX buffer Empty flag. New message may be transmit. Cleared by writing message for transmit. */
#define CLUSR_TXE   4
/* TX Finish event flag. Message was transmited. Cleared by status reading. */
#define CLUSR_TXF   5
/* TX Collision event flag. Collision while transmit. Cleared by status reading. */
#define CLUSR_TXC   6

#define CLUNET_IS_IDLE()            (TIM1_IER == _BV(TIM1_IER_CC1IE))
#define CLUNET_IS_TX_FORBIDDEN()    (status & (_BV(CLUSR_TXE) | _BV(CLUSR_RXNE)))

#if 0
#define CLUNET_CCRH(p)              ((1024 * (p)) >> 8)
#define CLUNET_CCRL(p)              ((1024 * (p)) & 255)
#define CLUNET_ARRH(p)              ((1024 * (p) - 1) >> 8)
#define CLUNET_ARRL(p)              ((1024 * (p) - 1) & 255)
#endif

#endif
