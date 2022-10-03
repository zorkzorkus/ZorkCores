library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkRegister is
	port (
		clk      : in std_logic;
		i_addr_a : in unsigned(4 downto 0);
		i_addr_b : in unsigned(4 downto 0);
		i_dati_a : in std_logic_vector(31 downto 0);
		i_wren_a : in std_logic := '1';
		i_dato_a : out std_logic_vector(31 downto 0);
		i_dato_b : out std_logic_vector(31 downto 0)
	);
end ZworkRegister;

architecture rtl of ZworkRegister is

	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector(31 downto 0);
	type memory_t is array(31 downto 0) of word_t;

	-- Declare the RAM
	signal ram : memory_t;

begin

	process(clk) begin
		if (rising_edge(clk)) then
			if (i_wren_a = '1') then
				ram(to_integer(i_addr_a)) <= i_dati_a;
			end if;
			i_dato_a <= ram(to_integer(i_addr_a));
			i_dato_b <= ram(to_integer(i_addr_b));
		end if;
	end process;

end rtl;
