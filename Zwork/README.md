# Zwork RISC-V Core - Preliminary Documentation

## 0. Table of Contents

0. Table of Contents
1. Characteristics
2. Control and Status Registers (CSRs)
3. Interrupt and Trap Handling
4. Hardware Abstraction Layer (HAL)

## 1. Characteristics

The Zwork Core is a simple RISC-V core purely implemented in VHDL.
It features a wrapper with a bus adapter for the Intel Avalon-MM bus.

- RV32IMZicsr Instruction Set
- Avalon-MM and Qsys ready
- Multicycle, No Pipeline
- 3 Stage: Fetch+Writeback, Decode, Execute
- With one cycle memory latency (FPGA On-Chip RAM):
  - 4 Cycles per generic instruction
  - +1 Cycle Memory Data Access
  - +1 Cycle Multiply, +32 Cycles Divide
  - 4.481 clocks per instruction average
  - 0.395 DMIPS/MHz
- Vectored Trap and Interrupt Handling
- CSR support for timer, instruction counter, interrupts and traps.
- Tested on an Intel MAX10 (10M16SAU169C7G) FPGA:
  - Area ~ 4000 LE
  - fmax ~105 MHz

## 2. Control and Status Registers (CSRs)

No privileges for accessing CSRs exist, most CSRs can be read and written, except if they are driven directly by the hardware. If individual bits are specified in the table, then only these bits are implemented.

| CSR          | CSR Address / Bit | RW  | Usage                                                                                                                    |
|--------------|-------------------|-----|--------------------------------------------------------------------------------------------------------------------------|
| mstatus      | 0x300             | RW  | Control of global interrupt enable                                                                                       |
| mstatus.mie  | 3                 | RW  | Enables interrupts, on trap or interrupt automatically set to 0, on `mret` the value from `mstatus.mpie` is copied back  |
| mstatus.mpie | 7                 | RW  | On trap or interrupt the previous value from `mstatus.mie` is copied over.                                               |
| mie          | 0x304             | RW  | Interrupt enable register                                                                                                |
| mie.soft     | 3                 | RW  | Enables software interrupts                                                                                              |
| mie.timer    | 7                 | RW  | Enables timer interrupts                                                                                                 |
| mie.ext      | 11                | RW  | Enables external interrupts                                                                                              |
| mip          | 0x344             | RW* | Interrupt pending register                                                                                               |
| mip.soft     | 3                 | RW  | Writes set or clear the pending software interrupt                                                                       |
| mip.timer    | 7                 | R   | Set when `mtime` >= `mtimecmp`                                                                                           |
| mip.ext      | 11                | R   | Set when atleast one external interrupt is enabled and pending                                                           |
| mtvec        | 0x305             | RW  | Base address of the exception vector table, depending on the cause an offset of up to 0x80 can be added                  |
| mepc         | 0x341             | RW  | On trap the address of the faulting instruction, on interrupt the address of the next instruction is written to this CSR |
| mcause       | 0x342             | R   | On exception the cause for it is written                                                                                 |
| mtval        | 0x343             | R   | Holds additional information depending on the trap cause                                                                 |

| CSR      | CSR Address | RW | Usage                                                                                                    |
|----------|-------------|----|----------------------------------------------------------------------------------------------------------|
| time     | 0xc01       | RW | Lower 32 bits of the timer register, increment on every rising edge                                      |
| timeh    | 0xc81       | RW | Upper 32 bits of the timer register                                                                      |
| timecmp  | 0x7c0       | RW | Lower 32 of the timer compare value, when the entire `time` >= `timecmp` then the `mip.timer` bit is set |
| timecmph | 0x7c1       | RW | Upper 32 bits of the timer compare value                                                                 |
| instret  | 0xc02       | RW | Lower 32 bits of the instruction retired register, incremented every time an instruction was executed    |
| instreth | 0xc82       | RW | Upper 32 bits of the instruction retired register                                                        |
| irqen    | 0x7c2       | RW | When set the corresponding external interrupt is enabled                                                 |
| irqpen   | 0x7c3       | R  | When set the corresponding external interrupt is pending                                                 |

## 3. Interrupt and Trap Handling

### Traps

The Zwork Core supports a number of traps as listed below.
When a trap occurs the core stores the program counter (`pc`) of the faulting instruction into `mepc`, moves `mstatus.mie` to `mstatus.mpie` and sets `mstatus.mie` to 0, loads the value of the mtvec into the `pc` - the offset for traps is 0 - and depending on the trap
the `mcause` and `mtval` CSRs are loaded with corresponding values:

| Exception                    | `mcause` | `mtval`     | Reason                                                                   |
|------------------------------|----------|-------------|--------------------------------------------------------------------------|
| Instruction Address Misalign | 0x0      | `pc`        | `pc` not a multiple of 4                                                 |
| Instruction Access Fault     | 0x1      | -           | `pc` set to address 0 (`nullptr`)                                        |
| Invalid Instruction          | 0x2      | Instruction | The instruction could not be decoded                                     |
| Load Address Misalign        | 0x4      | Address     | Address of `load` instruction not a multiple of the accessed data width  |
| Load Access Fault            | 0x5      | -           | Address of `load` instruction is 0 (`nullptr`)                           |
| Store Address Misalign       | 0x6      | Address     | Address of `store` instruction not a multiple of the accessed data width |
| Store Access Fault           | 0x7      | -           | Address of `store` instruction is 0 (`nullptr`)                          |
| ECALL                        | 0xb      | -           | Environment-Call from code                                               |

Note: The access fault traps do not prevent you from accessing a nullptr if the access has an offset. Only the direct access to address 0 triggers the trap. Likewise a negative offset on a positive address that results in address 0 will also trigger the trap.

Example:
```
  li t1, 0x1000
  lh t0, 3(t1)
```
The instructions access a 2-byte halfword at address 0x1003, which is not aligned on a 2-byte boundary, therefore a Load-Address-Misalign trap is triggered. The address 0x1003 is put into `mtval`.

A trap handler now can load the instruction at address `mepc`, decode it in software, load the data at the address in mtval from memory using two aligned accesses, assemble the result and put it into the intended register before modifying `mepc` to the address `mepc+4` and then returning via `mret`.

### Interrupts

The Zwork Core supports software, timer and 32 external interrupts.
The core is interrupted when an active interrupt is pending during the fetch stage. Interrupts are only enabled when the `mstatus.mie` bit is set to 1.

The current pending interrupts are visible in the CSR `mip` and their enabled status in the CSR `mie`. The logical function `mip and mie` determines if an interrupt is ready.

When the interrupt is triggered, the `mstatus.mie` bit is copied over to `mstatus.mpie` and `mstatus.mie` is set to 0. The `mcause` CSR is set to the corresponding value of the interrupt and the `pc` is set to `mtvec+offset`. The address of the instruction that would have been fetched otherwise is stored in `mepc`.

The priority (1 = Highest) and offsets are given with the following table:

| Interrupt        | Offset    | Priority | `mcause`   |
|------------------|-----------|----------|------------|
| Timer            | 0x8       | 1        | 0x80000007 |
| External IRQ #0  | 0xc       | 2        | 0x8000000b |
| External IRQ #n  | 0xc + n*4 | 2+n      | 0x8000000b |
| External IRQ #31 | 0xd0      | 33       | 0x8000000b |
| Soft             | 0x4       | 34       | 0x80000003 |

Timer interrupts occur when the `mie.timer` bit is set to 1 and `mtime` is greater or equal to `mtimecmp`. Software shall first set `mtimecmp` to the desired value, then set the `mie.timer` bit.

External interrupts are enabled by setting the `mie.ext` bit and enabling the individual external interrupt in the `irqen` CSR. Pending external interrupts set their corresponding bit in `irqpen`. The `mip.ext` bit is driven by the logical function `irqpen and irqen`.

Software interrupts are enabled by setting the `mie.soft` bit to 1 and triggered by setting the `mip.soft` bit to 1 and cleared by setting the bit to 0.

Example:

To trigger an interrupt by an external source the following registers have to be enabled:

- Any required register in the peripheral
- `irqen`
- `mie.ext`
- `mstatus.mie`

## 4. Hardware Abstraction Layer (HAL)

The HAL provides a number of C-functions to interface with the hardware...
[TODO]
