/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef _I2C_H_
#define _I2C_H_

#include "stm8s.h"

void
i2c_setup(void);

void
i2c_isr(void) __interrupt(I2C_ISR);

#endif
