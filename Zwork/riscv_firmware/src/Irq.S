.section .text

.global Irq_Soft

# TODO: do something useful, currently just deactivate the soft interrupt again
Irq_Soft:
	addi sp, sp, -8
	sw a0, 0(sp)
	sw a1, 4(sp)
	li a0, 0x10000
	li a1, 0x41
	sb a1, 0(a0)
	lw a1, 4(sp)
	lw a0, 0(sp)
	csrci 0x344, 0x08
	addi sp, sp, 8
	mret

.global Irq_Generic
# Allocate 32 words on stack and store all registers (excluding zero) and mepc on stack
Irq_Generic:
	addi sp, sp, -32*4
	sw  x1,  1 * 4(sp)
	sw  x2,  2 * 4(sp)
	sw  x3,  3 * 4(sp)
	sw  x4,  4 * 4(sp)
	sw  x5,  5 * 4(sp)
	sw  x6,  6 * 4(sp)
	sw  x7,  7 * 4(sp)
	sw  x8,  8 * 4(sp)
	sw  x9,  9 * 4(sp)
	sw x10, 10 * 4(sp)
	sw x11, 11 * 4(sp)
	sw x12, 12 * 4(sp)
	sw x13, 13 * 4(sp)
	sw x14, 14 * 4(sp)
	sw x15, 15 * 4(sp)
	sw x16, 16 * 4(sp)
	sw x17, 17 * 4(sp)
	sw x18, 18 * 4(sp)
	sw x19, 19 * 4(sp)
	sw x20, 20 * 4(sp)
	sw x21, 21 * 4(sp)
	sw x22, 22 * 4(sp)
	sw x23, 23 * 4(sp)
	sw x24, 24 * 4(sp)
	sw x25, 25 * 4(sp)
	sw x26, 26 * 4(sp)
	sw x27, 27 * 4(sp)
	sw x28, 28 * 4(sp)
	sw x29, 29 * 4(sp)
	sw x30, 30 * 4(sp)
	sw x31, 31 * 4(sp)
	csrr a1, mepc
	sw a1, 0(sp)
# a0 -> stack, a1 -> mepc, a2 -> mcause
	mv a0, sp
	csrr a2, mcause
	jal Irq_Handler
# Irq_Handler returns new stack pointer, restore mepc and regsisters from stack; then mret
	mv sp, a0
	lw a0, 0(sp)
	csrw mepc, a0
	lw  x1,  1 * 4(sp)
	lw  x2,  2 * 4(sp)
	lw  x3,  3 * 4(sp)
	lw  x4,  4 * 4(sp)
	lw  x5,  5 * 4(sp)
	lw  x6,  6 * 4(sp)
	lw  x7,  7 * 4(sp)
	lw  x8,  8 * 4(sp)
	lw  x9,  9 * 4(sp)
	lw x10, 10 * 4(sp)
	lw x11, 11 * 4(sp)
	lw x12, 12 * 4(sp)
	lw x13, 13 * 4(sp)
	lw x14, 14 * 4(sp)
	lw x15, 15 * 4(sp)
	lw x16, 16 * 4(sp)
	lw x17, 17 * 4(sp)
	lw x18, 18 * 4(sp)
	lw x19, 19 * 4(sp)
	lw x20, 20 * 4(sp)
	lw x21, 21 * 4(sp)
	lw x22, 22 * 4(sp)
	lw x23, 23 * 4(sp)
	lw x24, 24 * 4(sp)
	lw x25, 25 * 4(sp)
	lw x26, 26 * 4(sp)
	lw x27, 27 * 4(sp)
	lw x28, 28 * 4(sp)
	lw x29, 29 * 4(sp)
	lw x30, 30 * 4(sp)
	lw x31, 31 * 4(sp)
	addi sp, sp, 32*4
	mret
