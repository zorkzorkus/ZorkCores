-- Quartus Prime VHDL Template
-- Simple Dual-Port RAM with different read/write addresses but
-- single read/write clock

library ieee;
use ieee.std_logic_1164.all;

entity AvalonDualPortRam is
	port (
		clk   : in  std_logic;
		raddr : in  integer range 0 to 31;
		waddr : in  integer range 0 to 31;
		data  : in  std_logic_vector(31 downto 0);
		we    : in  std_logic := '1';
		q     : out std_logic_vector(31 downto 0)
	);
end AvalonDualPortRam;

architecture rtl of AvalonDualPortRam is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector(31 downto 0);
	type memory_t is array(31 downto 0) of word_t;

	-- Declare the RAM signal.
	signal ram : memory_t := (others => (others => '0'));
	signal r_q : std_logic_vector(31 downto 0) := (others => '0');

begin

	process (clk) begin
	if (rising_edge(clk)) then
		if(we = '1') then
			ram(waddr) <= data;
		end if;

		-- On a read during a write to the same address, the read will
		-- return the OLD data at the address
		r_q <= ram(raddr);
	end if;
	end process;

	q <= r_q;

end rtl;
