#include "Irq.h"
#include "printf.h"
#include "Hal.h"
#include "FpgaConfig.h"

void Irq_Uart(){}

extern "C" uintptr_t Irq_Handler(uintptr_t stack, uintptr_t mepc, uint32_t mcause) {
	if (mcause == 0x80000003) {
		printf_("Soft Interrupt\n");
		Hal_ClearSoftInterrupt();
	} else if (mcause == 0x80000007) {
		printf_("Timer Interrupt\n");
		Hal_TimerStop();
	} else if (mcause == 0x8000000b) {
		uint32_t active = Hal_ActiveInterrupts();
	} else {
		printf_("Unhandled Interrupt: %08lx\n", mcause);
	}
	return stack;
}
