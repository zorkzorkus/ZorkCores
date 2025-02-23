library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

-- todo: make everything work?
-- todo: generics for i2s configuration

entity AvalonI2S is
	generic (
		BUFFER_BITLENGTH : natural := 5
	);
	port (

		clk_sys : in  std_logic;
		clk_i2s : in  std_logic;
		resetn  : in  std_logic;

		avalon_address       : in std_logic_vector(2 downto 0);
		avalon_writedata     : in std_logic_vector(31 downto 0);
		avalon_write         : in std_logic;
		avalon_read          : in std_logic;
		avalon_readdata      : out std_logic_vector(31 downto 0);
		avalon_waitrequest   : out std_logic;
		avalon_irq           : out std_logic;

		i2s_mclk : out std_logic;
		i2s_wclk : out std_logic;
		i2s_sclk : out std_logic;
		i2s_dato : out std_logic;
		i2s_dati : in  std_logic

	);
end entity;

-- register map
-- 000 status & control
	-- 0  0x01 out irq enable (wr)
	-- 1  0x02 out irq active (r)
	-- 2  0x04 in irq enable (wr)
	-- 3  0x08 in irq active (r)
	-- 4  0x10 core enable (wr)
-- 001 out occupancy
-- 010 in occupancy
-- 011 out mark
-- 100 in mark
-- 101 buffer length
-- 110 reserverd
-- 111 DATA

architecture rtl of AvalonI2S is

	-- Ring buffer FIFO with Clock Domain Crossing signals
	type fifo_type is array (0 to (2**BUFFER_BITLENGTH)-1) of std_logic_vector(31 downto 0);
	signal out_fifo : fifo_type;
	signal out1_f_w : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal out1_m_w : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal out1_s_w : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal out2_f_r : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal out2_m_r : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal out2_s_r : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal in_fifo : fifo_type;
	signal in2_f_w : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal in2_m_w : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal in2_s_w : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal in1_f_r : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal in1_m_r : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal in1_s_r : integer range 0 to (2**BUFFER_BITLENGTH)-1 := 0;
	signal cdc1_m_enable : std_logic := '0';
	signal cdc1_s_enable : std_logic := '0';


	-- RISC-V core / avalon bus signals, exclusively in fastclk domain
	signal sa_out_fill     : std_logic_vector(BUFFER_BITLENGTH-1 downto 0);
	signal sa_in_fill      : std_logic_vector(BUFFER_BITLENGTH-1 downto 0);

	signal ra_out_mark     : std_logic_vector(BUFFER_BITLENGTH-1 downto 0) := std_logic_vector(to_unsigned(2**(BUFFER_BITLENGTH-1), BUFFER_BITLENGTH));
	signal ra_in_mark      : std_logic_vector(BUFFER_BITLENGTH-1 downto 0) := std_logic_vector(to_unsigned(2**(BUFFER_BITLENGTH-1), BUFFER_BITLENGTH));
	signal ra_status       : std_logic_vector(4 downto 0) := "00000";
	signal ra_writecounter : std_logic_vector(31 downto 0) := x"00000000";
	signal ra_waitrequest  : std_logic := '0';

	-- I2S signals, exclusively in slowclk domain
	signal rs_out_word : std_logic_vector(31 downto 0);
	signal rs_in_word : std_logic_vector(31 downto 0);
	signal rs_bitcounter : integer range 0 to 31;
	signal rs_prescaler : integer range 0 to 7 := 0;
	signal rs_wclk : std_logic := '0';

begin

	process (clk_sys, resetn) begin
		if (resetn = '0') then
			ra_out_mark <= std_logic_vector(to_unsigned(2**(BUFFER_BITLENGTH-1), BUFFER_BITLENGTH));
			ra_in_mark <= std_logic_vector(to_unsigned(2**(BUFFER_BITLENGTH-1), BUFFER_BITLENGTH));
			ra_status(0) <= '0';
			ra_status(2) <= '0';
			ra_status(4) <= '0';
			ra_writecounter <= x"00000000";
			ra_waitrequest <= '0';
		elsif (rising_edge(clk_sys)) then

			ra_waitrequest <= '1';

			if (avalon_write = '1' and ra_waitrequest = '1') then

				ra_waitrequest <= '0';

				case avalon_address is
					when "000" =>
						ra_status(0) <= avalon_writedata(0);
						ra_status(2) <= avalon_writedata(2);
						ra_status(4) <= avalon_writedata(4);
					when "011" => ra_out_mark <= avalon_writedata(BUFFER_BITLENGTH-1 downto 0);
					when "100" => ra_in_mark <= avalon_writedata(BUFFER_BITLENGTH-1 downto 0);
					when "111" =>
						if not (out1_f_w + 1 = out2_f_r) then
							out1_f_w <= out1_f_w + 1;
							ra_writecounter <= std_logic_vector(unsigned(ra_writecounter) + 1);
							out_fifo(out1_f_w) <= avalon_writedata;
						else
							-- Buffer is full, assert waitsignal
								ra_waitrequest <= '1';
						end if;
					when others => null;
				end case;

			elsif (avalon_read = '1' and ra_waitrequest = '1') then

				ra_waitrequest <= '0';
				avalon_readdata <= (others => '0');

				case avalon_address is
					when "000" => avalon_readdata(4 downto 0) <= ra_status;
					when "001" => avalon_readdata(BUFFER_BITLENGTH-1 downto 0) <= sa_out_fill;
					when "010" => avalon_readdata(BUFFER_BITLENGTH-1 downto 0) <= sa_in_fill;
					when "011" => avalon_readdata(BUFFER_BITLENGTH-1 downto 0) <= ra_out_mark;
					when "100" => avalon_readdata(BUFFER_BITLENGTH-1 downto 0) <= ra_in_mark;
					when "101" => avalon_readdata(BUFFER_BITLENGTH-1 downto 0) <= std_logic_vector(to_unsigned((2**BUFFER_BITLENGTH)-1, BUFFER_BITLENGTH));
					when "110" => avalon_readdata <= ra_writecounter;
					when "111" =>
						if (ra_status(4) = '0') then
							-- core disabled, return 0 (default)
						elsif not (in2_f_w = in1_f_r) then
							avalon_readdata <= in_fifo(in1_f_r);
							in1_f_r <= in1_f_r + 1;
						else
							-- core enabled, but no data available, wait
							ra_waitrequest <= '1';
						end if;
					when others => null;
				end case;

				if (avalon_address = "111") then
					if not (in1_f_r = in2_f_w) then
						avalon_readdata <= in_fifo(in1_f_r);
						in1_f_r <= in1_f_r + 1;
					end if;
				end if;

			end if;

		end if;
	end process;

	-- Metastability Synchronization Chain
	process (clk_sys, clk_i2s) begin
		if (rising_edge(clk_sys)) then
			out2_m_r <= out2_s_r;
			out2_f_r <= out2_m_r;
			in2_m_w <= in2_s_w;
			in2_f_w <= in2_m_w;
		end if;
		if (rising_edge(clk_i2s)) then
			out1_m_w <= out1_f_w;
			out1_s_w <= out1_m_w;
			in1_m_r <= in1_f_r;
			in1_s_r <= in1_m_r;
			cdc1_m_enable <= ra_status(4);
			cdc1_s_enable <= cdc1_m_enable;
		end if;
	end process;

	-- TODO: IN sampling of i2s data
	process (clk_i2s) begin
		if (rising_edge(clk_i2s) and cdc1_s_enable = '1') then

			rs_prescaler <= rs_prescaler + 1;

			if (rs_prescaler = 0) then

				i2s_sclk <= '1';
				rs_bitcounter <= rs_bitcounter + 1;
				i2s_dato <= rs_out_word(31);
				rs_out_word(31 downto 1) <= rs_out_word(30 downto 0);
				rs_in_word(0) <= i2s_dati;
				rs_in_word(31 downto 1) <= rs_in_word(30 downto 0);

				-- Try to get new word from ring buffer when shifting out last bit of previous word
				-- When there is no word available shift previous word again
				if (rs_bitcounter = 0) then
					if not (out1_s_w = out2_s_r) then
						out2_s_r <= out2_s_r + 1;
						rs_out_word <= out_fifo(out2_s_r);
					end if;
					if not (in2_s_w + 1 = in1_s_r) then
						in_fifo(in2_s_w) <= rs_in_word;
						in2_s_w <= in2_s_w + 1;
					end if;
					rs_wclk <= not rs_wclk;
				elsif (rs_bitcounter = 16) then
					rs_wclk <= not rs_wclk;
				end if;

			elsif (rs_prescaler = 4) then
				i2s_sclk <= '0';
			end if;

		end if;
	end process;

	-- combinatorial signals
	ra_status(1) <= '1' when unsigned(sa_out_fill) <= unsigned(ra_out_mark) else '0';
	ra_status(3) <= '1' when unsigned(sa_in_fill) >= unsigned(ra_in_mark) else '0';
	sa_out_fill <= std_logic_vector(to_unsigned(out1_f_w - out2_f_r, sa_out_fill'length));
	sa_in_fill <= std_logic_vector(to_unsigned(in2_f_w - in1_f_r, sa_in_fill'length));
	avalon_irq <= '1' when (ra_status(0)  = '1' and ra_status(1) = '1') or (ra_status(2) = '1' and ra_status(3) = '1') else '0';

	-- port signals
	avalon_waitrequest <= ra_waitrequest;
	i2s_wclk <= rs_wclk;
	i2s_mclk <= clk_i2s when cdc1_s_enable = '1' else '0';

end architecture;
