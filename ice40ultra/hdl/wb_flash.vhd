library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.top_util_pkg.all;
use work.top_component_pkg.all;

entity wb_flash is
  port (
  -- WishBone Signals
    CLK_I   : in std_logic;
    RST_I   : in std_logic;

    ADR_I   : in std_logic_vector(31 downto 0);   -- SPI register to write to
    DAT_I   : in std_logic_vector(31 downto 0);   -- value to write to SPI register
    WE_I    : in std_logic;
    CYC_I   : in std_logic;
    STB_I   : in std_logic;
    SEL_I   : in std_logic_vector(3 downto 0);
    CTI_I   : in std_logic_vector(2 downto 0);
    BTE_I   : in std_logic_vector(1 downto 0);
    LOCK_I  : in std_logic;
    
    ACK_O   : out std_logic;
    STALL_O : out std_logic;
    DAT_O   : out std_logic_vector(31 downto 0);
    ERR_O   : out std_logic;
    RTY_O   : out std_logic;

  -- Debug Signal
    DEBUG   : out std_logic_vector(2 downto 0);

  -- SPI Block Signals
    SPI1_MISO : inout std_logic;
    SPI1_MOSI : inout std_logic;
    SPI1_SCK  : inout std_logic;
    SPI1_MCSN : out std_logic_vector(3 downto 0);
    SPI1_SCSN : in std_logic);

end entity;

architecture rtl of wb_flash is
  component spi_flash is
    port (
      SPI1_MISO : inout std_logic;
      SPI1_MOSI : inout std_logic;
      SPI1_SCK  : inout std_logic;
      SPI1_SCSN : in std_logic;
      SPI1_MCSN : out std_logic_vector(3 downto 0);
      RST       : in std_logic;
      IPLOAD    : in std_logic;
      IPDONE    : out std_logic;
      SBCLKi    : in std_logic;
      SBWRi     : in std_logic;
      SBSTBi    : in std_logic;
      SBADRi    : in std_logic_vector(7 downto 0);
      SBDATi    : in std_logic_vector(7 downto 0);
      SBDATo    : out std_logic_vector(7 downto 0);
      SBACKo    : out std_logic;
      I2CPIRQ   : out std_logic_vector(1 downto 0);
      I2CPWKUP  : out std_logic_vector(1 downto 0);
      SPIPIRQ   : out std_logic_vector(1 downto 0);
      SPIPWKUP  : out std_logic_vector(1 downto 0)
    );
  end component;

  type state_t is (start, 
                   handler,
                   done);

  signal IPLOAD      : std_logic := '0';
  signal SBWRi       : std_logic;
  signal SBSTBi      : std_logic;
  signal SBADRi      : std_logic_vector(7 downto 0);
  signal SBDATi      : std_logic_vector(7 downto 0);
  signal IPDONE      : std_logic;
  signal SBDATo      : std_logic_vector(7 downto 0);
  signal SBACKo      : std_logic;
  signal I2CPIRQ     : std_logic_vector(1 downto 0); 
  signal I2CPWKUP    : std_logic_vector(1 downto 0);
  signal SPIPIRQ     : std_logic_vector(1 downto 0);
  signal SPIPWKUP    : std_logic_vector(1 downto 0);

  signal adr_count   : unsigned(1 downto 0)          := (others => '0');
  signal byte_count  : unsigned(1 downto 0)          := (others => '0');
  signal adr_done    : std_logic                     :=             '0';
  signal data_reg    : std_logic_vector(31 downto 0) := (others => '0');
  signal cycle_valid : std_logic;
  signal done_flag   : std_logic                     :=             '0';
  
  signal state       : state_t := start;
 
  -- upper address bits are 0x2 for left SPI block connected to flash 
  constant CR2_ADR   : std_logic_vector(7 downto 0) :=      X"2A";
  constant TX_ADR    : std_logic_vector(7 downto 0) :=      X"2D";
  constant RX_ADR    : std_logic_vector(7 downto 0) :=      X"2E";
  constant SPISR_ADR : std_logic_vector(7 downto 0) :=      X"2C";
  constant READ      : std_logic_vector(7 downto 0) :=      X"03";
  constant FRAME_I   : std_logic_vector(7 downto 0) :=      X"C0";
  constant FRAME_E   : std_logic_vector(7 downto 0) :=      X"80";
  constant TRDY      : natural                      :=          4;
  constant RRDY      : natural                      :=          3;
  constant TIP       : natural                      :=          7;
  constant BUSY      : natural                      :=          6;
  constant DUMMY     : std_logic_vector             :=      X"00";      

  signal stall_s_1   : std_logic                    :=        '0';
  signal stall_s_2   : std_logic                    :=        '0';


begin
  ERR_O   <= '0'; 
  RTY_O   <= '0'; 
  cycle_valid <= STB_I and CYC_I;
  STALL_O <= cycle_valid and (not done_flag);

  spi_soft : component spi_flash
    port map (
      SPI1_MISO => SPI1_MISO,   --  input from flash
      SPI1_MOSI => SPI1_MOSI,   --  output to flash
      SPI1_SCK  => SPI1_SCK,   --  CLK output to flash slave  
      SPI1_SCSN => SPI1_SCSN,  -- unused, not a slave
      SPI1_MCSN => SPI1_MCSN,  -- only using 1 flash slave, active low
      RST       => RST_I,
      IPLOAD    => IPLOAD,    -- ? begin configuration on positive edge
      IPDONE    => IPDONE, -- ? High when configuration is complete
      SBCLKi    => CLK_I,
      SBWRi     => SBWRi,   
      SBSTBi    => SBSTBi,
      SBADRi    => SBADRi,
      SBDATi    => SBDATi,  -- input data byte 
      SBDATo    => SBDATo,   -- output data byte
      SBACKo    => SBACKo,
      I2CPIRQ   => I2CPIRQ,   -- unused interrupt
      I2CPWKUP  => I2CPWKUP,  -- unused interrupt
      SPIPIRQ   => SPIPIRQ,   -- unused interrupt
      SPIPWKUP  => SPIPWKUP);  -- unused interrupt 
  

  process (CLK_I)
  begin
    if rising_edge(CLK_I) then
      if RST_I = '1' then
        state <= start;
        IPLOAD <= '0';
        done_flag <= '0';
        DEBUG <= "000";
        ACK_O <= '0';
      else
        IPLOAD <= '0';
        done_flag <= '0';
        case state is
          when start => 
            DEBUG <= "111";
            ACK_O <= '0';
--            IPLOAD <= '1';
            if (cycle_valid = '1') then
              state <= handler;
            end if;

          when handler =>
            DEBUG <= "100";
            if (cycle_valid = '1') then
              if (WE_I = '1') then  -- write
                SBSTBi <= '1';
                SBWRi <= '1';
                SBADRi <= ADR_I(9 downto 2);
                SBDATi <= DAT_I(7 downto 0);
                if (SBACKo = '1') then
                  SBSTBi <= '0';
                  done_flag <= '1';
                  state <= done;
                end if;
              else                  -- read
                SBSTBi <= '1';
                SBWRi <= '0';
                SBADRi <= ADR_I(9 downto 2);
                SBDATi <= X"00";
                if (SBACKo = '1') then
                  SBSTBi <= '0';
                  DAT_O <= X"000000" & SBDATo;
                  done_flag <= '1';
                  state <= done;
                end if;
              end if;
            end if;

          when done =>        -- let processor unstall
            DEBUG <= "101";
            done_flag <= '0';
            ACK_O <= '1';
            state <= start;
            
          when others =>
            state <= start;

        end case;
      end if;
    end if;
  end process;
end architecture rtl;
