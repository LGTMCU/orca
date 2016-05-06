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

    ADR_I   : in std_logic_vector(31 downto 0);
    DAT_I   : in std_logic_vector(31 downto 0);
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
                   t_ready,
                   read_command,
                   r_ready,
                   discard,
                   read_addr1,
                   read_addr2,
                   read_addr3,
                   t_blank,
                   read_data1,
                   read_data2,
                   read_data3,
                   read_data4,
                   end_frame,
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
  ACK_O <= done_flag;

  -- edge detection
--  process (CLK_I)
--  begin
--    if rising_edge(CLK_I) then
--      stall_s_1 <= cycle_valid and (not done_flag); -- new
--      stall_s_2 <= stall_s_1;                       -- old
--      if ((stall_s_1 = '1') and (stall_s_2 = '0')) then         -- rising edge
--        DEBUG(2) <= DEBUG(2) or '1';
--      end if;
--      if ((stall_s_1 = '0') and (stall_s_2 = '1')) then         -- falling edge
--        DEBUG(0) <= DEBUG(0) or '1';
--      end if;
--    end if;
--  end process;


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
      else
        stall_s_1 <= cycle_valid and (not done_flag); -- new
        stall_s_2 <= stall_s_1;                       -- old
        if ((stall_s_1 = '1') and (stall_s_2 = '0')) then         -- rising edge
          DEBUG(2) <= DEBUG(2) or '1';
        end if;
        if ((stall_s_1 = '0') and (stall_s_2 = '1')) then         -- falling edge
          DEBUG(0) <= DEBUG(0) or '1';
        end if;
        case state is
          when start => -- begin the frame
            IPLOAD <= '1';
            done_flag <= '0';
            if cycle_valid = '1' then
              adr_count <= (others => '0');
              byte_count <= (others => '0');
              adr_done <= '0';
              SBSTBi <= '1';
              SBWRi <= '1'; -- write
              SBADRi <= CR2_ADR; -- Control Register 2
              SBDATi <= FRAME_I;
              if SBACKo = '1' then
                SBSTBi <= '0';
                IPLOAD <= '0';
                state <= t_ready;
              end if;
            end if;

          when t_ready => -- Check if ready for transmission
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0'; -- read
              SBADRi <= SPISR_ADR;  -- SPI Status Register 
              if SBACKo = '1' then
                SBSTBi <= '0';
                if SBDATo(TRDY) = '1' then
                  state <= read_command;
                end if;
              end if;
            end if;

          when read_command => -- flash READ command
            if cycle_valid = '1' then
              SBSTBi <= '1'; 
              SBWRi <= '1'; -- write
              SBADRi <= TX_ADR;
              SBDATi <= READ; -- READ command for flash
              if SBACKo = '1' then
                SBSTBi <= '0';
                state <= r_ready;
              end if;
            end if;

          when r_ready => -- check if ready for reception
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0'; -- read
              SBADRi <= SPISR_ADR; -- SPI Status Register
              if SBACKo = '1' then
                SBSTBI <= '0';
                if SBDATo(RRDY) = '1' then
                  if adr_done = '0' then
                    state <= discard;
                  else
                    case byte_count is
                      when "00" =>
                        state <= read_data1;
                      when "01" =>
                        state <= read_data2;
                      when "10" =>
                        state <= read_data3;
                      when "11" =>
                        state <= read_data4;
                      when others =>  -- something went wrong, reset
                        state <= start;
                    end case;
                  end if;
                end if;
              end if;
            end if;

          when discard => -- discard the rx register value
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0'; -- read
              SBADRi <= RX_ADR;
              if SBACKo = '1' then
                SBSTBI <= '0';
                case adr_count is
                  when "00" =>
                    adr_done <= '0';
                    state <= read_addr1;
                  when "01" =>
                    adr_done <= '0';
                    state <= read_addr2;
                  when "10" =>
                    adr_done <= '0';
                    state <= read_addr3;
                  when "11" =>
                    adr_done <= '1';
                    state <= t_blank;
                  when others => -- something went wrong, reset
                    adr_done <= '0';
                    state <= start; 
                end case;
              end if; 
            end if;

          when read_addr1 => -- A[MAX] 
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '1'; -- write
              SBADRi <= TX_ADR;
              SBDATi <= ADR_I(23 downto 16); -- A[MAX] to read from 
              if SBACKo = '1' then
                adr_count <= adr_count + 1;  -- 0 -> 1
                SBSTBi <= '0'; 
                state <= r_ready; 
              end if;
            end if;

          when read_addr2 => -- A[MED]
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '1'; -- write
              SBADRi <= TX_ADR;
              SBDATi <= ADR_I(15 downto 8); -- A[MED] to read from 
              if SBACKo = '1' then
                adr_count <= adr_count + 1;  -- 1 -> 2
                SBSTBi <= '0';
                state <= r_ready;
              end if;
            end if;

          when read_addr3 => -- A[MIN]
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '1'; -- write
              SBADRi <= TX_ADR;
              SBDATi <= ADR_I(7 downto 0); -- A[MIN] to read from 
              if SBACKo = '1' then
                adr_count <= adr_count + 1;  -- 2 -> 3, done
                SBSTBi <= '0';
                state <= r_ready;
              end if;
            end if;

          when t_blank => -- write dummy byte
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '1'; -- write
              SBADRi <= TX_ADR;
              SBDATi <= DUMMY;
              if SBACKo = '1' then
                SBSTBi <= '0';
                state <= r_ready;
              end if;
            end if;
          
          when read_data1 =>  -- assuming little endian storage?
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0'; -- read
              SBADRi <= RX_ADR;
              if SBACKo = '1' then
                SBSTBi <= '0';
                data_reg(7 downto 0) <= SBDATo; -- LSB
                byte_count <= byte_count + 1;   -- 0 -> 1
                state <=  t_blank;
              end if;
            end if;

          when read_data2 =>
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0';
              SBADRi <= RX_ADR;
              if SBACKo = '1' then
                SBSTBi <= '0';
                data_reg(15 downto 8) <= SBDATo;
                byte_count <= byte_count + 1; -- 1 -> 2
                state <= t_blank;
              end if;
            end if;

          when read_data3 =>
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0';
              SBADRi <= RX_ADR;
              if SBACKo = '1' then
                SBSTBi <= '0';
                data_reg(23 downto 16) <= SBDATo;
                byte_count <= byte_count + 1; -- 2 -> 3
                state <= t_blank;
              end if;
            end if;

          when read_data4 =>
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '0';
              SBADRi <= RX_ADR;
              if SBACKo = '1' then
                SBSTBi <= '0';
                data_reg(31 downto 24) <= SBDATo; -- MSB
                byte_count <= byte_count + 1; -- 3 -> 0, overflow
                state <= end_frame;
              end if;
            end if;

          when end_frame => -- close the frame by writing to CR2
            if cycle_valid = '1' then
              SBSTBi <= '1';
              SBWRi <= '1';   -- write 
              SBADRi <= CR2_ADR;
              SBDATi <= FRAME_E;
              if SBACKo = '1' then
                SBSTBi <= '0';
                state <= done;
              end if;
            end if;

          when done =>  -- wait for TIP to be low
            if cycle_valid = '1' then 
              SBSTBi <= '1';
              SBWRi <= '0'; -- read
              SBADRi <= SPISR_ADR; 
              if SBACKo = '1' then
                SBSTBi <= '0';
                if SBDATo(TIP) = '0' then
                  DEBUG(1) <= DEBUG(1) or '1';
                  DAT_O <= data_reg;
                  done_flag <= '1';   -- data is ready, activate the core
                  state <= start;
                end if;
              end if;
            end if;

          when others =>
            state <= start;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
