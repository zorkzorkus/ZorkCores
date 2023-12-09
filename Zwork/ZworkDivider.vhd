library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkDivider is
	port (
		clk      : in  std_logic;
		i_dividend : in  std_logic_vector(31 downto 0);
		i_divisor  : in  std_logic_vector(31 downto 0);
		i_op       : in  e_Opcode;
		i_start    : in  boolean;
		o_result   : out std_logic_vector(31 downto 0);
		o_done     : out boolean
	);
end ZworkDivider;

architecture rtl of ZworkDivider is

	-- Dividend and Divisor are converted to unsigned (TWO-COMP)
	signal r_dividend     : unsigned(31 downto 0) := (others => '0');
	signal r_divisor      : unsigned(31 downto 0) := (others => '0');
	signal r_remainder    : unsigned(31 downto 0) := (others => '0');
	signal r_quotient     : unsigned(31 downto 0) := (others => '0');
	signal r_mask         : unsigned(31 downto 0) := (others => '0');
	signal r_active       : boolean := false;
	signal r_neg_dividend : boolean := false;
	signal r_neg_divisor  : boolean := false;

	signal r_done         : boolean := false;
	signal r_result       : std_logic_vector(31 downto 0) := (others => '0');

	signal c_new_rem      : unsigned(31 downto 0);


begin

	process (clk) begin
		-- TODO: resetn?
		if (rising_edge(clk)) then

			r_done <= false; -- default assignment, gets overridden for 1 clock if result is ready

			if (i_start) then

				-- always
				r_remainder <= x"00000000";
				r_quotient <= x"00000000";
				r_mask <= x"80000000";

				-- Start of Division; Check Inputs
				if (i_divisor = x"00000000") then

					-- Divisor is 0
					r_done <= true;
					if (i_op = Op_Rem or i_op = Op_Remu) then
						-- Rem and Remu return input (dividend)
						r_result <= i_dividend;
					else
						-- Div and Divu return all ones
						r_result <= x"ffffffff";
					end if;

				else

					if (i_op = Op_Div or i_op = Op_Rem) then

						-- Signed operation
						if (i_dividend = x"80000000" and i_divisor = x"ffffffff") then

							-- Signed overflow
							if (i_op = Op_Div) then
								-- Div returns min value / input
								r_result <= x"80000000";
							else -- i_op = Op_Rem
								-- Rem returns 0
								r_result <= x"00000000";
							end if;
							r_done <= true;

						else

							-- Valid inputs, but signed, convert them to unsigned (2's complement if negative)
							if (i_dividend(31) = '1') then
								r_neg_dividend <= true;
								r_dividend <= to_unsigned(-to_integer(signed(i_dividend)), i_dividend'length);
							else
								r_neg_dividend <= false;
								r_dividend <= unsigned(i_dividend);
							end if;
							if (i_divisor(31) = '1') then
								r_neg_divisor <= true;
								r_divisor <= to_unsigned(-to_integer(signed(i_divisor)), i_divisor'length);
							else
								r_neg_divisor <= false;
								r_divisor <= unsigned(i_divisor);
							end if;

							r_active <= true;

						end if;

					else

						-- Valid inputs with unsigned operation
						r_dividend <= unsigned(i_dividend);
						r_divisor <= unsigned(i_divisor);
						r_active <= true;

					end if;

				end if;

			elsif (r_active) then
				if (r_mask /= x"00000000") then
					if (c_new_rem >= r_divisor) then
						r_remainder <= c_new_rem - r_divisor;
						r_quotient <= r_quotient or r_mask; -- TODO mask only has 1 bit set, how to do this without 32 bit OR?
					else
						r_remainder <= c_new_rem;
					end if;
					r_dividend <= r_dividend(30 downto 0) & '0';
					r_mask <= '0' & r_mask(31 downto 1);
				else
					r_active <= false;
					r_done <= true;
					case i_op is
						when Op_Div =>
							if (r_neg_dividend xor r_neg_divisor) then
								r_result <= std_logic_vector(to_signed(-to_integer(signed(r_quotient)), r_quotient'length));
							else
								r_result <= std_logic_vector(r_quotient);
							end if;
						when Op_Divu =>
							r_result <= std_logic_vector(r_quotient);
						when Op_Rem =>
							if (r_neg_dividend) then
								r_result <= std_logic_vector(to_signed(-to_integer(signed(r_remainder)), r_remainder'length));
							else
								r_result <= std_logic_vector(r_remainder);
							end if;
						when Op_Remu =>
							r_result <= std_logic_vector(r_remainder);
						when others => null;
					end case;
				end if;
			end if;

		end if;
	end process;

	o_done <= r_done;
	o_result <= r_result;

	c_new_rem <= r_remainder(30 downto 0) & r_dividend(31);

end rtl;
