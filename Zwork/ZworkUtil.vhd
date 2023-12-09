library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ZworkUtil is

	type e_State is (State_FetchWriteback, State_Decode, State_Execute);
	type e_Opcode is (
		Op_Lui, Op_Auipc, Op_Jal, Op_Jalr,
		Op_Beq, Op_Bne, Op_Blt, Op_Bge, Op_Bltu, Op_Bgeu,
		Op_Lb, Op_Lh, Op_Lw, Op_Lbu, Op_Lhu, Op_Sb, Op_Sh, Op_Sw,
		Op_Addi, Op_Slti, Op_Sltiu, Op_Xori, Op_Ori, Op_Andi, Op_Slli, Op_Srli, Op_Srai,
		Op_Add, Op_Sub, Op_Sll, Op_Slt, Op_Sltu, Op_Xor, Op_Srl, Op_Sra, Op_Or, Op_And,
		Op_Mul, Op_Mulh, Op_Mulhsu, Op_Mulhu, Op_Div, Op_Divu, Op_Rem, Op_Remu,
		Op_Csrrw, Op_Csrrs, Op_Csrrc, Op_Csrrwi, Op_Csrrsi, Op_Csrrci,
		Op_Ecall, Op_Mret
	);
	type e_Type is (Type_AluBrn, Type_Csr, Type_Mem);
	type e_Csr is (
		Csr_NoCsr,
		Csr_Mtvec, Csr_Mepc, Csr_Mtval, Csr_Mie, Csr_Mip, Csr_Mstatus,
		Csr_Mcause, Csr_Irqen, Csr_Irqpen, Csr_Time, Csr_Timeh,
		Csr_Timecmp, Csr_Timecmph, Csr_Instret, Csr_Instreth
	);
	type CsrRegs is array(e_Csr) of std_logic_vector(31 downto 0);

end ZworkUtil;
