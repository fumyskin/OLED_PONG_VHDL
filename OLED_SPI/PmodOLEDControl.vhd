
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--use clock division of CLK/32 or CLK/64

--RST SPI must wait 10 us otherwise it wont get accepted


entity PmodOLEDCtrl is
    Port ( 
        CLK     : in  STD_LOGIC;
        RST     : in  STD_LOGIC;
        SPI_CS  : out STD_LOGIC;
        SPI_SDA : out STD_LOGIC;
        SPI_SCLK: out STD_LOGIC;
        SPI_DC  : out STD_LOGIC;
        SPI_RES : out STD_LOGIC
    );
end PmodOLEDCtrl;

architecture Behavioral of PmodOLEDCtrl is

component OledInit is
    Port ( 
        CLK     : in  STD_LOGIC;
        RST     : in  STD_LOGIC;
        SPI_EN  : in  STD_LOGIC;
        SPI_CS  : out STD_LOGIC;
        SPI_SDA : out STD_LOGIC;
        SPI_SCLK: out STD_LOGIC;
        SPI_DC  : out STD_LOGIC;
        SPI_RES : out STD_LOGIC;
        VBAT    : out STD_LOGIC;
        VDD     : out STD_LOGIC;
        SPI_FIN : out STD_LOGIC
    );
end component;

component OledEx is
    Port ( 
        CLK     : in  STD_LOGIC;
        RST     : in  STD_LOGIC;
        SPI_EN  : in  STD_LOGIC;
        SPI_CS  : out STD_LOGIC;
        SPI_SDA : out STD_LOGIC;
        SPI_SCLK: out STD_LOGIC;
        SPI_DC  : out STD_LOGIC;
        SPI_FIN : out STD_LOGIC
    );
end component;

component blk_mem_gen_0
    port (
        clka   : in std_logic;
        ena    : in std_logic;
        addra  : in std_logic_vector(9 downto 0);
        douta  : out std_logic_vector(7 downto 0)
    );
end component;

type states is (Idle, OledInitialize, OledExample, Done);
signal current_state : states := Idle;

signal init_en       : STD_LOGIC := '0';
signal init_done     : STD_LOGIC;
signal init_SPI_CS   : STD_LOGIC;
signal init_sda      : STD_LOGIC;
signal init_SPI_SCLK : STD_LOGIC;
signal init_dc       : STD_LOGIC;

signal example_en    : STD_LOGIC := '0';
signal example_SPI_CS: STD_LOGIC := '1';  -- Initialize to inactive
signal example_sda   : STD_LOGIC := '0';
signal example_SPI_SCLK : STD_LOGIC;
signal example_dc    : STD_LOGIC;
signal example_done  : STD_LOGIC;

signal vbat_signal   : STD_LOGIC := '1';
signal vdd_signal    : STD_LOGIC := '1';
signal rst_internal  : STD_LOGIC := '0';


signal clka     : std_logic;
signal en       : std_logic;
signal addr     : std_logic_vector(9 downto 0);
signal data_out : std_logic_vector(7 downto 0);

begin

    Init: OledInit
        port map (
            CLK      => CLK,
            RST      => rst_internal,
            SPI_EN   => init_en,
            SPI_CS   => init_SPI_CS,
            SPI_SDA  => init_sda,
            SPI_SCLK => init_SPI_SCLK,
            SPI_DC   => init_dc,
            SPI_RES  => SPI_RES,
            SPI_FIN  => init_done,
            VBAT     => vbat_signal,
            VDD      => vdd_signal
        );

    Example: OledEx
        port map (
            CLK      => CLK,
            RST      => rst_internal,
            SPI_EN   => example_en,
            SPI_CS   => example_SPI_CS,
            SPI_SDA  => example_sda,
            SPI_SCLK => example_SPI_SCLK,
            SPI_DC   => example_dc,
            SPI_FIN  => example_done
        );

    memory_instance : blk_mem_gen_0
        port map (
            clka   => clka,
            ena    => en,
            addra  => addr,
            douta  => data_out
        );
    
    -- Safe output MUXes with default values
    SPI_CS   <= init_SPI_CS when (current_state = OledInitialize) else
                example_SPI_CS when (current_state = OledExample) else
                '1';  -- Default inactive
    
    SPI_SDA  <= init_sda when (current_state = OledInitialize) else
                example_sda when (current_state = OledExample) else
                '0';  -- Default low
    
    SPI_SCLK <= init_SPI_SCLK when (current_state = OledInitialize) else
                example_SPI_SCLK when (current_state = OledExample) else
                '0';  -- Default low
    
    SPI_DC   <= init_dc when (current_state = OledInitialize) else
                example_dc when (current_state = OledExample) else
                '0';  -- Default data mode
    
    -- Block enable signals
    init_en <= '1' when (current_state = OledInitialize) else '0';
    example_en <= '1' when (current_state = OledExample) else '0';

    -- Main state machine
    process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                current_state <= Idle;
                rst_internal <= '1';
            else
                rst_internal <= '0';
                case current_state is
                    when Idle =>
                        current_state <= OledInitialize;
                    
                    when OledInitialize =>
                        if init_done = '1' then
                            current_state <= OledExample;
                        end if;
                    
                    when OledExample =>
                        if example_done = '1' then
                            current_state <= Done;
                        end if;
                    
                    when Done =>
                        current_state <= Done;
                    
                    when others =>
                        current_state <= Idle;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
