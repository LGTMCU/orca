library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.top_util_pkg.all;
use work.top_component_pkg.all;

entity spi_flash is
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
end entity;

architecture rtl of spi_flash is

  type state_t is (ip_load,
                   handle_command,
                   strobe_low,
                   transmit);

  signal state : state_t := ip_load;
  signal wait_count : unsigned(7 downto 0) := (others => '0');
  signal CR2_reg    : std_logic_vector(7 downto 0)   := (others => '0');
  signal TX_reg     : std_logic_vector(7 downto 0)   := (others => '0');
  signal RX_reg     : std_logic_vector(7 downto 0)   := (others => '0');
  signal SPISR_reg  : std_logic_vector(7 downto 0)   := (others => '0');
  signal intrn_rst  : std_logic                      :=             '0';

  signal cmd_count  : std_logic                      :=             '0';
  signal adr_count  : unsigned(1 downto 0)           := (others => '0');
  signal byte_count : natural                        :=               0;
  signal adr_reg    : std_logic_vector(23 downto 0)  := (others => '0');
  signal bad_adr    : std_logic                      :=             '0';
  
  constant CR2_ADR   : std_logic_vector(7 downto 0)  :=       X"2A";
  constant TX_ADR    : std_logic_vector(7 downto 0)  :=       X"2D";
  constant RX_ADR    : std_logic_vector(7 downto 0)  :=       X"2E";
  constant SPISR_ADR : std_logic_vector(7 downto 0)  :=       X"2C";
  constant READ      : std_logic_vector(7 downto 0)  :=       X"03";
  constant FRAME_I   : std_logic_vector(7 downto 0)  :=       X"C0";
  constant FRAME_E   : std_logic_vector(7 downto 0)  :=       X"80";
  constant TRDY      : natural                       :=           4;
  constant RRDY      : natural                       :=           3;
  constant TIP       : natural                       :=           7;
  constant DUMMY     : std_logic_vector(7 downto 0)  :=       X"00";      
  constant DATA      : std_logic_vector(31 downto 0) := X"DEADBEEF"; 

begin
  
  process(SBCLKi)
  begin
    if rising_edge(SBCLKi) then
      if RST = '1' then
        state <= ip_load;
      else
        case state is
          when ip_load =>
            if (IPLOAD = '1') or (intrn_rst = '1') then
              if wait_count = "00000011" then
                wait_count <= (others => '0');
                SPISR_reg(TRDY) <= '1';        -- ready for transmission
                SPISR_reg(RRDY) <= '0';        -- RX empty
                state <= handle_command;
                IPDONE <= '1';
                intrn_rst <= '0';                 -- config done
              else
                wait_count <= wait_count + 1;
                IPDONE <= '0';
              end if;
            end if;
          
          when handle_command =>
          if byte_count = 4 then          -- word finished transmitting
            cmd_count <= '0';
            adr_count <= "00";
            byte_count <= 0;     
          end if;
          if SBSTBi = '1' then
            if SBWRi = '1' then -- write cycle
              if wait_count /= "00000011" then
                wait_count <= wait_count + 1;
                SBACKo <= '0';
              else
                wait_count <= (others => '0');
                SBACKo <= '1';
                state <= strobe_low;
                case SBADRi is
                  when CR2_ADR =>
                    CR2_reg <= SBDATi;
                    intrn_rst <= '1';
                  when TX_ADR =>
                    TX_reg <= SBDATi;
                    SPISR_reg(TRDY) <= '0';  -- start transmission
                    SPISR_reg(TIP) <= '1';
                  when others =>
                    bad_adr <= '1';
                end case;
              end if;
            else                -- read cycle
              if wait_count /= "00000011" then
                wait_count <= wait_count + 1;
                SBACKo <= '0';
              else
                wait_count <= (others => '0');
                SBACKo <= '1';
                state <= strobe_low;
                case SBADRi is
                  when CR2_ADR =>
                    SBDATo <= CR2_reg;
                  when SPISR_ADR =>
                    SBDATo <= SPISR_reg;
                  when RX_ADR =>
                    SBDATo <= RX_reg;
                    SPISR_reg(RRDY) <= '0';  -- no longer anything received
                  when others =>
                    bad_adr <= '1';
                end case;
              end if;
            end if;
          end if;

          when strobe_low =>
            SBACKo <= '0';
            if SBSTBi <= '0' then
              if (SPISR_reg(RRDY) = '0') and (SPISR_reg(TRDY) = '0') then
                state <= transmit;
              elsif intrn_rst = '1' then
                state <= ip_load;
                IPDONE <= '0';
              else
                state <= handle_command;
              end if;
            end if;

          when transmit =>
            if wait_count /= "00000011" then
              wait_count <= wait_count + 1;
            else
              wait_count <= (others => '0');
              if cmd_count = '0' then
                RX_reg <= DUMMY;
                cmd_count <= '1';
              elsif adr_count /= "11" then
                RX_reg <= DUMMY;
                adr_count <= adr_count + 1;
              else
                RX_reg <= data(((byte_count+1)*8-1) downto (byte_count*8));
                byte_count <= byte_count + 1;
              end if;
              SPISR_reg(RRDY) <= '1';
              SPISR_reg(TRDY) <= '1';
              SPISR_reg(TIP) <= '0';
              state <= handle_command;
            end if;
          
          when others =>
            state <= ip_load;

        end case;
      end if;  
    end if;
  end process;
end architecture rtl;
