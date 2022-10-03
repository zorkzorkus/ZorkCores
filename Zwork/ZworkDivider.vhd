library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

-- Set dividend and divisor
-- In the same clock pulse start for 1 clock
-- When the result is ready done is true for 1 clock

-- TODO: maybe optional reset???

entity ZworkDivider is
	port (
		clk      : in  std_logic;
		dividend : in  std_logic_vector(31 downto 0);
		divisor  : in  std_logic_vector(31 downto 0);
		result   : out std_logic_vector(31 downto 0);
		op       : in  e_Opcode;
		start    : in  boolean;
		done     : out boolean
	);
end ZworkDivider;

architecture rtl of ZworkDivider is

	signal s_dividend     : unsigned(31 downto 0);
	signal s_divisor      : unsigned(31 downto 0);
	signal s_shiftnext    : unsigned(32 downto 0); -- extra bit so it can be greater than dividend
	signal s_shiftprev    : unsigned(31 downto 0);
	signal s_shiftct      : unsigned(31 downto 0);
	signal s_result       : unsigned(31 downto 0);
	signal s_op           : e_Opcode;
	signal s_active       : boolean;
	signal s_neg_dividend : boolean;
	signal s_neg_divisor  : boolean;

begin

	process (clk) begin
		if (rising_edge(clk)) then

			done <= false; -- default assignment, gets overridden for 1 clock if result is ready
			if (start) then
				s_op <= op;
				if (divisor = x"00000000") then
					done <= true;
					if (op = Op_Rem or op = Op_Remu) then
						result <= dividend;
					else
						result <= x"00000000";
					end if;
				else
					if (op = Op_Div or op = Op_Rem) then -- signed operation
						if (dividend = x"80000000" and divisor = x"ffffffff") then
							if (op = Op_Div) then
								result <= x"80000000";
							else -- op = dRem
								result <= x"00000000";
							end if;
							done <= true;
						else
							if (dividend(31) = '1') then
								s_neg_dividend <= true;
								s_dividend <= to_unsigned(-to_integer(signed(dividend)), dividend'length);
							else
								s_neg_dividend <= false;
								s_dividend <= unsigned(dividend);
							end if;
							if (divisor(31) = '1') then
								s_neg_divisor <= true;
								s_divisor <= to_unsigned(-to_integer(signed(divisor)), divisor'length);
							else
								s_neg_divisor <= false;
								s_divisor <= unsigned(divisor);
							end if;
							s_result <= (others => '0');
							s_shiftct <= (others => '0');
							s_active <= true;
						end if;
					else
						s_dividend <= unsigned(dividend);
						s_divisor <= unsigned(divisor);
						s_result <= (others => '0');
						s_shiftct <= (others => '0');
						s_active <= true;
					end if;
				end if;
			elsif (s_active) then
				if (s_dividend < s_divisor) then
					if (s_op = Op_Div) then
						if (s_neg_dividend xor s_neg_divisor) then
							result <= std_logic_vector(to_signed(-to_integer(s_result), s_result'length));
						else
							result <= std_logic_vector(s_result);
						end if;
					elsif (s_op = Op_Divu) then
						result <= std_logic_vector(s_result);
					elsif (s_op = Op_Rem) then
						if (s_neg_dividend) then
							result <= std_logic_vector(to_signed(-to_integer(s_dividend), s_dividend'length));
						else
							result <= std_logic_vector(s_dividend);
						end if;
					elsif (s_op = Op_Remu) then
						result <= std_logic_vector(s_dividend);
					end if;
					done <= true;
					s_active <= false;
				elsif (s_shiftct = 0) then
					s_shiftct <= x"00000001";
					s_shiftnext(32 downto 0) <= s_divisor(31 downto 0) & "0";
					s_shiftprev <= s_divisor;
				else
					if (s_dividend < s_shiftnext) then
						s_dividend <= s_dividend - s_shiftprev;
						s_result <= s_result + s_shiftct;
						s_shiftct <= x"00000001";
						s_shiftnext(32 downto 0) <= s_divisor(31 downto 0) & "0";
						s_shiftprev <= s_divisor;
					else
						s_shiftct <= s_shiftct(30 downto 0) & "0";
						s_shiftnext <= s_shiftnext(31 downto 0) & "0";
						s_shiftprev <= s_shiftprev(30 downto 0) & "0";
					end if;
				end if;
			end if;

		end if;
	end process;

end rtl;
