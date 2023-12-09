# Section expected at OCRAM + 0x10
# Section must have maximum of 16 bytes
.section .init

__addr__zero__: .word 0

.global __reset_vector__ # export for linker script
__reset_vector__:
	j _start

# Create 35 jump instructions that serve every exception cause
# By default they use the generic exception vector but can be overwritten by software

# Exception, Soft, Timer
j __exception_vector__
j __exception_vector__
j __exception_vector__
# 32 Interrupts
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__
j __exception_vector__

# Default execption vector to handle any otherwise unhandled trap or interrupt
.global __exception_vector__
__exception_vector__:
# Allocate 32 words on stack and store all registers (excluding zero) and mepc on stack
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
# a0 -> stack, a1 -> mepc, a2 -> mcause, a3 -> mtval
	mv a0, sp
	csrr a2, mcause
	csrr a3, mtval
	jal Hal_Exception
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

.extern __data_lma_begin__
.extern __data_vma_begin__
.extern __data_vma_end__
.extern __bss_begin__
.extern __bss_end__
.extern __init_begin__
.extern __init_end__

.global _start
_start:
# Copy data section from LMA to VMA
	la x1, __data_vma_begin__
	la x2, __data_vma_end__
	la x3, __data_lma_begin__
1:
	beq x1, x2, 2f
	lw x4, 0(x3)
	sw x4, 0(x1)
	addi x1, x1, 4
	addi x3, x3, 4
	j 1b
2:
# Zero out BSS segment
	la x1, __bss_begin__
	la x2, __bss_end__
3:
	beq x1, x2, 4f
	sw x0, 0(x1)
	addi x1, x1, 4
	j 3b
4:
# Set all registers to 0, load stack pointer (x2)
	mv  x1, x0
	la  x2, __sp
	mv  x3, x0
	mv  x4, x0
	mv  x5, x0
	mv  x6, x0
	mv  x7, x0
	mv  x8, x0
	mv  x9, x0
	mv x10, x0
	mv x11, x0
	mv x12, x0
	mv x13, x0
	mv x14, x0
	mv x15, x0
	mv x16, x0
	mv x17, x0
	mv x18, x0
	mv x19, x0
	mv x20, x0
	mv x21, x0
	mv x22, x0
	mv x23, x0
	mv x24, x0
	mv x25, x0
	mv x26, x0
	mv x27, x0
	mv x28, x0
	mv x29, x0
	mv x30, x0
	mv x31, x0
# Call initialisers and constructors (C++)
# this is generated code and must be executed after initializing registers
	la s0, __init_begin__
	la s1, __init_end__
5:
	beq s0, s1, 6f
	lw t0, 0(s0)
	jalr ra, t0
	addi s0, s0, 4
	j 5b
6:
	call main
7:	j 7b
