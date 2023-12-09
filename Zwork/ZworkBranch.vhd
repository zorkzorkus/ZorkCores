library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkBranch is
	generic (
		g_reset_vector : std_logic_vector(31 downto 0) := x"00000010"
	);
	port (
		clk        : in  std_logic;
		resetn     : in  std_logic;
		i_active   : in  boolean;
		i_op       : in  e_Opcode;
		i_mepc     : in  std_logic_vector(31 downto 0);
		i_imm      : in  std_logic_vector(31 downto 0);
		i_rs1      : in  std_logic_vector(31 downto 0);
		i_rs2      : in  std_logic_vector(31 downto 0);
		i_pc       : in  std_logic_vector(31 downto 0);
		o_pc       : out std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of ZworkBranch is

	signal r_pcnext : std_logic_vector(31 downto 0) := g_reset_vector;

	signal c_pc_jumpbranch   : std_logic_vector(31 downto 0);
	signal c_pc_jumpregister : std_logic_vector(31 downto 0);
	signal c_pc_nextinst     : std_logic_vector(31 downto 0);

begin

	process (clk, resetn) begin
		if (resetn = '0') then
			r_pcnext <= g_reset_vector;
		elsif rising_edge(clk) then
			if (i_active) then
				case i_op is
					when Op_Jal => r_pcnext <= c_pc_jumpbranch;
					when Op_Jalr => r_pcnext <= c_pc_jumpregister;
					when Op_Beq =>
						if (i_rs1 = i_rs2) then
							r_pcnext <= c_pc_jumpbranch;
						else
							r_pcnext <= c_pc_nextinst;
						end if;
					when Op_Bne =>
						if (i_rs1 /= i_rs2) then
							r_pcnext <= c_pc_jumpbranch;
						else
							r_pcnext <= c_pc_nextinst;
						end if;
					when Op_Blt =>
						if (signed(i_rs1) < signed(i_rs2)) then
							r_pcnext <= c_pc_jumpbranch;
						else
							r_pcnext <= c_pc_nextinst;
						end if;
					when Op_Bge =>
						if (signed(i_rs1) >= signed(i_rs2)) then
							r_pcnext <= c_pc_jumpbranch;
						else
							r_pcnext <= c_pc_nextinst;
						end if;
					when Op_Bltu =>
						if (unsigned(i_rs1) < unsigned(i_rs2)) then
							r_pcnext <= c_pc_jumpbranch;
						else
							r_pcnext <= c_pc_nextinst;
						end if;
					when Op_Bgeu =>
						if (unsigned(i_rs1) >= unsigned(i_rs2)) then
							r_pcnext <= c_pc_jumpbranch;
						else
							r_pcnext <= c_pc_nextinst;
						end if;
					when Op_Mret =>
						r_pcnext <= i_mepc;
					when others => r_pcnext <= c_pc_nextinst;
				end case;
			end if;
		end if;
	end process;

	o_pc <= r_pcnext;

	c_pc_jumpbranch   <= std_logic_vector(unsigned(i_pc) + unsigned(i_imm));
	c_pc_jumpregister <= std_logic_vector(unsigned(i_rs1) + unsigned(i_imm));
	c_pc_nextinst     <= std_logic_vector(unsigned(i_pc) + 4);

end architecture;
