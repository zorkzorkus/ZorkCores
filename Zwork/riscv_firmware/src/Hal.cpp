#include "Hal.h"
#include "printf.h"

#define MTVEC_OFFSET_SOFT  1
#define MTVEC_OFFSET_TIMER 2
#define MTVEC_OFFSET_EXT   3

static uint32_t* const l_ExceptionTable = (uint32_t*)(c_Mtvec);

static uint32_t CreateJumpInstruction(uint32_t offset, VoidFunc target) {
	uint32_t immOffset = (uint32_t)target - (c_Mtvec + 4 * offset);
	uint32_t imm = immOffset & 0x000ff000; // [19, 12] -> [19, 12]
	imm |= (immOffset << 9) & 0x00100000; // [11] -> [20]
	imm |= (immOffset << 20) & 0x7fe00000; // [10, 1] -> [30, 21]
	imm |= (immOffset << 11) & 0x80000000; // [20] -> [31]
	uint32_t instr = 0x0000006f;
	return imm | instr;
}

void Hal_SetExtIrqHandler(uint32_t irq, VoidFunc callback) {
	l_ExceptionTable[MTVEC_OFFSET_EXT + irq] = CreateJumpInstruction(MTVEC_OFFSET_EXT + irq, callback);
}

void Hal_SetTimerIrqHandler(VoidFunc callback) {
	l_ExceptionTable[MTVEC_OFFSET_TIMER] = CreateJumpInstruction(MTVEC_OFFSET_TIMER, callback);
}

void Hal_SetSoftIrqHandler(VoidFunc callback) {
	l_ExceptionTable[MTVEC_OFFSET_SOFT] = CreateJumpInstruction(MTVEC_OFFSET_SOFT, callback);
}

void Hal_EnableInterrupt(uint32_t irq) {
	Hal_EnableInterrupts(1 << irq);
}

void Hal_DisableInterrupt(uint32_t irq) {
	Hal_DisableInterrupts(1 << irq);
}

void Hal_Delay(uint32_t cycles) {
	uint32_t startTick = Hal_ReadTime32();
	while ((Hal_ReadTime32() - startTick) < cycles);
}

void Hal_TimerStart(uint64_t value) {
	Hal_DisableMachineInterrupt(IRQ_TIMER);
	uint64_t mtime = Hal_ReadTime64() + value;
	write_csr_ns(0x7c0, (uint32_t)mtime);
	write_csr_ns(0x7c1, (uint32_t)(mtime>>32));
	Hal_EnableMachineInterrupt(IRQ_TIMER);
}

void Hal_TimerStop() {
	Hal_DisableMachineInterrupt(IRQ_TIMER);
}

void Hal_RaiseSoftInterrupt() {
	// Raise the soft irq bit, the effect takes place in the FetchWriteback stage
	// The interrupt will be triggered when fetching the instruction after the nop
	set_csr_ns(0x344, 0x08);
	asm("nop");
}

void Hal_ClearSoftInterrupt() {
	clear_csr_ns(0x344, 0x08);
}

// Called from crt0.S
extern "C" uintptr_t Hal_Exception(uintptr_t stack, uintptr_t mepc, uint32_t mcause, uintptr_t mtval) {

	if (mcause & 0x80000000) {
		printf_("Unhandled Interrupt\n\tCause: %08lx\n\t Mepc: %08x\n\tMtval: %08x\n\n", mcause, mepc, mtval);
	} else {
		const char* errorMsg = "Unknown";
		if (mcause == 0) {
			errorMsg = "Instruction Address Misaligned";
		} else if (mcause == 1) {
			errorMsg = "Instruction Access Fault";
		} else if (mcause == 2) {
			errorMsg = "Illegal Instruction";
		} else if (mcause == 4) {
			errorMsg = "Load Address Misaligned";
		} else if (mcause == 5) {
			errorMsg = "Load Access Fault";
		} else if (mcause == 6) {
			errorMsg = "Store Address Misaligned";
		} else if (mcause == 7) {
			errorMsg = "Store Access Fault";
		} else if (mcause == 11) {
			errorMsg = "Environment Call";
		}
		printf_("Exception: %s\n\tCause: %08lx\n\t Mepc: %08x\n\tMtval: %08x\n\n", errorMsg, mcause, mepc, mtval);
	}

	return stack;

}
