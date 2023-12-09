library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkAlu is
	port (
		clk    : in  std_logic;
		resetn : in  std_logic;
		i_op   : in  e_Opcode;
		i_rs1  : in  std_logic_vector(31 downto 0);
		i_rs2  : in  std_logic_vector(31 downto 0);
		i_imm  : in  std_logic_vector(31 downto 0);
		i_pc   : in  std_logic_vector(31 downto 0);
		i_act  : in  boolean;
		o_res  : out std_logic_vector(31 downto 0);
		o_wait : out boolean
	);
end entity;

architecture rtl of ZworkAlu is

	signal r_res        : std_logic_vector(31 downto 0) := x"00000000";
	signal r_divact   : boolean := false;
	signal r_muldone  : boolean := false;
	signal r_mulreg   : boolean := false;
	signal r_mul1     : std_logic_vector(32 downto 0) := (others => '0');
	signal r_mul2     : std_logic_vector(32 downto 0) := (others => '0');
	signal r_mulres   : std_logic_vector(65 downto 0) := (others => '0');

	signal s_divdone  : boolean;
	signal s_divres   : std_logic_vector(31 downto 0);

	signal c_muldiv   : boolean;
	signal c_mul      : boolean;
	signal c_div      : boolean;
	signal c_divstart : boolean;

	component ZworkDivider is
		port (
			clk      : in  std_logic;
			i_dividend : in  std_logic_vector(31 downto 0);
			i_divisor  : in  std_logic_vector(31 downto 0);
			i_op       : in  e_Opcode;
			i_start    : in  boolean;
			o_result   : out std_logic_vector(31 downto 0);
			o_done     : out boolean
		);
	end component;

begin

	com_zworkdivider : component ZworkDivider
		port map (
			clk        => clk,
			i_dividend => i_rs1,
			i_divisor  => i_rs2,
			i_op       => i_op,
			i_start    => c_divstart,
			o_result   => s_divres,
			o_done     => s_divdone
		);

	process (clk, resetn) begin
		if (resetn = '0') then
			r_res     <= x"00000000";
			r_divact  <= false;
			r_muldone <= false;
			r_mulreg  <= false;
			r_mul1    <= (others => '0');
			r_mul2    <= (others => '0');
			r_mulres  <= (others => '0');
		elsif rising_edge(clk) then

			if (i_act) then

				case i_op is
					when Op_Lui =>
						r_res <= i_imm;
					when Op_Auipc =>
						r_res <= std_logic_vector(unsigned(i_pc) + unsigned(i_imm));
					when Op_Jal =>
						r_res <= std_logic_vector(unsigned(i_pc) + 4);
					when Op_Jalr =>
						r_res <= std_logic_vector(unsigned(i_pc) + 4);
					when Op_Addi =>
						r_res <= std_logic_vector(unsigned(i_rs1) + unsigned(i_imm));
					when Op_Slti =>
						if (signed(i_rs1) < signed(i_imm)) then
							r_res <= x"00000001";
						else
							r_res <= x"00000000";
						end if;
					when Op_Sltiu =>
						if (unsigned(i_rs1) < unsigned(i_imm)) then
							r_res <= x"00000001";
						else
							r_res <= x"00000000";
						end if;
					when Op_Xori =>
						r_res <= i_rs1 xor i_imm;
					when Op_Ori =>
						r_res <= i_rs1 or i_imm;
					when Op_Andi =>
						r_res <= i_rs1 and i_imm;
					when Op_Slli =>
						r_res <= std_logic_vector(shift_left(unsigned(i_rs1), to_integer(unsigned(i_imm(4 downto 0)))));
					when Op_Srli =>
						r_res <= std_logic_vector(shift_right(unsigned(i_rs1), to_integer(unsigned(i_imm(4 downto 0)))));
					when Op_Srai =>
						r_res <= std_logic_vector(shift_right(signed(i_rs1), to_integer(unsigned(i_imm(4 downto 0)))));
					when Op_Add =>
						r_res <= std_logic_vector(unsigned(i_rs1) + unsigned(i_rs2));
					when Op_Sub =>
						r_res <= std_logic_vector(unsigned(i_rs1) - unsigned(i_rs2));
					when Op_Sll =>
						r_res <= std_logic_vector(shift_left(unsigned(i_rs1), to_integer(unsigned(i_rs2(4 downto 0)))));
					when Op_Slt =>
						if (unsigned(i_rs1) < unsigned(i_rs2)) then
							r_res <= x"00000001";
						else
							r_res <= x"00000000";
						end if;
					when Op_Sltu =>
						if (unsigned(i_rs1) < unsigned(i_rs2)) then
							r_res <= x"00000001";
						else
							r_res <= x"00000000";
						end if;
					when Op_Xor =>
						r_res <= i_rs1 xor i_rs2;
					when Op_Srl =>
						r_res <= std_logic_vector(shift_right(unsigned(i_rs1), to_integer(unsigned(i_rs2(4 downto 0)))));
					when Op_Sra =>
						r_res <= std_logic_vector(shift_right(signed(i_rs1), to_integer(unsigned(i_rs2(4 downto 0)))));
					when Op_Or =>
						r_res <= i_rs1 or i_rs2;
					when Op_And =>
						r_res <= i_rs1 and i_rs2;
					when Op_Mul | Op_Mulh | Op_Mulhsu | Op_Mulhu =>

						if (r_muldone) then
							r_muldone <= false;
							r_mulreg <= false;
							r_muldone <= false;
							case i_op is
								when Op_Mul => r_res <= r_mulres(31 downto 0);
								when Op_Mulh => r_res <= r_mulres(63 downto 32);
								when Op_Mulhsu => r_res <= r_mulres(63 downto 32);
								when Op_Mulhu => r_res <= r_mulres(63 downto 32);
								when others => null;
							end case;
						elsif (r_mulreg) then
							r_mulres <= std_logic_vector(signed(r_mul1) * signed(r_mul2));
							r_muldone <= true;
						else
							r_mulreg <= true;
							r_mul1(31 downto 0) <= i_rs1;
							r_mul2(31 downto 0) <= i_rs2;
							if (i_op = Op_Mulhu) then
								r_mul1(32) <= '0';
							else
								r_mul1(32) <= r_mul1(31);
							end if;
							if (i_op = Op_Mulhsu or i_op = Op_Mulhu) then
								r_mul2(32) <= '0';
							else
								r_mul2(32) <= r_mul2(31);
							end if;
						end if;

					when Op_Div | Op_Divu | Op_Rem | Op_Remu =>
						if (not r_divact) then
							r_divact <= true;
						elsif (s_divdone) then
							r_res <= s_divres;
							r_divact <= false;
						end if;
					when others => null;
				end case;
			else
				r_muldone <= false;
			end if;
		end if;
	end process;

	o_res <= r_res;
	o_wait <=
		not s_divdone when c_div else
		not r_muldone when c_mul else
		false;


	c_mul <= i_op = Op_Mul or i_op = Op_Mulh or i_op = Op_Mulhsu or i_op = Op_Mulhu;
	c_div <= i_op = Op_Div or i_op = Op_Divu or i_op = Op_Rem or i_op = Op_Remu;
	c_muldiv <= c_mul or c_div;

	c_divstart <= c_div and not r_divact and i_act;

end architecture;
