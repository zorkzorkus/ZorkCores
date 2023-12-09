library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ZworkUtil.all;

entity ZworkCore is
	generic (
		g_reset_vector : std_logic_vector(31 downto 0) := x"00000004";
		g_mtvec        : std_logic_vector(31 downto 0) := x"00000008"
	);
	port (
		clk        : in  std_logic;
		resetn     : in  std_logic;
		bus_act    : out std_logic;
		bus_ack    : in  std_logic;
		bus_wnr    : out std_logic;
		bus_byten  : out std_logic_vector(3 downto 0);
		bus_addr   : out std_logic_vector(31 downto 0);
		bus_wdata  : out std_logic_vector(31 downto 0);
		bus_rdata  : in  std_logic_vector(31 downto 0);
		interrupt  : in  std_logic_vector(31 downto 0)
	);
end entity;

architecture rtl of ZworkCore is


	signal r_state   : e_State := State_FetchWriteback;

	signal c_res : std_logic_vector(31 downto 0);
	signal c_memact : boolean;
	signal c_regwrite : boolean;
	signal c_fchactive : boolean;
	signal c_decactive : boolean;
	signal c_exeactive : boolean;
	signal c_trap : boolean;
	signal c_busaddr : std_logic_vector(31 downto 0);

	-- driver for s_signal is in another ~castle~ module
	signal s_op      : e_Opcode;
	signal s_type    : e_Type;
	signal s_imm     : std_logic_vector(31 downto 0);
	signal s_csrimm  : std_logic_vector(4 downto 0);
	signal s_rd      : std_logic_vector(4 downto 0);
	signal s_rs1data : std_logic_vector(31 downto 0);
	signal s_rs2data : std_logic_vector(31 downto 0);
	signal s_rs1reg  : std_logic_vector(4 downto 0);
	signal s_rs2reg  : std_logic_vector(4 downto 0);
	signal s_funct3  : std_logic_vector(2 downto 0);
	signal s_funct7  : std_logic_vector(6 downto 0);
	signal s_pc      : std_logic_vector(31 downto 0);
	signal s_pcnext  : std_logic_vector(31 downto 0);
	signal s_alures  : std_logic_vector(31 downto 0);
	signal s_aluwait : boolean;
	signal s_memdone : boolean;
	signal s_memres  : std_logic_vector(31 downto 0);
	signal s_csr     : e_Csr;
	signal s_csrres  : std_logic_vector(31 downto 0);
	signal s_mem_wdata : std_logic_vector(31 downto 0);
	signal s_mem_addr  : std_logic_vector(31 downto 0);
	signal s_mem_byten : std_logic_vector(3 downto 0);
	signal s_mem_wnr   : std_logic;
	signal s_csr_mtvec : std_logic_vector(31 downto 0);
	signal s_csr_mepc  : std_logic_vector(31 downto 0);
	signal s_trp_instalign  : boolean;
	signal s_trp_instaccess : boolean;
	signal s_trp_badinstr   : boolean;
	signal s_trp_loadalign  : boolean;
	signal s_trp_loadaccess : boolean;
	signal s_trp_storealign : boolean;
	signal s_trp_storeacess : boolean;
	signal s_trp_ecall      : boolean;
	signal s_trp_irqext     : boolean;
	signal s_trp_irqsoft    : boolean;
	signal s_trp_irqtimer   : boolean;
	signal s_interrupts     : std_logic_vector(2 downto 0);

	signal r_instr   : std_logic_vector(31 downto 0) := (others => '0');

	component ZworkAlu is
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
	end component;

	component ZworkBranch is
		generic (
			g_reset_vector : std_logic_vector(31 downto 0) := x"00000004"
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
	end component;

	component ZworkCsr is
		generic (
			g_mtvec : std_logic_vector(31 downto 0) := x"00000008"
		);
		port (
			clk              : in  std_logic;
			resetn           : in  std_logic;
			i_state          : in  e_State;
			i_csrsel         : in  e_Csr;
			i_op             : in  e_Opcode;
			i_pc             : in  std_logic_vector(31 downto 0);
			i_pcnext         : in  std_logic_vector(31 downto 0);
			i_rs1            : in  std_logic_vector(31 downto 0);
			i_imm            : in  std_logic_vector(4 downto 0);
			i_badaddr        : in  std_logic_vector(31 downto 0);
			i_instr          : in  std_logic_vector(31 downto 0);
			i_trp_instalign  : in  boolean;
			i_trp_instaccess : in  boolean;
			i_trp_badinstr   : in  boolean;
			i_trp_loadalign  : in  boolean;
			i_trp_loadaccess : in  boolean;
			i_trp_storealign : in  boolean;
			i_trp_storeacess : in  boolean;
			i_trp_ecall      : in  boolean;
			i_trp_irqsoft    : in  boolean;
			i_trp_irqtimer   : in  boolean;
			i_trp_irqext     : in  boolean;
			i_interrupt      : in  std_logic_vector(31 downto 0);
			o_interrupts     : out std_logic_vector(2 downto 0);
			o_regres         : out std_logic_vector(31 downto 0);
			o_csr_mtvec      : out std_logic_vector(31 downto 0);
			o_csr_mepc       : out std_logic_vector(31 downto 0)
		);
	end component;

	component ZworkDecoder is
		port (
			clk            : in  std_logic;
			resetn         : in  std_logic;
			i_instr        : in  std_logic_vector(31 downto 0);
			i_active       : in  boolean;
			o_trp_badinstr : out boolean;
			o_trp_ecall    : out boolean;
			o_op           : out e_Opcode;
			o_type         : out e_Type;
			o_rd           : out std_logic_vector(4 downto 0);
			o_rs1          : out std_logic_vector(4 downto 0);
			o_rs2          : out std_logic_vector(4 downto 0);
			o_imm          : out std_logic_vector(31 downto 0);
			o_csrimm       : out std_logic_vector(4 downto 0);
			o_csr          : out e_Csr;
			o_funct3       : out std_logic_vector(2 downto 0);
			o_funct7       : out std_logic_vector(6 downto 0)
		);
	end component;

	component ZworkFetch is
		port (
			clk              : in  std_logic;
			resetn           : in  std_logic;
			i_active         : in  boolean;
			i_interrupts     : in  std_logic_vector(2 downto 0);
			i_ext_irqs       : in  std_logic_vector(31 downto 0);
			i_pc             : in  std_logic_vector(31 downto 0);
			i_mtvec          : in  std_logic_vector(31 downto 0);
			i_trp_badinstr   : in  boolean;
			i_trp_ecall      : in  boolean;
			i_trp_loadalign  : in  boolean;
			i_trp_loadaccess : in  boolean;
			i_trp_storealign : in  boolean;
			i_trp_storeacess : in  boolean;
			o_pc             : out std_logic_vector(31 downto 0);
			o_trp_instalign  : out boolean;
			o_trp_instaccess : out boolean;
			o_irq_soft       : out boolean;
			o_irq_timer      : out boolean;
			o_irq_ext        : out boolean
		);
	end component;

	component ZworkMemory is
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
	end component;

	component ZworkRegisters is
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
	end component;

begin

	com_zworkalu: ZworkAlu
		port map (
			clk    => clk,
			resetn => resetn,
			i_op   => s_op,
			i_rs1  => s_rs1data,
			i_rs2  => s_rs2data,
			i_imm  => s_imm,
			i_pc   => s_pc,
			i_act  => c_exeactive,
			o_res  => s_alures,
			o_wait => s_aluwait
		);

	com_zworkbranch: ZworkBranch
		generic map (
			g_reset_vector => g_reset_vector
		)
		port map (
			clk        => clk,
			resetn     => resetn,
			i_active   => c_exeactive,
			i_op       => s_op,
			i_mepc     => s_csr_mepc,
			i_imm      => s_imm,
			i_rs1      => s_rs1data,
			i_rs2      => s_rs2data,
			i_pc       => s_pc,
			o_pc       => s_pcnext
		);

	com_zworkcsr: ZworkCsr
		generic map (
			g_mtvec => g_mtvec
		)
		port map (
			clk              => clk,
			resetn           => resetn,
			i_state          => r_state,
			i_csrsel         => s_csr,
			i_op             => s_op,
			i_pc             => s_pc,
			i_pcnext         => s_pcnext,
			i_rs1            => s_rs1data,
			i_imm            => s_csrimm,
			i_badaddr        => c_busaddr, -- TODO: this signal is VERY LIKELY WRONG
			i_instr          => r_instr,
			i_trp_instalign  => s_trp_instalign,
			i_trp_instaccess => s_trp_instaccess,
			i_trp_badinstr   => s_trp_badinstr,
			i_trp_loadalign  => s_trp_loadalign,
			i_trp_loadaccess => s_trp_loadaccess,
			i_trp_storealign => s_trp_storealign,
			i_trp_storeacess => s_trp_storeacess,
			i_trp_ecall      => s_trp_ecall,
			i_trp_irqsoft    => s_trp_irqsoft,
			i_trp_irqtimer   => s_trp_irqtimer,
			i_trp_irqext     => s_trp_irqext,
			i_interrupt      => interrupt,
			o_interrupts     => s_interrupts,
			o_regres         => s_csrres,
			o_csr_mtvec      => s_csr_mtvec,
			o_csr_mepc       => s_csr_mepc
		);

	com_zworkdecoder: ZworkDecoder
		port map (
			clk            => clk,
			resetn         => resetn,
			i_instr        => bus_rdata,
			i_active       => c_decactive,
			o_trp_badinstr => s_trp_badinstr,
			o_trp_ecall    => s_trp_ecall,
			o_op           => s_op,
			o_type         => s_type,
			o_rd           => s_rd,
			o_rs1          => s_rs1reg,
			o_rs2          => s_rs2reg,
			o_imm          => s_imm,
			o_csrimm       => s_csrimm,
			o_csr          => s_csr,
			o_funct3       => s_funct3,
			o_funct7       => s_funct7
		);

	com_zworkfetch: ZworkFetch
		port map (
			clk              => clk,
			resetn           => resetn,
			i_active         => c_fchactive,
			i_interrupts     => s_interrupts,
			i_ext_irqs       => interrupt,
			i_pc             => s_pcnext,
			i_mtvec          => s_csr_mtvec,
			i_trp_badinstr   => s_trp_badinstr,
			i_trp_ecall      => s_trp_ecall,
			i_trp_loadalign  => s_trp_loadalign,
			i_trp_loadaccess => s_trp_loadaccess,
			i_trp_storealign => s_trp_storealign,
			i_trp_storeacess => s_trp_storeacess,
			o_pc             => s_pc,
			o_trp_instalign  => s_trp_instalign,
			o_trp_instaccess => s_trp_instaccess,
			o_irq_soft       => s_trp_irqsoft,
			o_irq_timer      => s_trp_irqtimer,
			o_irq_ext        => s_trp_irqext
		);

	com_zworkmemory: ZworkMemory
		port map (
			clk               => clk,
			resetn            => resetn,
			i_op              => s_op,
			i_active          => c_exeactive,
			i_imm             => s_imm,
			i_rs1             => s_rs1data,
			i_rs2             => s_rs2data,
			i_bus_ack         => bus_ack,
			i_bus_data        => bus_rdata,
			o_bus_addr        => s_mem_addr,
			o_bus_data        => s_mem_wdata,
			o_bus_wnr         => s_mem_wnr,
			o_bus_byten       => s_mem_byten,
			o_res             => s_memres,
			o_done            => s_memdone,
			o_trp_loadalign   => s_trp_loadalign,
			o_trp_loadaccess  => s_trp_loadaccess,
			o_trp_storealign  => s_trp_storealign,
			o_trp_storeaccess => s_trp_storeacess
		);

	com_zworkregisters: ZworkRegisters
		port map (
			clk      => clk,
			resetn   => resetn,
			i_write  => c_regwrite,
			i_rs1    => s_rs1reg,
			i_rs2    => s_rs2reg,
			i_rd     => s_rd,
			i_result => c_res,
			o_reg1   => s_rs1data,
			o_reg2   => s_rs2data
		);

	process (clk, resetn) begin
		if (resetn = '0') then
			r_state <= State_FetchWriteback;
		elsif rising_edge(clk) then
			if (c_trap) then
				-- In case of a trap, the next clock will already have the mtvec on the fetch addr
				-- So we can jump directly to decode and wait for ack
				r_state <= State_Decode;
			else
				case r_state is
					when State_FetchWriteback =>
						if (s_type /= Type_Mem or bus_ack = '1') then
							r_state <= State_Decode;
						end if;
					when State_Decode =>
						if (bus_ack = '1') then
							r_state <= State_Execute;
							r_instr <= bus_rdata;
						end if;
					when State_Execute =>
						if (s_type = Type_AluBrn) then
							if (not s_aluwait) then
								r_state <= State_FetchWriteback;
							end if;
						elsif (s_type = Type_Csr) then
							r_state <= State_FetchWriteback;
						elsif (s_type = Type_Mem) then
							r_state <= State_FetchWriteback;
						end if;
				end case;
			end if;
		end if;
	end process;
	-- TODO: there are exactly 2 entites the core should modify (side effects):
	-- 1. register
	-- 2. memory
	-- When a trap occures, the instruction shall not be executed,
	-- therefore stop bus_act here (and write in registers!)
	bus_act   <= '1' when r_state = State_Decode or c_memact else '0';
	bus_addr  <= c_busaddr;
	bus_wnr   <= s_mem_wnr when c_memact else '0';
	bus_byten <= s_mem_byten when c_memact else "1111"; -- even though for read access byten may be ignored
	bus_wdata <= s_mem_wdata;

	c_busaddr <= s_mem_addr when c_memact else s_pc;
	c_memact <= r_state = State_FetchWriteback and s_type = Type_Mem;
	c_fchactive <= r_state = State_FetchWriteback and (c_memact = (bus_ack = '1'));
	c_decactive <= r_state = State_Decode and bus_ack = '1';
	c_exeactive <= r_state = State_Execute;
	c_res <=
		s_csrres when s_type = Type_Csr else
		s_memres when s_type = Type_Mem else
		s_alures;
	c_regwrite <= r_state = State_FetchWriteback and (s_type /= Type_Mem or bus_ack = '1') and not c_trap;
	c_trap <= s_trp_badinstr or s_trp_ecall or
		s_trp_loadaccess or s_trp_loadalign or s_trp_storeacess or s_trp_storealign or
		s_trp_instaccess or s_trp_instalign or
		s_trp_irqext or s_trp_irqsoft or s_trp_irqtimer;

end architecture;
