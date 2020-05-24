/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef _TIM1_H_
#define _TIM1_H_

#include "stm8s.h"

void
tim1_setup(void);

void
tim1_uev_isr(void) __interrupt(TIM1_OVF_ISR);

void
tim1_cc_isr(void) __interrupt(TIM1_CC_ISR);

#endif
