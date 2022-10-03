# Zwork

### RV32IMZicsr Core
* Simple non-pipelined, non-caching architecture
* Fetch+Writeback, Decode, Execute, Memory (if instruction)
* Hard multiply (2 cycles in execute)
* Variable cycle divide
* Full Trap and Interrupt support via CSRs
* Lower fmax and higher area usage compared to other RISC-V cores
* Simple and short VHDL code

### Generics
| Name | Description |
| - | - |
| g_reset_vector | Initial value of the PC register, first instruction the core loads when starting
| g_mtvec | Initial value of the the ``MTVEC`` CSR. This address is loaded into the PC when an interrupt or trap occures.

### TODO
* Ensure stability and correctness
* Improve area usage und fmax

