#ifndef FPGACONFIG_H
#define FPGACONFIG_H

#include <cstdint>

// Include peripherals used in the FPGA
#include "Uart.h"
#include "Pio.h"

// RISC-V Configuration
constexpr uintptr_t c_ResetVector = 0x00000004;
constexpr uintptr_t c_Mtvec = 0x00000008;

// Clock, Address and Interrupt Configuration
constexpr uint32_t  c_CLK_FREQ         = 25000000UL; // 25 MHz
constexpr uintptr_t c_ADDRESS_PIO      = 0x10100;
constexpr uintptr_t c_ADDRESS_UART     = 0x10200;
constexpr uintptr_t c_ADDRESS_RESRAM   = 0x10300;
constexpr uint32_t  c_INTERRUPT_UART   = 0;
constexpr uint32_t  c_INTERRUPT_RESRAM = 1;

extern Uart g_Uart;
extern Pio g_Pio;

#endif // FPGACONFIG_H
