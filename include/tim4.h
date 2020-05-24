/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef _TIM4_H_
#define _TIM4_H_

#include "stm8s.h"
#include "clunet.h"

#ifndef STM8S001J3

void
tim4_setup(void);

void
tim4_isr(void) __interrupt(TIM4_ISR);

#endif

#endif
