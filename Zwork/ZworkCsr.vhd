library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkCsr is
	generic (
		g_mtvec : std_logic_vector(31 downto 0) := x"00000008"
	);
	port (
		clk              : in  std_logic;
		resetn           : in  std_logic;
		i_state          : in  e_State;
		i_csrsel         : in  e_Csr;
		i_op             : in  e_Opcode;
		i_pc             : in  std_logic_vector(31 downto 0);
		i_pcnext         : in  std_logic_vector(31 downto 0);
		i_rs1            : in  std_logic_vector(31 downto 0);
		i_imm            : in  std_logic_vector(4 downto 0);
		i_badaddr        : in  std_logic_vector(31 downto 0);
		i_instr          : in  std_logic_vector(31 downto 0);
		i_trp_instalign  : in  boolean;
		i_trp_instaccess : in  boolean;
		i_trp_badinstr   : in  boolean;
		i_trp_loadalign  : in  boolean;
		i_trp_loadaccess : in  boolean;
		i_trp_storealign : in  boolean;
		i_trp_storeacess : in  boolean;
		i_trp_ecall      : in  boolean;
		i_trp_irqsoft    : in  boolean;
		i_trp_irqtimer   : in  boolean;
		i_trp_irqext     : in  boolean;
		i_interrupt      : in  std_logic_vector(31 downto 0);
		o_interrupts     : out std_logic_vector(2 downto 0);
		o_regres         : out std_logic_vector(31 downto 0);
		o_csr_mtvec      : out std_logic_vector(31 downto 0);
		o_csr_mepc       : out std_logic_vector(31 downto 0)
	);
end entity;

-- CSR mapping of partial registers
-- Some CSRs do not implement the full 32-bit word, instead the bits may be non-continguous
	-- MIE, MIP (machine only)
		-- (11) Ext
		-- (7) Timer
		-- (3) Soft
	-- MSTATUS
		-- (7) MPIE (previous IE)
		-- (3) MIE (interrupt enabled)
	-- MCAUSE
		-- only 16 bit code (3 downto 0) + 1 bit type (31)
		-- refer to priviledged spec, table 3.6
		-- interrupts implemented are (3 7 11) ex: timer interrupt is "10111"
		-- traps implemented are (0 1 2 4 5 6 7 11) (11 for ECALL)
	-- time timecmp instret are 64-bit registers with the high word of "xyz" addressable as "xyzh"

architecture rtl of ZworkCsr is

	signal rcsr_mtvec   : std_logic_vector(31 downto 0) := g_mtvec;
	signal rcsr_mcause  : std_logic_vector(4 downto 0) := (others => '0');
	signal rcsr_mepc    : std_logic_vector(31 downto 0) := (others => '0');
	signal rcsr_time    : std_logic_vector(63 downto 0) := (others => '0');
	signal rcsr_instret : std_logic_vector(63 downto 0) := (others => '0');
	signal rcsr_mtval   : std_logic_vector(31 downto 0) := (others => '0');
	signal rcsr_mie     : std_logic_vector(2 downto 0) := (others => '0');
	signal rcsr_mip     : std_logic_vector(2 downto 0) := (others => '0');
	signal rcsr_mstatus : std_logic_vector(1 downto 0) := (others => '0');
	signal rcsr_irqen   : std_logic_vector(31 downto 0) := (others => '0');
	signal rcsr_irqpen  : std_logic_vector(31 downto 0) := (others => '0');
	signal rcsr_timecmp : std_logic_vector(63 downto 0) := (others => '0');

	signal r_csrres : std_logic_vector(31 downto 0) := (others => '0');
	signal r_regres : std_logic_vector(31 downto 0) := (others => '0');

	signal r_prev_exe : boolean := false;
	signal r_csrwren  : boolean := false;
	signal r_csrsel   : e_Csr := Csr_NoCsr;

	signal c_trp_fetch : boolean;
	signal c_trp_dec   : boolean;
	signal c_trp_exe   : boolean;
	signal c_trp_irq   : boolean;
	signal c_trap      : boolean;
	

begin

	process (clk, resetn) begin
		if (resetn = '0') then
			rcsr_mtvec   <= g_mtvec;
			rcsr_mcause  <= (others => '0');
			rcsr_mepc    <= (others => '0');
			rcsr_time    <= (others => '0');
			rcsr_instret <= (others => '0');
			rcsr_mtval   <= (others => '0');
			rcsr_mie     <= (others => '0');
			rcsr_mip     <= (others => '0');
			rcsr_mstatus <= (others => '0');
			rcsr_irqen   <= (others => '0');
			rcsr_irqpen  <= (others => '0');
			rcsr_timecmp <= (others => '0');
			r_csrres     <= (others => '0');
			r_regres     <= (others => '0');
			r_prev_exe   <= false;
			r_csrwren    <= false;
			r_csrsel     <= Csr_NoCsr;
elsif rising_edge(clk) then

			rcsr_irqpen <= i_interrupt;
			rcsr_time <= std_logic_vector(unsigned(rcsr_time) + 1);
			if (r_prev_exe and i_state = State_FetchWriteback) then
				rcsr_instret <= std_logic_vector(unsigned(rcsr_instret) + 1);
			end if;

			if ((rcsr_irqen and rcsr_irqpen) /= x"00000000") then
				rcsr_mip(2) <= '1';
			else
				rcsr_mip(2) <= '0';
			end if;

			if (unsigned(rcsr_time) >= unsigned(rcsr_timecmp)) then
				rcsr_mip(1) <= '1';
			else
				rcsr_mip(1) <= '0';
			end if;

			r_prev_exe <= i_state = State_Execute;

			if (c_trap) then
				if (c_trp_irq or c_trp_fetch) then
					rcsr_mepc <= i_pcnext;
				else
					rcsr_mepc <= i_pc;
				end if;
				rcsr_mstatus(1) <= rcsr_mstatus(0);
				rcsr_mstatus(0) <= '0';
			elsif (i_state = State_Decode) then

				r_regres <= (others => '0');

				r_csrsel <= i_csrsel;
				case i_csrsel is
					when Csr_Mtvec => r_regres <= rcsr_mtvec;
					when Csr_Mepc => r_regres <= rcsr_mepc;
					when Csr_Mtval => r_regres <= rcsr_mtval;
					when Csr_Mie =>
						r_regres(11) <= rcsr_mie(2);
						r_regres(7) <= rcsr_mie(1);
						r_regres(3) <= rcsr_mie(0);
					when Csr_Mip =>
						r_regres(11) <= rcsr_mip(2);
						r_regres(7) <= rcsr_mip(1);
						r_regres(3) <= rcsr_mip(0);
					when Csr_Mstatus =>
						r_regres(7) <= rcsr_mstatus(1);
						r_regres(3) <= rcsr_mstatus(0);
					when Csr_Mcause =>
						r_regres(31) <= rcsr_mcause(4);
						r_regres(3 downto 0) <= rcsr_mcause(3 downto 0);
					when Csr_Irqen => r_regres <= rcsr_irqen;
					when Csr_Irqpen => r_regres <= rcsr_irqpen;
					when Csr_Time => r_regres <= rcsr_time(31 downto 0);
					when Csr_Timeh => r_regres <= rcsr_time(63 downto 32);
					when Csr_Timecmp => r_regres <= rcsr_timecmp(31 downto 0);
					when Csr_Timecmph => r_regres <= rcsr_timecmp(63 downto 32);
					when Csr_Instret => r_regres <= rcsr_instret(31 downto 0);
					when Csr_Instreth => r_regres <= rcsr_instret(63 downto 32);
					when others => null;
				end case;

			elsif (i_state = State_Execute) then

				r_csrwren <=
					(i_op = Op_Csrrw or i_op = Op_Csrrwi) or
					((i_op = Op_Csrrs or i_op = Op_Csrrw) and i_rs1 /= x"00000000") or
					((i_op = Op_Csrrsi or i_op = Op_Csrrwi) and i_imm /= x"00000");

				case i_op is
					-- TODO: FATAL BUG; reading timer overwrites the values
					-- there is a section in the spec that takes about when writes to csr are to be ignored
					when Op_Csrrw  => r_csrres <= i_rs1;
					when Op_Csrrs  => r_csrres <= i_rs1 or r_regres;
					when Op_Csrrc  => r_csrres <= (not i_rs1) and r_regres;
					when Op_Csrrwi => r_csrres <= (x"000000" & "000" & i_imm);
					when Op_Csrrsi => r_csrres <= (x"000000" & "000" & i_imm) or r_regres;
					when Op_Csrrci => r_csrres <= (x"ffffff" & "111" & (not i_imm)) and r_regres;
					when Op_Mret   => rcsr_mstatus(0) <= rcsr_mstatus(1);
					when others => null;
				end case;
			elsif (i_state = State_FetchWriteback and r_csrwren) then

				case r_csrsel is
					when Csr_Mtvec => rcsr_mtvec <= r_csrres;
					when Csr_Mepc => rcsr_mepc <= r_csrres;
					when Csr_Mtval => rcsr_mtval <= r_csrres;
					when Csr_Mie =>
						rcsr_mie(2) <= r_csrres(11);
						rcsr_mie(1) <= r_csrres(7);
						rcsr_mie(0) <= r_csrres(3);
					when Csr_Mip =>
					-- timer and ext are not writeable
					-- 	rcsr_mip(2) <= r_csrres(11);
					-- 	rcsr_mip(1) <= r_csrres(7);
						rcsr_mip(0) <= r_csrres(3);
					when Csr_Mstatus =>
						rcsr_mstatus(1) <= r_csrres(7);
						rcsr_mstatus(0) <= r_csrres(3);
					--when Csr_Mcause => rcsr_mcause <= r_csrres(4 downto 0);
					when Csr_Irqen => rcsr_irqen <= r_csrres;
					--when Csr_Irqpen => rcsr_irqpen <= r_csrres; every clock the pending external interrupts are written here
					when Csr_Time => rcsr_time(31 downto 0) <= r_csrres;
					when Csr_Timeh => rcsr_time(63 downto 32) <= r_csrres;
					when Csr_Timecmp => rcsr_timecmp(31 downto 0) <= r_csrres;
					when Csr_Timecmph => rcsr_timecmp(63 downto 32) <= r_csrres;
					when Csr_Instret => rcsr_instret(31 downto 0) <= r_csrres;
					when Csr_Instreth => rcsr_instret(63 downto 32) <= r_csrres;
					when others => null;
				end case;

			end if;

			if (c_trp_fetch) then
				if (i_trp_instaccess) then
					rcsr_mcause <= "00001";
				elsif (i_trp_instalign) then
					rcsr_mcause <= "00000";
					rcsr_mtval <= i_pcnext;
				end if;
			elsif (c_trp_dec) then
				if (i_trp_badinstr) then
					rcsr_mcause <= "00010";
					rcsr_mtval <= i_instr;
				elsif (i_trp_ecall) then
					rcsr_mcause <= "01011";
				end if;
			elsif (c_trp_exe) then
				if (i_trp_loadalign) then
					rcsr_mcause <= "00100";
					rcsr_mtval <= i_badaddr;
				elsif (i_trp_loadaccess) then
					rcsr_mcause <= "00101";
				elsif (i_trp_storealign) then
					rcsr_mcause <= "00110";
					rcsr_mtval <= i_badaddr;
				elsif (i_trp_storeacess) then
					rcsr_mcause <= "00111";
				end if;
			elsif (c_trp_irq) then
				if (i_trp_irqext) then
					rcsr_mcause <= "11011";
				elsif (i_trp_irqtimer) then
					rcsr_mcause <= "10111";
				elsif (i_trp_irqsoft) then
					rcsr_mcause <= "10011";
				end if;
			end if;

		end if;
	end process;

-- TODO !! IMPORTANT !! ZORK
-- what if a jump occures at the same time an interrupt is triggered
-- does mepc store the corrent address?

	o_regres    <= r_regres;
	o_csr_mtvec <= rcsr_mtvec;
	o_csr_mepc  <= rcsr_mepc;
	o_interrupts <= rcsr_mip and rcsr_mie when rcsr_mstatus(0) = '1' else "000";

	c_trp_fetch <= i_trp_instaccess or i_trp_instalign;
	c_trp_dec   <= i_trp_badinstr or i_trp_ecall;
	c_trp_exe   <= i_trp_loadaccess or i_trp_loadalign or i_trp_storeacess or i_trp_storealign;
	c_trp_irq   <= i_trp_irqext or i_trp_irqsoft or i_trp_irqtimer;
	c_trap      <= c_trp_fetch or c_trp_dec or c_trp_exe or c_trp_irq;

end architecture;
