library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- TOP LEVEL FILE
-- for Avalon/Qsys Component

entity ZworkAvalon is
	generic (
		g_reset_vector : std_logic_vector(31 downto 0) := x"00000004";
		g_mtvec        : std_logic_vector(31 downto 0) := x"00000008"
	);
	port (
		clk               : in  std_logic;
		resetn            : in  std_logic;
		mm_waitrequest    : in  std_logic;
		mm_read           : out std_logic;
		mm_write          : out std_logic;
		mm_byten          : out std_logic_vector(3 downto 0);
		mm_addr           : out std_logic_vector(31 downto 0);
		mm_wdata          : out std_logic_vector(31 downto 0);
		mm_rdata          : in  std_logic_vector(31 downto 0);
		interrupt         : in  std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of ZworkAvalon is

	signal s_act   : std_logic;
	signal s_ack   : std_logic;
	signal s_wnr   : std_logic;
	signal s_byten : std_logic_vector(3 downto 0);
	signal s_addr  : std_logic_vector(31 downto 0);
	signal s_rdata : std_logic_vector(31 downto 0);
	signal s_wdata : std_logic_vector(31 downto 0);

	alias a_addroff : std_logic_vector(1 downto 0) is s_addr(1 downto 0);

	component ZworkCore is
		generic (
			g_reset_vector : std_logic_vector(31 downto 0) := x"00000004";
			g_mtvec        : std_logic_vector(31 downto 0) := x"00000008"
		);
		port (
			clk       : in  std_logic;
			resetn    : in  std_logic;
			bus_act   : out std_logic;
			bus_ack   : in  std_logic;
			bus_wnr   : out std_logic;
			bus_byten : out std_logic_vector(3 downto 0);
			bus_addr  : out std_logic_vector(31 downto 0);
			bus_wdata : out std_logic_vector(31 downto 0);
			bus_rdata : in  std_logic_vector(31 downto 0);
			interrupt : in  std_logic_vector(31 downto 0)
		);
	end component;

begin

	com_zworkcore: component ZworkCore
		generic map (
			g_reset_vector => g_reset_vector,
			g_mtvec        => g_mtvec
		)
		port map (
			clk => clk,
			resetn => resetn,
			bus_act => s_act,
			bus_ack => s_ack,
			bus_wnr => s_wnr,
			bus_byten => s_byten,
			bus_addr => s_addr,
			bus_wdata => s_wdata,
			bus_rdata => s_rdata,
			interrupt => interrupt
		);

	-- Shifting address to be aligned on 4 bytes
	-- If requested bytes cross over alignment the RISC-V core has to issue a trap error.
	-- The shift here only translates access to partial words to operate on 32bit-word boundaries.
	mm_addr <= s_addr(31 downto 2) & "00";

	mm_byten <= s_byten when a_addroff = "00" else
		s_byten(2 downto 0) & "0"  when a_addroff = "01" else
		s_byten(1 downto 0) & "00" when a_addroff = "10" else
		s_byten(0) & "000";

	mm_wdata <= s_wdata when a_addroff = "00" else
		s_wdata(23 downto 0) & x"00" when a_addroff ="01" else
		s_wdata(15 downto 0) & x"0000" when a_addroff ="10" else
		s_wdata(7 downto 0) & x"000000";

	s_rdata <= mm_rdata when a_addroff = "00" else
		x"00" & mm_rdata(31 downto 8) when a_addroff ="01" else
		x"0000" & mm_rdata(31 downto 16) when a_addroff ="10" else
		x"000000" & mm_rdata(31 downto 24);

	mm_read <= s_act and not s_wnr;
	mm_write <= s_act and s_wnr;
	s_ack <= not mm_waitrequest and s_act;

end architecture;
