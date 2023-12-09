library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkDecoder is
	port (
		clk            : in  std_logic;
		resetn         : in  std_logic;
		i_instr        : in  std_logic_vector(31 downto 0);
		i_active       : in  boolean;
		o_trp_badinstr : out boolean;
		o_trp_ecall    : out boolean;
		o_op           : out e_Opcode;
		o_type         : out e_Type;
		o_rd           : out std_logic_vector(4 downto 0);
		o_imm          : out std_logic_vector(31 downto 0);
		o_csrimm       : out std_logic_vector(4 downto 0);
		o_funct3       : out std_logic_vector(2 downto 0);
		o_funct7       : out std_logic_vector(6 downto 0);
		o_rs1          : out std_logic_vector(4 downto 0);
		o_rs2          : out std_logic_vector(4 downto 0);
		o_csr          : out e_Csr
	);
end entity;

-- Decoder unit
-- Decodes instruction into control signals
-- Registered on the clock:
	-- r_trp_badinstr
	-- r_trp_ecall
	-- r_op
	-- r_rd
	-- r_imm
	-- r_csrimm
	-- r_funct3
	-- r_funct7
	-- r_type
-- Combinatorial for the same clock:
	-- o_rs1
	-- o_rs2
	-- o_csr

architecture rtl of ZworkDecoder is

	alias a_csrsel : std_logic_vector(11 downto 0) is i_instr(31 downto 20);
	signal c_csr : e_Csr;

	signal r_trp_badinstr : boolean := false;
	signal r_trp_ecall    : boolean := false;
	signal r_op           : e_Opcode := Op_Lui;
	signal r_type         : e_Type := Type_AluBrn;
	signal r_rd           : std_logic_vector(4 downto 0) := (others => '0');
	signal r_imm          : std_logic_vector(31 downto 0) := (others => '0');
	signal r_csrimm       : std_logic_vector(4 downto 0) := (others => '0');
	signal r_funct3       : std_logic_vector(2 downto 0) := (others => '0');
	signal r_funct7       : std_logic_vector(6 downto 0) := (others => '0');

begin

	process (clk, resetn)

		-- "va" means its a "variable" but used just as an "alias"
		variable va_immi   : std_logic_vector(31 downto 0);
		variable va_imms   : std_logic_vector(31 downto 0);
		variable va_immb   : std_logic_vector(31 downto 0);
		variable va_immu   : std_logic_vector(31 downto 0);
		variable va_immj   : std_logic_vector(31 downto 0);
		variable va_funct3 : std_logic_vector(2 downto 0);
		variable va_funct7 : std_logic_vector(6 downto 0);
		variable va_inst62 : std_logic_vector(4 downto 0);

	begin

		-- Prepare aliases
		va_immi := (others => i_instr(31));
		va_immi(10 downto 0) := i_instr(30 downto 20);
		va_imms := (others => i_instr(31));
		va_imms(10 downto 0) := i_instr(30 downto 25) & i_instr(11 downto 7);
		va_immb := (others => i_instr(31));
		va_immb(11 downto 0) := i_instr(7) & i_instr(30 downto 25) & i_instr(11 downto 8) & "0";
		va_immu := i_instr(31 downto 12) & x"000";
		va_immj := (others => i_instr(31));
		va_immj(19 downto 0) := i_instr(19 downto 12) & i_instr(20) & i_instr(30 downto 21) & "0";
		va_funct3 := i_instr(14 downto 12);
		va_funct7 := i_instr(31 downto 25);
		va_inst62 := i_instr(6 downto 2);

		if (resetn = '0') then
			r_trp_badinstr <= false;
			r_trp_ecall <= false;
			r_op <= Op_Lui;
			r_type <= Type_AluBrn;
			r_rd <= (others => '0');
			r_imm <= (others => '0');
			r_csrimm <= (others => '0');
			r_funct3 <= (others => '0');
			r_funct7 <= (others => '0');
		elsif rising_edge(clk) then

			r_trp_badinstr <= false;
			r_trp_ecall <= false;

			if (i_active) then

				r_funct3 <= va_funct3;
				r_funct7 <= va_funct7;
				r_rd <= i_instr(11 downto 7);
				r_type <= Type_AluBrn; -- most common, overwrite for mem & csr
				r_csrimm <= i_instr(19 downto 15);

				if (i_instr(1 downto 0) /= "11") then
					r_trp_badinstr <= true;
				else
					case va_inst62 is
						when "01101" => -- LUI
							r_op <= Op_Lui;
							r_imm <= va_immu;
						when "00101" => -- AUIPC
							r_op <= Op_Auipc;
							r_imm <= va_immu;
						when "11011" => -- JAL
							r_op <= Op_Jal;
							r_imm <= va_immj;
						when "11001" => -- JALR
							if (va_funct3 /= "000") then
								r_trp_badinstr <= true;
							end if;
							r_op <= Op_Jalr;
							r_imm <= va_immi;
						when "11000" => -- Branch
							case va_funct3 is
								when "000" => r_op <= Op_Beq;
								when "001" => r_op <= Op_Bne;
								when "100" => r_op <= Op_Blt;
								when "101" => r_op <= Op_Bge;
								when "110" => r_op <= Op_Bltu;
								when "111" => r_op <= Op_Bgeu;
								when others => null;
							end case;
							r_imm <= va_immb;
							r_rd <= "00000";
							if (va_funct3(2 downto 1) = "01") then
								r_trp_badinstr <= true;
							end if;
						when "00000" => -- Load
							r_type <= Type_Mem;
							case va_funct3 is
								when "000" => r_op <= Op_Lb;
								when "001" => r_op <= Op_Lh;
								when "010" => r_op <= Op_Lw;
								when "100" => r_op <= Op_Lbu;
								when "101" => r_op <= Op_Lhu;
								when others => r_trp_badinstr <= true;
							end case;
							r_imm <= va_immi;
						when "01000" => -- Store
							r_type <= Type_Mem;
							case va_funct3 is
								when "000" => r_op <= Op_Sb;
								when "001" => r_op <= Op_Sh;
								when "010" => r_op <= Op_Sw;
								when others => r_trp_badinstr <= true;
							end case;
							r_rd <= "00000";
							r_imm <= va_imms;
						when "00100" => -- OP-IMM
							case va_funct3 is
								when "000" => r_op <= Op_Addi;
								when "001" => r_op <= Op_Slli;
								when "010" => r_op <= Op_Slti;
								when "011" => r_op <= Op_Sltiu;
								when "100" => r_op <= Op_Xori;
								when "101" =>
									if (va_funct7(5) = '1') then
										r_op <= Op_Srai;
									else
										r_op <= Op_Srli;
									end if;
								when "110" => r_op <= Op_Ori;
								when "111" => r_op <= Op_Andi;
								when others => null;
							end case;
							r_imm <= va_immi;
							if (va_funct3 = "001" and va_funct7 /= "0000000") then
								r_trp_badinstr <= true;
							elsif (va_funct3 = "101" and (va_funct7 /= "0000000" and va_funct7 /= "0100000")) then
								r_trp_badinstr <= true;
							end if;
						when "01100" => -- OP
							if (va_funct7(0) = '1') then -- RV32<M>
								case va_funct3 is
									when "000" => r_op <= Op_Mul;
									when "001" => r_op <= Op_Mulh;
									when "010" => r_op <= Op_Mulhsu;
									when "011" => r_op <= Op_Mulhu;
									when "100" => r_op <= Op_Div;
									when "101" => r_op <= Op_Divu;
									when "110" => r_op <= Op_Rem;
									when "111" => r_op <= Op_Remu;
									when others => null;
							end case;
							else -- RV32<I>
								case va_funct3 is
									when "000" =>
										if (va_funct7(5) = '1') then
											r_op <= Op_Sub;
										else
											r_op <= Op_Add;
										end if;
									when "001" => r_op <= Op_Sll;
									when "010" => r_op <= Op_Slt;
									when "011" => r_op <= Op_Sltu;
									when "100" => r_op <= Op_Xor;
									when "101" =>
										if (va_funct7(5) = '1') then
											r_op <= Op_Sra;
										else
											r_op <= Op_Srl;
										end if;
									when "110" => r_op <= Op_Or;
									when "111" => r_op <= Op_And;
									when others => null;
							end case;
							end if;
							if (not (va_funct7 = "0000000" or (va_funct7 = "0100000" and (va_funct3 = "000" or va_funct3 = "101")) -- RV32I valid
							or va_funct7 = "0000001")) then
								r_trp_badinstr <= true;
							end if;
						when "11100" => -- System
							if (i_instr = x"30200073") then -- MRET
								r_op <= Op_Mret;
								r_rd <= "00000";
							elsif (i_instr = x"00000073") then -- ECALL
								r_trp_ecall <= true;
							else -- CSR
								r_type <= Type_Csr;
								case va_funct3 is
									when "001" => r_op <= Op_Csrrw;
									when "010" => r_op <= Op_Csrrs;
									when "011" => r_op <= Op_Csrrc;
									when "101" => r_op <= Op_Csrrwi;
									when "110" => r_op <= Op_Csrrsi;
									when "111" => r_op <= Op_Csrrci;
									when others => r_trp_badinstr <= true;
								end case;
								if (c_csr = Csr_NoCsr) then
									r_trp_badinstr <= true;
								end if;
							end if;

						-- 5 bit opcode not recognized
						when others => r_trp_badinstr <= true;

					end case;
				end if;
			end if;
		end if;
	end process;

	o_rs1 <= i_instr(19 downto 15);
	o_rs2 <= i_instr(24 downto 20);
	o_csr <= c_csr;
	c_csr <=
		Csr_Time     when a_csrsel = x"c01" else
		Csr_Timeh    when a_csrsel = x"c81" else
		Csr_Timecmp  when a_csrsel = x"7c0" else
		Csr_Timecmph when a_csrsel = x"7c1" else
		Csr_Irqen    when a_csrsel = x"7c2" else
		Csr_Irqpen   when a_csrsel = x"7c3" else
		Csr_Instret  when a_csrsel = x"c02" else
		Csr_Instreth when a_csrsel = x"c82" else
		Csr_Mtvec    when a_csrsel = x"305" else
		Csr_Mepc     when a_csrsel = x"341" else
		Csr_Mtval    when a_csrsel = x"343" else
		Csr_Mie      when a_csrsel = x"304" else
		Csr_Mip      when a_csrsel = x"344" else
		Csr_Mstatus  when a_csrsel = x"300" else
		Csr_Mcause   when a_csrsel = x"342" else
		Csr_NoCsr;

	o_trp_badinstr <= r_trp_badinstr;
	o_trp_ecall <= r_trp_ecall;
	o_op <= r_op;
	o_type <= r_type;
	o_rd <= r_rd;
	o_imm <= r_imm;
	o_csrimm <= r_csrimm;
	o_funct3 <= r_funct3;
	o_funct7 <= r_funct7;

end architecture;
