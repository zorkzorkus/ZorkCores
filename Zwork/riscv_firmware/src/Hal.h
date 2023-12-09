#ifndef HAL_H
#define HAL_H

#include <cstdint>
#include "FpgaConfig.h"

#define write_csr(reg, val) ({ \
	if (__builtin_constant_p(val) && (unsigned long)(val) < 32) \
		asm volatile ("csrw " #reg ", %0" :: "i"(val)); \
	else \
		asm volatile ("csrw " #reg ", %0" :: "r"(val)); })

#define swap_csr(reg, val) ({ unsigned long __tmp; \
	if (__builtin_constant_p(val) && (unsigned long)(val) < 32) \
		asm volatile ("csrrw %0, " #reg ", %1" : "=r"(__tmp) : "i"(val)); \
	else \
		asm volatile ("csrrw %0, " #reg ", %1" : "=r"(__tmp) : "r"(val)); \
	__tmp; })

#define set_csr(reg, bit) ({ unsigned long __tmp; \
	if (__builtin_constant_p(bit) && (unsigned long)(bit) < 32) \
		asm volatile ("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "i"(bit)); \
	else \
		asm volatile ("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "r"(bit)); \
	__tmp; })

#define clear_csr(reg, bit) ({ unsigned long __tmp; \
	if (__builtin_constant_p(bit) && (unsigned long)(bit) < 32) \
		asm volatile ("csrrc %0, " #reg ", %1" : "=r"(__tmp) : "i"(bit)); \
	else \
		asm volatile ("csrrc %0, " #reg ", %1" : "=r"(__tmp) : "r"(bit)); \
	__tmp; })

#define read_csr_ns(reg)		read_csr(reg)
#define write_csr_ns(reg, val)	write_csr(reg, val)
#define swap_csr_ns(reg, val)	swap_csr(reg, val)
#define set_csr_ns(reg, bit)	set_csr(reg, bit)
#define clear_csr_ns(reg, bit)	clear_csr(reg, bit)

typedef void(*VoidFunc)(void);

constexpr uint32_t IRQ_EXT = 0x0b;
constexpr uint32_t IRQ_TIMER = 0x07;
constexpr uint32_t IRQ_SOFT = 0x03;

// Located in Hal.c

void Hal_SetExtIrqHandler(uint32_t irq, VoidFunc callback);
void Hal_SetTimerIrqHandler(VoidFunc callback);
void Hal_SetSoftIrqHandler(VoidFunc callback);
void Hal_EnableInterrupt(uint32_t irq);
void Hal_DisableInterrupt(uint32_t irq);
void Hal_Delay(uint32_t cycles);
void Hal_TimerStart(uint64_t value);
void Hal_TimerStop();
void Hal_RaiseSoftInterrupt();
void Hal_ClearSoftInterrupt();

// Located in Hal.S
extern "C" {
	void Hal_EnableInterrupts(uint32_t mask);
	void Hal_DisableInterrupts(uint32_t mask);
	void Hal_EnableMachineInterrupt(uint32_t irq);
	void Hal_DisableMachineInterrupt(uint32_t irq);
	void Hal_GlobalEnableInterrupts();
	void Hal_GlobalEnableInterrupts();
	uint32_t Hal_ActiveInterrupts();
	uint32_t Hal_ReadTime32();
	uint64_t Hal_ReadTime64();
}
// Private function called from Crt.S, not to be called directly
	// uintptr_t Hal_Exception(uintptr_t stack, uintptr_t addr, uint32_t irq);

#endif // HAL_H
