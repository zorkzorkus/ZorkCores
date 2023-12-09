#include "printf.h"
#include "Hal.h"
#include "Irq.h"

int main() {
	printf_("\n\n* * Zwonk RISC-V C++ * *\n");
	Hal_SetExtIrqHandler(c_INTERRUPT_UART, Irq_Generic);
	Hal_EnableMachineInterrupt(IRQ_EXT); // enable bit "m_ext" in csr_mie
	Hal_GlobalEnableInterrupts(); // enable bit "mie" in csr_mstatus
	g_Pio.SetDirection(3);
	while (true) {
		g_Pio.Set(0);
		Hal_Delay(2500000);
		g_Pio.Set(1);
		Hal_Delay(2500000);
	}
}
