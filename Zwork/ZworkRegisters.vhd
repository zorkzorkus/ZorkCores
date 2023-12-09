library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkRegisters is
	port (
		clk      : in  std_logic;
		resetn   : in  std_logic;
		i_write  : in  boolean;
		i_rs1    : in  std_logic_vector(4 downto 0);
		i_rs2    : in  std_logic_vector(4 downto 0);
		i_rd     : in  std_logic_vector(4 downto 0);
		i_result : in  std_logic_vector(31 downto 0);
		o_reg1   : out std_logic_vector(31 downto 0);
		o_reg2   : out std_logic_vector(31 downto 0)
	);
end entity;

-- Register Unit
-- Implements the general purpose registers with 2 dual ported rams
-- Registers have 3 ports (write, read_1, read_2) therefore implementation with 2 dual-ports
-- where the write port is tied together

-- Alternative implementation may be to use state as input and multiplex one address for rs2 and rd

architecture rtl of ZworkRegisters is

	component AvalonDualPortRam is
		port (
			clk   : in  std_logic;
			raddr : in  integer range 0 to 31;
			waddr : in  integer range 0 to 31;
			data  : in  std_logic_vector(31 downto 0);
			we    : in  std_logic := '1';
			q     : out std_logic_vector(31 downto 0)
		);
	end component;

	signal c_rs1 : integer range 0 to 31;
	signal c_rs2 : integer range 0 to 31;
	signal c_rd  : integer range 0 to 31;
	signal c_we  : std_logic;

begin

	com_reg1 : component AvalonDualPortRam
		port map (
			clk   => clk,
			raddr => c_rs1,
			waddr => c_rd,
			data  => i_result,
			we    => c_we,
			q     => o_reg1
		);

	com_reg2 : component AvalonDualPortRam
		port map (
			clk   => clk,
			raddr => c_rs2,
			waddr => c_rd,
			data  => i_result,
			we    => c_we,
			q     => o_reg2
		);

	c_rs1 <= to_integer(unsigned(i_rs1));
	c_rs2 <= to_integer(unsigned(i_rs2));
	c_rd  <= to_integer(unsigned(i_rd));
	c_we  <= '1' when i_rd /= "00000" and i_write else '0';

end architecture;
