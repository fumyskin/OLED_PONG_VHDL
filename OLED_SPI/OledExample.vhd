library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.blk_mem_gen_0;


entity OledEx is
    Port ( 
        CLK     : in  STD_LOGIC;
        RST     : in  STD_LOGIC;
        SPI_EN  : in  STD_LOGIC;
        SPI_CS  : out STD_LOGIC;
        SPI_SDA : out STD_LOGIC;
        SPI_SCLK: out STD_LOGIC;
        SPI_DC  : out STD_LOGIC;
        SPI_Fin : out STD_LOGIC
    );
end OledEx;

architecture Behavioral of OledEx is

    -----------------------------------------------------------------------------
    -- COMPONENTS
    -----------------------------------------------------------------------------
    COMPONENT SpiCtrl
        PORT(
            CLK      : in  STD_LOGIC;
            RST      : in  STD_LOGIC;
            SPI_EN   : in  STD_LOGIC;
            SPI_DATA : in  UNSIGNED(7 downto 0);
            SPI_CS   : out STD_LOGIC;
            SPI_SDA  : out STD_LOGIC;
            SPI_SCLK : out STD_LOGIC;
            SPI_Fin  : out STD_LOGIC
        );
    END COMPONENT;

    COMPONENT Delay
        PORT(
            CLK       : in  STD_LOGIC;
            RST       : in  STD_LOGIC;
            DELAY_MS  : in  UNSIGNED(11 downto 0);
            DELAY_EN  : in  STD_LOGIC;
            DELAY_FIN : out STD_LOGIC
        );
    END COMPONENT;

    -----------------------------------------------------------------------------
    -- TYPE DECLARATIONS
    -----------------------------------------------------------------------------
    type step_type is record
        dc    : std_logic;                   -- 0=command, 1=data
        value : std_logic_vector(7 downto 0);-- byte to send
    end record;

    type seq_type is array (natural range <>) of step_type;

    -----------------------------------------------------------------------------
    -- DRAW SINGLE PIXEL SEQUENCE
    -----------------------------------------------------------------------------
    constant pixel_sequence : seq_type := (
        -- Set Column Address (x=0x10)
        (dc=>'0', value=>x"2A"), -- CASET
        (dc=>'1', value=>x"00"), 
        (dc=>'1', value=>x"10"), 
        (dc=>'1', value=>x"00"), 
        (dc=>'1', value=>x"10"),

        -- Set Row Address (y=0x20)
        (dc=>'0', value=>x"2B"), -- RASET
        (dc=>'1', value=>x"00"), 
        (dc=>'1', value=>x"20"), 
        (dc=>'1', value=>x"00"), 
        (dc=>'1', value=>x"20"),

        -- Write Pixel Data
        (dc=>'0', value=>x"2C"), -- RAMWR
        (dc=>'1', value=>x"F8"), -- RED high byte
        (dc=>'1', value=>x"00")  -- RED low byte
    );

    
    -- Image ROM component (stores your image in RGB565 format)
    --Character Library, Latency = 1
    COMPONENT charLib
      PORT (
        clka : in STD_LOGIC; --Attach System Clock to it
        addra : in UNSIGNED(16 DOWNTO 0); --First 8 bits is the ASCII value of the character the last 3 bits are the parts of the char
        douta : out UNSIGNED(7 DOWNTO 0) --Data byte out
      );
    END COMPONENT;

    -----------------------------------------------------------------------------
    -- SIGNALS
    -----------------------------------------------------------------------------
    type states is (Idle, SendByte, WaitSPI, Done);

    signal current_state : states := Idle;
    signal seq_index     : integer range 0 to pixel_sequence'length := 0;

    -- SPI signals
    signal temp_spi_en   : std_logic := '0';
    signal temp_spi_data : unsigned(7 downto 0) := (others => '0');
    signal temp_spi_fin  : std_logic := '0';

    -- Control signals
    signal temp_dc  : std_logic := '0';

begin
    -----------------------------------------------------------------------------
    -- OUTPUT ASSIGNMENTS
    -----------------------------------------------------------------------------
    SPI_DC  <= temp_dc;
    SPI_Fin <= '1' when current_state = Done else '0';

    -----------------------------------------------------------------------------
    -- SPI CONTROLLER INSTANTIATION
    -----------------------------------------------------------------------------
    SPI_COMP: SpiCtrl 
    PORT MAP (
        CLK      => CLK,
        RST      => RST,
        SPI_EN   => temp_spi_en,
        SPI_DATA => temp_spi_data,
        SPI_CS   => SPI_CS,
        SPI_SDA  => SPI_SDA,
        SPI_SCLK => SPI_SCLK,
        SPI_Fin  => temp_spi_fin
    );

    -----------------------------------------------------------------------------
    -- FSM
    -----------------------------------------------------------------------------
    process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                current_state <= Idle;
                seq_index     <= 0;
                temp_spi_en   <= '0';
                temp_dc       <= '0';
            else
                case current_state is

                    -----------------------------------------------------------------
                    when Idle =>
                        if SPI_EN = '1' then
                            seq_index     <= 0;
                            current_state <= SendByte;
                        end if;

                    -----------------------------------------------------------------
                    when SendByte =>
                        -- Load DC and data
                        temp_dc       <= pixel_sequence(seq_index).dc;
                        temp_spi_data <= unsigned(pixel_sequence(seq_index).value);
                        temp_spi_en   <= '1';
                        current_state <= WaitSPI;

                    -----------------------------------------------------------------
                    when WaitSPI =>
                        if temp_spi_fin = '1' then
                            temp_spi_en <= '0';
                            if seq_index = pixel_sequence'length - 1 then
                                current_state <= Done;
                            else
                                seq_index     <= seq_index + 1;
                                current_state <= SendByte;
                            end if;
                        end if;

                    -----------------------------------------------------------------
                    when Done =>
                        if SPI_EN = '0' then
                            current_state <= Idle;
                        end if;

                    -----------------------------------------------------------------
                    when others =>
                        current_state <= Idle;

                end case;
            end if;
        end if;
    end process;

end Behavioral;


