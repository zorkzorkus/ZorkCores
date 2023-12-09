#pragma once 

#include <cstdint>
#include "FpgaConfig.h"

void Irq_Soft(void);

extern "C" void Irq_Generic(void);
extern "C" uintptr_t Irq_Handler(uintptr_t stack, uintptr_t mepc, uint32_t mcause);
