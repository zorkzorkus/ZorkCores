library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkFetch is
	port (
		clk              : in  std_logic;
		resetn           : in  std_logic;
		i_active         : in  boolean;
		i_interrupts     : in  std_logic_vector(2 downto 0);
		i_ext_irqs       : in  std_logic_vector(31 downto 0);
		i_pc             : in  std_logic_vector(31 downto 0);
		i_mtvec          : in  std_logic_vector(31 downto 0);
		i_trp_badinstr   : in  boolean;
		i_trp_ecall      : in  boolean;
		i_trp_loadalign  : in  boolean;
		i_trp_loadaccess : in  boolean;
		i_trp_storealign : in  boolean;
		i_trp_storeacess : in  boolean;
		o_pc             : out std_logic_vector(31 downto 0);
		o_trp_instalign  : out boolean;
		o_trp_instaccess : out boolean;
		o_irq_soft       : out boolean;
		o_irq_timer      : out boolean;
		o_irq_ext        : out boolean
	);
end entity;

-- Fetch unit
-- Drives (instruction) bus to fetch instruction data
-- The i_mtvec address is fetched in this priority:
	-- Interrupt pending
	-- Instruction access fault (pc is 0)
	-- Instruction misalign fault (pc % 4 != 0)
-- Otherwise the i_pc address is fetched

architecture rtl of ZworkFetch is

	signal r_trp_instalign  : boolean := false;
	signal r_trp_instaccess : boolean := false;
	signal r_trp_irqext     : boolean := false;
	signal r_trp_irqtimer   : boolean := false;
	signal r_trp_irqsoft    : boolean := false;
	signal r_pc : std_logic_vector(31 downto 0) := (others => '0');

	signal c_trapped : boolean;

begin

	process (clk, resetn) begin
		if (resetn = '0') then

			r_trp_instaccess <= false;
			r_trp_instalign  <= false;
			r_trp_irqext     <= false;
			r_trp_irqtimer   <= false;
			r_trp_irqsoft    <= false;
			r_pc <= (others => '0');

		elsif rising_edge(clk) then

			r_trp_instaccess <= false;
			r_trp_instalign <= false;
			r_trp_irqext     <= false;
			r_trp_irqtimer   <= false;
			r_trp_irqsoft    <= false;

			if (c_trapped) then
				r_pc <= i_mtvec;
			elsif (i_active) then
				if (i_interrupts(2) = '1') then
					r_trp_irqext <= true;
					for i in 31 downto 0 loop
						if (i_ext_irqs(i) = '1') then
							r_pc <= std_logic_vector(unsigned(i_mtvec) + 12 + 4 * i);
						end if;
					end loop;
				elsif (i_interrupts(1) = '1') then
					r_trp_irqtimer <= true;
					r_pc <= std_logic_vector(unsigned(i_mtvec) + 8);
				elsif (i_interrupts(0) = '1') then
					r_trp_irqsoft <= true;
					r_pc <= std_logic_vector(unsigned(i_mtvec) + 4);
				elsif (i_pc = x"00000000") then
					r_trp_instaccess <= true;
					r_pc <= i_mtvec;
				elsif (i_pc(1 downto 0) /= "00") then
					r_trp_instalign <= true;
					r_pc <= i_mtvec;
				else
					r_pc <= i_pc;
				end if;
			end if;

		end if;
	end process;

	c_trapped <= i_trp_badinstr or i_trp_ecall or i_trp_loadalign or i_trp_loadaccess or i_trp_storeacess or i_trp_storealign;

	o_trp_instalign  <= r_trp_instalign;
	o_trp_instaccess <= r_trp_instaccess;
	o_irq_ext        <= r_trp_irqext;
	o_irq_timer      <= r_trp_irqtimer;
	o_irq_soft       <= r_trp_irqsoft;
	o_pc <= r_pc;

end architecture;
