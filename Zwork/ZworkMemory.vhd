library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkMemory is
	port (
		clk               : in  std_logic;
		resetn            : in  std_logic;
		i_op              : in  e_Opcode;
		i_active          : in  boolean;
		i_imm             : in  std_logic_vector(31 downto 0);
		i_rs1             : in  std_logic_vector(31 downto 0);
		i_rs2             : in  std_logic_vector(31 downto 0);
		i_bus_ack         : in  std_logic;
		i_bus_data        : in  std_logic_vector(31 downto 0);
		o_bus_addr        : out std_logic_vector(31 downto 0);
		o_bus_data        : out std_logic_vector(31 downto 0);
		o_bus_wnr         : out std_logic;
		o_bus_byten       : out std_logic_vector(3 downto 0);
		o_res             : out std_logic_vector(31 downto 0);
		o_done            : out boolean;
		o_trp_loadalign   : out boolean;
		o_trp_loadaccess  : out boolean;
		o_trp_storealign  : out boolean;
		o_trp_storeaccess : out boolean
	);
end entity;

architecture rtl of ZworkMemory is

	signal c_op_load : boolean;
	signal c_op_store : boolean;

	signal c_bus_addr : std_logic_vector(31 downto 0);

	signal r_bus_addr        : std_logic_vector(31 downto 0) := (others => '0');
	signal r_bus_wdata       : std_logic_vector(31 downto 0) := (others => '0');
	signal r_bus_wnr         : std_logic := '0';
	signal r_bus_byten       : std_logic_vector(3 downto 0) := (others => '0');
	signal r_trp_loadalign   : boolean := false;
	signal r_trp_loadaccess  : boolean := false;
	signal r_trp_storealign  : boolean := false;
	signal r_trp_storeaccess : boolean := false;

begin

	process (clk, resetn) begin
		if (resetn = '0') then
			r_bus_addr <= (others => '0');
			r_bus_wdata <= (others => '0');
			r_bus_wnr <= '0';
			r_bus_byten <= (others => '0');
			r_trp_loadalign <= false;
			r_trp_loadaccess <= false;
			r_trp_storealign <= false;
			r_trp_storeaccess <= false;
		elsif rising_edge(clk) then

			r_trp_storeaccess <= false;
			r_trp_storealign <= false;
			r_trp_loadaccess <= false;
			r_trp_loadalign <= false;

			if (i_active) then
				if (c_op_store) then
					r_bus_wnr <= '1';
				else
					r_bus_wnr <= '0';
				end if;

				r_trp_storealign <= (i_op = Op_Sw and c_bus_addr(1 downto 0) /= "00")
					or (i_op = Op_Sh and c_bus_addr(0) /= '0');

				r_trp_loadalign <= (i_op = Op_Lw  and c_bus_addr(1 downto 0) /= "00")
					or (i_op = Op_Lhu and c_bus_addr(0) /= '0')
					or (i_op = Op_Lh  and c_bus_addr(0) /= '0');

				r_trp_storeaccess <= c_op_store and c_bus_addr = x"00000000";
				r_trp_loadaccess <= c_op_load and c_bus_addr = x"00000000";

				case i_op is
					when Op_Sb => r_bus_byten <= "0001";
					when Op_Sh => r_bus_byten <= "0011";
					when others => r_bus_byten <= "1111";
				end case;

				r_bus_addr <= c_bus_addr;
				r_bus_wdata <= i_rs2;

			end if;
		end if;
	end process;

	process (i_op, i_bus_data) begin
		case i_op is
			when Op_Lb =>
				o_res <= (others => i_bus_data(7));
				o_res(7 downto 0) <= i_bus_data(7 downto 0);
			when Op_Lh =>
				o_res <= (others => i_bus_data(15));
				o_res(15 downto 0) <= i_bus_data(15 downto 0);
			when Op_Lbu =>
				o_res <= (others => '0');
				o_res(7 downto 0) <= i_bus_data(7 downto 0);
			when Op_Lhu =>
				o_res <= (others => '0');
				o_res(15 downto 0) <= i_bus_data(15 downto 0);
			-- when Op_Lw =>
			when others =>
				o_res <= i_bus_data;
		end case;
	end process;

	c_bus_addr <= std_logic_vector(unsigned(i_rs1) + unsigned(i_imm));
	c_op_load <= (i_op = Op_Lb or i_op = Op_Lh or i_op = Op_Lw or i_op = Op_Lbu or i_op = Op_Lhu) and i_active;
	c_op_store <= (i_op = Op_Sb or i_op = Op_Sh or i_op = Op_Sw) and i_active;

	o_done <= i_bus_ack = '1';
	o_bus_data <= r_bus_wdata;

	o_bus_addr <= r_bus_addr;
	o_bus_byten <= r_bus_byten;
	o_bus_wnr <= r_bus_wnr;
	o_trp_loadalign <= r_trp_loadalign;
	o_trp_loadaccess <= r_trp_loadaccess;
	o_trp_storealign <= r_trp_storealign;
	o_trp_storeaccess <= r_trp_storeaccess;

end architecture;
