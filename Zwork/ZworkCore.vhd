library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkCore is
	generic (
		g_reset_vector : std_logic_vector(31 downto 0) := x"00000010";
		g_mtvec        : std_logic_vector(31 downto 0) := x"00000020"
	);
	port (
		clk       : in  std_logic;
		resetn    : in  std_logic;
		bus_ack   : in  std_logic;
		bus_rdata : in  std_logic_vector(31 downto 0);
		bus_act   : out std_logic;
		bus_wnr   : out std_logic;
		bus_byten : out std_logic_vector( 3 downto 0);
		bus_addr  : out std_logic_vector(31 downto 0);
		bus_wdata : out std_logic_vector(31 downto 0);
		interrupt : in  std_logic_vector(31 downto 0)
	);
end entity;

-- Core can be interrupted if:
	-- Global interrupt (MIE) ist set in rcsr_mstatus(0) [equals mstatus(3)]
	-- Interrupt Type is enabled (rcsr_mie(2 downto 0))
-- When core is interrupted
	-- MIE is copied to MPIE (rcsr_mstatus(1))
	-- mepc <= pc
	-- pc <= mtvec
	-- etc.
-- When MRET is executed
	-- MPIE is copied back to MIE and MPIE set to 0
	-- pc <= mepc

architecture rtl of ZworkCore is

	signal r_state : e_State := State_FetchWriteback;
	signal r_pc : unsigned(31 downto 0) := unsigned(g_reset_vector);

	signal r_funct3 : std_logic_vector(2 downto 0);
	signal r_op1    : std_logic_vector(31 downto 0);
	signal r_op2    : std_logic_vector(31 downto 0);
	signal r_op3    : std_logic_vector(31 downto 0);
	signal r_csrval : std_logic_vector(31 downto 0);
	signal r_csrres : std_logic_vector(31 downto 0);
	signal r_rd     : unsigned(4 downto 0) := (others => '0');
	signal r_op     : e_Opcode;
	signal r_reg1   : boolean;
	signal r_reg2   : boolean;
	signal r_res    : std_logic_vector(31 downto 0);
	signal r_csr    : e_Csr;
	signal r_csrpen : boolean := false;
	signal r_multi  : boolean := false;
	signal r_mulss  : std_logic_vector(63 downto 0);
	signal r_mulsu  : std_logic_vector(65 downto 0);
	signal r_muluu  : std_logic_vector(63 downto 0);

	signal c_op1     : std_logic_vector(31 downto 0);
	signal c_op2     : std_logic_vector(31 downto 0);
	signal c_timer   : boolean;
	signal c_memaddr : std_logic_vector(31 downto 0);

	signal reg_addr1 : unsigned(4 downto 0);
	signal reg_addr2 : unsigned(4 downto 0);
	signal reg_wren1 : std_logic;
	signal reg_dati1 : std_logic_vector(31 downto 0);
	signal reg_dato1 : std_logic_vector(31 downto 0);
	signal reg_dato2 : std_logic_vector(31 downto 0);

	signal div_result : std_logic_vector(31 downto 0);
	signal div_done   : boolean;
	signal div_start  : boolean := false;

	signal rcsr_mtvec   : std_logic_vector(31 downto 0) := g_mtvec;
	signal rcsr_mcause  : std_logic_vector(4 downto 0);
	signal rcsr_mepc    : std_logic_vector(31 downto 0);
	signal rcsr_time    : std_logic_vector(63 downto 0) := (others => '0');
	signal rcsr_instret : std_logic_vector(63 downto 0) := (others => '0');
	signal rcsr_mtval   : std_logic_vector(31 downto 0);
	signal rcsr_mie     : std_logic_vector(2 downto 0) := "000";
	signal rcsr_mip     : std_logic_vector(2 downto 0) := "000";
	signal rcsr_mstatus : std_logic_vector(1 downto 0);
	signal rcsr_irqen   : std_logic_vector(31 downto 0);
	signal rcsr_irqpen  : std_logic_vector(31 downto 0);
	signal rcsr_timecmp : std_logic_vector(63 downto 0);

	component ZworkRegister is
		port (
			clk      : in std_logic;
			i_addr_a : in unsigned(4 downto 0);
			i_addr_b : in unsigned(4 downto 0);
			i_dati_a : in std_logic_vector(31 downto 0);
			i_wren_a : in std_logic := '1';
			i_dato_a : out std_logic_vector(31 downto 0);
			i_dato_b : out std_logic_vector(31 downto 0)
		);
	end component;

	component ZworkDivider is
		port (
			clk      : in  std_logic;
			dividend : in  std_logic_vector(31 downto 0);
			divisor  : in  std_logic_vector(31 downto 0);
			result   : out std_logic_vector(31 downto 0);
			op       : in  e_Opcode;
			start    : in  boolean;
			done     : out boolean
		);
	end component;
	

begin

	com_registers: ZworkRegister
		port map (
			clk      => clk,
			i_addr_a => reg_addr1,
			i_addr_b => reg_addr2,
			i_dati_a => reg_dati1,
			i_wren_a => reg_wren1,
			i_dato_a => reg_dato1,
			i_dato_b => reg_dato2
		);

	com_divider: ZworkDivider
		port map (
			clk      => clk,
			dividend => reg_dato1,
			divisor  => reg_dato2,
			result   => div_result,
			op       => r_op,
			start    => div_start,
			done     => div_done
		);

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
		if (resetn = '0') then
			r_pc <= unsigned(g_reset_vector);
			r_state <= State_FetchWriteback;
			r_rd <= "00000";
			bus_act <= '0';
		elsif (rising_edge(clk)) then

			-- Prepare aliases
			va_immi := (others => bus_rdata(31));
			va_immi(10 downto 0) := bus_rdata(30 downto 20);
			va_imms := (others => bus_rdata(31));
			va_imms(10 downto 0) := bus_rdata(30 downto 25) & bus_rdata(11 downto 7);
			va_immb := (others => bus_rdata(31));
			va_immb(11 downto 0) := bus_rdata(7) & bus_rdata(30 downto 25) & bus_rdata(11 downto 8) & "0";
			va_immu := bus_rdata(31 downto 12) & x"000";
			va_immj := (others => bus_rdata(31));
			va_immj(19 downto 0) := bus_rdata(19 downto 12) & bus_rdata(20) & bus_rdata(30 downto 21) & "0";
			va_funct3 := bus_rdata(14 downto 12);
			va_funct7 := bus_rdata(31 downto 25);
			va_inst62 := bus_rdata(6 downto 2);

			-- Default Assignments
			reg_wren1 <= '0';

			-- Every Clock
			rcsr_time <= std_logic_vector(unsigned(rcsr_time) + 1);
			rcsr_irqpen <= interrupt;
			if ((interrupt and rcsr_irqen) /= x"00000000") then
				rcsr_mip(2) <= '1';
			else 
				rcsr_mip(2) <= '0';
			end if;
			if (unsigned(rcsr_time) >= unsigned(rcsr_timecmp)) then
				rcsr_mip(1) <= '1';
			else
				rcsr_mip(1) <= '0';
			end if;

			-- Core
			if (r_state = State_FetchWriteback) then

				-- Writeback
				if (r_rd /= 0) then
					reg_wren1 <= '1';
				end if;
				rcsr_instret <= std_logic_vector(unsigned(rcsr_instret) + 1);

				-- Writeback CSRs
				if (r_csrpen) then
					r_csrpen <= false;
					case r_csr is
						when Csr_Mtvec => rcsr_mtvec <= r_csrres;
						when Csr_Mepc => rcsr_mepc <= r_csrres;
						when Csr_Mie =>
							rcsr_mie(2) <= r_csrres(11);
							rcsr_mie(1) <= r_csrres(7);
							rcsr_mie(0) <= r_csrres(3);
						when Csr_Mip => rcsr_mip(0) <= r_csrres(3);
						when Csr_Mstatus =>
							rcsr_mstatus(1) <= r_csrres(7);
							rcsr_mstatus(0) <= r_csrres(3);
						when Csr_Irqen => rcsr_irqen <= r_csrres;
						when Csr_Timecmp => rcsr_timecmp(31 downto 0) <= r_csrres;
						when Csr_Timecmph => rcsr_timecmp(63 downto 32) <= r_csrres;
						when others => null;
					end case;
				end if;

				-- Fetch
				if (r_pc = x"00000000") then
					r_state <= State_Trap;
					rcsr_mcause <= "00001";
				elsif (r_pc(1 downto 0) /= "00") then
					r_state <= State_Trap;
					rcsr_mcause <= "00000";
				elsif (rcsr_mstatus(0) = '1' and (rcsr_mie(1) and rcsr_mip(1)) = '1') then
					r_state <= State_Trap;
					rcsr_mcause <= "10111";
				elsif (rcsr_mstatus(0) = '1' and (rcsr_mie(2) and rcsr_mip(2)) = '1') then
					r_state <= State_Trap;
					rcsr_mcause <= "11011";
				elsif (rcsr_mstatus(0) = '1' and (rcsr_mie(0) and rcsr_mip(0)) = '1') then
					r_state <= State_Trap;
					rcsr_mcause <= "10011";
				else
					r_state <= State_Decode;
					bus_act <='1';
					bus_wnr <= '0';
					bus_byten <= "1111";
					bus_addr <= std_logic_vector(r_pc);
				end if;

			-- DDDD   EEEEE   CCCC
			-- D   D  E      C
			-- D   D  EEEEE  C
			-- D   D  E      C
			-- DDDD   EEEEE   CCCC

			elsif (r_state = State_Decode and bus_ack = '1') then
				bus_act <= '0';
				r_state <= State_Execute;
				r_rd <= unsigned(bus_rdata(11 downto 7));
				r_reg1 <= false;
				r_reg2 <= false;
				r_funct3 <= va_funct3;
				r_op1 <= x"00000000";
				r_op2 <= x"00000000";

				case va_inst62 is
					when "01101" => -- LUI
						r_op <= Op_Add;
						r_op2 <= va_immu;
					when "00101" => -- AUIPC
						r_op <= Op_Add;
						r_op1 <= std_logic_vector(r_pc);
						r_op2 <= va_immu;
					when "11011" => -- JAL
						r_op <= Op_Jump;
						r_op1 <= std_logic_vector(r_pc);
						r_op2 <= va_immj;
					when "11001" => -- JALR
						r_op <= Op_Jump;
						r_reg1 <= true;
						r_op2 <= va_immi;
						if (va_funct3 /= "000") then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
						end if;
					when "11000" => -- Branch
						case va_funct3 is
							when "000" => r_op <= Op_BranchEq;
							when "001" => r_op <= Op_BranchNe;
							when "100" => r_op <= Op_BranchLt;
							when "101" => r_op <= Op_BranchGe;
							when "110" => r_op <= Op_BranchLtu;
							when "111" => r_op <= Op_BranchGeu;
							when others => null;
						end case;
						r_reg1 <= true;
						r_reg2 <= true;
						r_op3 <= va_immb;
						r_rd <= "00000";
						if (va_funct3(2 downto 1) = "01") then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
						end if;
					when "00000" => -- Load
						r_op <= Op_Load;
						r_reg1 <= true;
						r_op3 <= va_immi;
						if (va_funct3 = "011" or va_funct3 = "110" or va_funct3 = "111") then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
						end if;
					when "01000" => -- Store
						r_op <= Op_Store;
						r_rd <= "00000";
						r_reg1 <= true;
						r_reg2 <= true;
						r_op3 <= va_imms;
						if (va_funct3 = "011" or va_funct3(2) = '1') then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
						end if;
					when "00100" => -- OP-IMM
						case va_funct3 is
							when "000" => r_op <= Op_Add;
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
						end case;
						r_reg1 <= true;
						r_op2 <= va_immi;
						if (va_funct3 = "001" and va_funct7 /= "0000000") then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
						elsif (va_funct3 = "101" and (va_funct7 /= "0000000" and va_funct7 /= "0100000")) then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
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
							end case;
						end if;
						r_reg1 <= true;
						r_reg2 <= true;
						if (not(va_funct7 = "0000000" or (va_funct7 = "0100000" and (va_funct3 = "000" or va_funct3 = "101")) -- RV32I valid
						or va_funct7 = "0000001")) then
							r_state <= State_Trap;
							rcsr_mtval <= bus_rdata;
							rcsr_mcause <= "00010";
						end if;
					when "11100" => -- System
						if (bus_rdata = x"30200073") then -- MRET
							r_op <= Op_Mret;
							r_rd <= "00000";
						elsif (bus_rdata = x"00000073") then -- ECALL
							r_state <= State_Trap;
							rcsr_mcause <= "01000";
						else
							r_op1 <= "000000000000000000000000000" & bus_rdata(19 downto 15);
							if (va_funct3(2) = '0') then
								r_reg1 <= true;
							end if;
							case va_funct3(1 downto 0) is
								when "00" => null;
								when "01" => r_op <= Op_Csrw;
								when "10" => r_op <= Op_Csrs;
								when "11" => r_op <= Op_Csrc;
							end case;
							case va_immi(11 downto 0) is
								when x"c01" =>
									r_csrval <= rcsr_time(31 downto 0);
									r_csr <= Csr_Time;
								when x"c81" =>
									r_csrval <= rcsr_time(63 downto 32);
									r_csr <= Csr_Timeh;
								when x"7c0" =>
									r_csrval <= rcsr_timecmp(31 downto 0);
									r_csr <= Csr_Timecmp;
								when x"7c1" =>
									r_csrval <= rcsr_timecmp(63 downto 32);
									r_csr <= Csr_Timecmph;
								when x"7c2" =>
									r_csrval <= rcsr_irqen;
									r_csr <= Csr_Irqen;
								when x"7c3" =>
									r_csrval <= rcsr_irqpen;
									r_csr <= Csr_Irqpen;
								when x"c02" =>
									r_csrval <= rcsr_instret(31 downto 0);
									r_csr <= Csr_Instret;
								when x"c82" =>
									r_csrval <= rcsr_instret(63 downto 32);
									r_csr <= Csr_Instreth;
								when x"305" =>
									r_csrval <= rcsr_mtvec;
									r_csr <= Csr_Mtvec;
								when x"341" =>
									r_csrval <= rcsr_mepc;
									r_csr <= Csr_Mepc;
								when x"343" =>
									r_csrval <= rcsr_mtval;
									r_csr <= Csr_Mtval;
								when x"304" =>
									r_csrval <= (others => '0');
									r_csrval(11) <= rcsr_mie(2);
									r_csrval(7) <= rcsr_mie(1);
									r_csrval(3) <= rcsr_mie(0);
									r_csr <= Csr_Mie;
								when x"344" =>
									r_csrval <= (others => '0');
									r_csrval(11) <= rcsr_mip(2);
									r_csrval(7) <= rcsr_mip(1);
									r_csrval(3) <= rcsr_mip(0);
									r_csr <= Csr_Mip;
								when x"300" =>
									r_csrval <= (others => '0');
									r_csrval(7) <= rcsr_mstatus(1);
									r_csrval(3) <= rcsr_mstatus(0);
									r_csr <= Csr_Mstatus;
								when x"342" =>
									r_csrval <= (others => '0');
									r_csrval(3 downto 0) <= rcsr_mcause(3 downto 0);
									r_csrval(31) <= rcsr_mcause(4);
									r_csr <= Csr_Mcause;
								when others =>
									r_state <= State_Trap;
									rcsr_mtval <= bus_rdata;
									rcsr_mcause <= "00010";
							end case;
						end if;
					when others =>
						r_state <= State_Trap;
						rcsr_mtval <= bus_rdata;
						rcsr_mcause <= "00010";
				end case;

				if (bus_rdata(1 downto 0) /= "11") then
					r_state <= State_Trap;
					rcsr_mtval <= bus_rdata;
					rcsr_mcause <= "00010";
				end if;
				
			-- EEEEE  X   X  EEEEE
			-- E       X X   E
			-- EEEEE    X    EEEEE
			-- E       X X   E
			-- EEEEE  X   X  EEEEE

			elsif (r_state = State_Execute) then

				r_pc <= r_pc + 4;
				r_state <= State_FetchWriteback;
				r_res <= (others => '0');

				case r_op is
					when Op_Jump =>
						r_pc <= unsigned(c_op1) + unsigned(c_op2);
						r_res <= std_logic_vector(unsigned(r_pc) + 4);
					when Op_BranchEq =>
						if (c_op1 = c_op2) then
							r_pc <= r_pc + unsigned(r_op3);
						end if;
					when Op_BranchNe =>
						if (c_op1 /= c_op2) then
							r_pc <= r_pc + unsigned(r_op3);
						end if;
					when Op_BranchLt =>
						if (signed(c_op1) < signed(c_op2)) then
							r_pc <= r_pc + unsigned(r_op3);
						end if;
					when Op_BranchGe =>
						if (signed(c_op1) >= signed(c_op2)) then
							r_pc <= r_pc + unsigned(r_op3);
						end if;
					when Op_BranchLtu =>
						if (unsigned(c_op1) < unsigned(c_op2)) then
							r_pc <= r_pc + unsigned(r_op3);
						end if;
					when Op_BranchGeu =>
						if (unsigned(c_op1) >= unsigned(c_op2)) then
							r_pc <= r_pc + unsigned(r_op3);
						end if;
					when Op_Load =>
						r_state <= State_Memory;
						bus_act <= '1';
						bus_wnr <= '0';
						bus_addr <= c_memaddr;
						case r_funct3(1 downto 0) is
							when "00" => 
								bus_byten <= "0001";
							when "01" =>
								if (c_memaddr(0) /= '0') then
									r_state <= State_Trap;
									rcsr_mtval <= c_memaddr;
									rcsr_mcause <= "00100";
									bus_act <= '0';
								end if;
								bus_byten <= "0011";
							when "10" =>
								if (c_memaddr(1 downto 0) /= "00") then
									r_state <= State_Trap;
									rcsr_mtval <= c_memaddr;
									rcsr_mcause <= "00100";
									bus_act <= '0';
								end if;
								bus_byten <= "1111";
							when others => null;
						end case;
						if (c_memaddr = x"00000000") then
							r_state <= State_Trap;
							rcsr_mtval <= c_memaddr;
							rcsr_mcause <= "00101";
							bus_act <= '0';
						end if;
					when Op_Store =>
						r_state <= State_Memory;
						bus_act <= '1';
						bus_wnr <= '1';
						bus_wdata <= reg_dato2;
						bus_addr <= c_memaddr;
						case r_funct3(1 downto 0) is
							when "00" => 
								bus_byten <= "0001";
							when "01" =>
								if (c_memaddr(0) /= '0') then
									r_state <= State_Trap;
									rcsr_mtval <= c_memaddr;
									rcsr_mcause <= "00110";
									bus_act <= '0';
								end if;
								bus_byten <= "0011";
							when "10" =>
								if (c_memaddr(1 downto 0) /= "00") then
									r_state <= State_Trap;
									rcsr_mtval <= c_memaddr;
									rcsr_mcause <= "00110";
									bus_act <= '0';
								end if;
								bus_byten <= "1111";
							when others => null;
						end case;
						if (c_memaddr = x"00000000") then
							r_state <= State_Trap;
							rcsr_mtval <= c_memaddr;
							rcsr_mcause <= "00111";
							bus_act <= '0';
						end if;
					when Op_Add =>
						r_res <= std_logic_vector(unsigned(c_op1) + unsigned(c_op2));
					when Op_Slt =>
						if (signed(c_op1) < signed(c_op2)) then
							r_res <= x"00000001";
						else
							r_res <= x"00000000";
						end if;
					when Op_Sltu =>
						if (unsigned(c_op1) < unsigned(c_op2)) then
							r_res <= x"00000001";
						else
							r_res <= x"00000000";
						end if;
					when Op_Xor =>
						r_res <= c_op1 xor c_op2;
					when Op_Or =>
						r_res <= c_op1 or c_op2;
					when Op_And =>
						r_res <= c_op1 and c_op2;
					when Op_Sll =>
						r_res <= std_logic_vector(shift_left(unsigned(c_op1), to_integer(unsigned(c_op2(4 downto 0)))));
					when Op_Srl =>
						r_res <= std_logic_vector(shift_right(unsigned(c_op1), to_integer(unsigned(c_op2(4 downto 0)))));
					when Op_Sra =>
						r_res <= std_logic_vector(shift_right(signed(c_op1), to_integer(unsigned(c_op2(4 downto 0)))));
					when Op_Sub =>
						r_res <= std_logic_vector(unsigned(c_op1) - unsigned(c_op2));
					when Op_Mul | Op_Mulh | Op_Mulhsu | Op_Mulhu =>
						if (r_multi) then
							r_multi <= false;
							case r_op is
								when Op_Mul => r_res <= r_mulss(31 downto 0);
								when Op_Mulh => r_res <= r_mulss(63 downto 32);
								when Op_Mulhsu => r_res <= r_mulsu(63 downto 32);
								when Op_Mulhu => r_res <= r_muluu(63 downto 32);
								when others => null;
							end case;
						else
							r_mulss <= std_logic_vector(signed(reg_dato1) * signed(reg_dato2));
							r_mulsu <= std_logic_vector(signed(reg_dato1(31) & reg_dato1) * signed('0' & reg_dato2));
							r_muluu <= std_logic_vector(unsigned(reg_dato1) * unsigned(reg_dato2));
							r_multi <= true;
							r_pc <= r_pc;
							r_state <= State_Execute;
						end if;
					when Op_Div | Op_Divu | Op_Rem | Op_Remu =>
						if (r_multi and div_done) then
							r_multi <= false;
							r_res <= div_result;
						elsif (r_multi and not div_done) then
							r_state <= State_Execute;
							r_pc <= r_pc;
						else 
							r_state <= State_Execute;
							r_pc <= r_pc;
							r_multi <= true;
						end if;
					when Op_Mret =>
						r_pc <= unsigned(rcsr_mepc);
						rcsr_mstatus(0) <= rcsr_mstatus(1);
					when Op_Csrw =>
						r_res <= r_csrval;
						r_csrres <= c_op1;
						r_csrpen <= true;
					when Op_Csrs =>
						r_res <= r_csrval;
						r_csrres <= c_op1 or r_csrval;
						if (c_op1 /= x"00000000") then
							r_csrpen <= true;
						end if;
					when Op_Csrc =>
						r_res <= r_csrval;
						r_csrres <= not c_op1 and r_csrval;
						if (c_op1 /= x"00000000") then
							r_csrpen <= true;
						end if;
					end case;

			-- M   M  EEEEE  M   M
			-- MM MM  E      MM MM
			-- M M M  EEEEE  M M M
			-- M   M  E      M   M
			-- M   M  EEEEE  M   M

			elsif (r_state = State_Memory and bus_ack = '1') then
				r_state <= State_FetchWriteback;
				bus_act <= '0';
				if (r_op = Op_Load) then
					case r_funct3 is
						when "000" =>
							r_res <= (others => bus_rdata(7));
							r_res(7 downto 0) <= bus_rdata(7 downto 0);
						when "001" =>
							r_res <= (others => bus_rdata(15));
							r_res(15 downto 0) <= bus_rdata(15 downto 0);
						when "010" => r_res <= bus_rdata;
						when "100" => r_res <= x"000000" & bus_rdata(7 downto 0);
						when "101" => r_res <= x"0000" & bus_rdata(15 downto 0);
						when others => null;
					end case;
				end if;
			
			elsif (r_state = State_Trap) then
				r_state <= State_FetchWriteback;
				r_rd <= "00000";
				r_pc <= unsigned(rcsr_mtvec);
				rcsr_mepc <= std_logic_vector(r_pc);
				rcsr_mstatus(1) <= rcsr_mstatus(0);
				rcsr_mstatus(0) <= '0';
			end if;

		end if;
	end process;

	c_op1 <= reg_dato1 when r_reg1 else r_op1;
	c_op2 <= reg_dato2 when r_reg2 else r_op2;
	c_memaddr <= std_logic_vector(unsigned(reg_dato1) + unsigned(r_op3));

	reg_dati1 <= r_res;
	reg_addr1 <= r_rd when reg_wren1 = '1' else unsigned(bus_rdata(19 downto 15));
	reg_addr2 <= unsigned(bus_rdata(24 downto 20));

	div_start <= 
		(r_op = Op_Div or
		r_op = Op_Divu or
		r_op = Op_Rem or
		r_op = Op_Remu) and
		r_multi = false and
		r_state = State_Execute;

end architecture;
