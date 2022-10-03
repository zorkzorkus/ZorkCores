library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ZworkUtil is

	type e_State is (State_FetchWriteback, State_Decode, State_Execute, State_Memory, State_Trap);
	type e_Opcode is (
		Op_Jump, Op_BranchEq, Op_BranchNe, Op_BranchLt, Op_BranchGe, Op_BranchLtu, Op_BranchGeu, Op_Load, Op_Store,
		Op_Add, Op_Slt, Op_Sltu, Op_Xor, Op_Or, Op_And, Op_Sll, Op_Srl, Op_Sra, Op_Sub,
		Op_Mul, Op_Mulh, Op_Mulhsu, Op_Mulhu, Op_Div, Op_Divu, Op_Rem, Op_Remu,
		Op_Mret, Op_Csrw, Op_Csrs, Op_Csrc
	);
	type e_Execute is (Execute_Alu, Execute_Brn, Execute_Csr, Execute_Mem);
	type e_Csr is (
		Csr_Mtvec, Csr_Mepc, Csr_Mtval, Csr_Mie, Csr_Mip, Csr_Mstatus,
		Csr_Mcause, Csr_Irqen, Csr_Irqpen, Csr_Time, Csr_Timeh,
		Csr_Timecmp, Csr_Timecmph, Csr_Instret, Csr_Instreth
	);
	type CsrRegs is array(e_Csr) of std_logic_vector(31 downto 0);

end ZworkUtil;
