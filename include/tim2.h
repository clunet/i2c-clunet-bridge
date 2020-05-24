/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef _TIM2_H_
#define _TIM2_H_

#include "stm8s.h"

void
tim2_setup(void);

void
tim2_uev_isr(void) __interrupt(TIM2_OVF_ISR);

#endif
