
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity OledInit is
    port(
            CLK:        in STD_LOGIC;
            RST:        in STD_LOGIC;  -- in because they are read only
            SPI_EN:     in STD_LOGIC;  -- block enable pin
            SPI_CS:     out STD_LOGIC; -- spi chip select
            SPI_SDA:    out STD_LOGIC; -- spi data out
            SPI_SCLK:   out STD_LOGIC; -- spi clock
            SPI_RES:    out STD_LOGIC; -- PMODOLED reset flag (?)
            SPI_DC:     out STD_LOGIC; -- data/command pin
            FIN:    out STD_LOGIC  -- OLEDINIT finish flag
    );
end OledInit;

architecture Behavioral of OledInit is

    type spi_step is record
        dc      : STD_LOGIC;      -- 1 = command; 0 = data
        value   : STD_LOGIC_VECTOR(7 downto 0);  --byte to send
        delay   : NATURAL; -- delay in ms after this byte
    end record;

    --Initialization sequence found in ADAFRUIT DOCUMENTATION
    type st7789_init_seq is array(natural range <>) of spi_step;
    constant init_sequence: st7789_init_seq := (
        -- SWRESET (0x01)
        (dc=>'0', value=>x"01", delay=>150),

        -- SLPOUT (0x11)
        (dc=>'0', value=>x"11", delay=>10),

        -- COLMOD (0x3A), arg=0x55
        (dc=>'0', value=>x"3A", delay=>0),
        (dc=>'1', value=>x"55", delay=>10),

        -- MADCTL (0x36), arg=0x08
        (dc=>'0', value=>x"36", delay=>0),
        (dc=>'1', value=>x"08", delay=>0),

        -- CASET (0x2A), args: 0x00,0x00,0x00,0xF0
        (dc=>'0', value=>x"2A", delay=>0),
        (dc=>'1', value=>x"00", delay=>0),
        (dc=>'1', value=>x"00", delay=>0),
        (dc=>'1', value=>x"00", delay=>0),
        (dc=>'1', value=>x"F0", delay=>0),

        -- RASET (0x2B), args: 0x00,0x00,0x01,0x40
        (dc=>'0', value=>x"2B", delay=>0),
        (dc=>'1', value=>x"00", delay=>0),
        (dc=>'1', value=>x"00", delay=>0),
        (dc=>'1', value=>x"01", delay=>0),
        (dc=>'1', value=>x"40", delay=>0),

        -- INVON (0x21)
        (dc=>'0', value=>x"21", delay=>10),

        -- NORON (0x13)
        (dc=>'0', value=>x"13", delay=>10),

        -- DISPON (0x29)
        (dc=>'0', value=>x"29", delay=>10)  

    );

    --constant pixel_sequence : TO BE DONE
    -- Components declaration for wiring
    -- correctly name component (coherent with SpiControl.vhd)
    component SpiControl
        port(   
            CLK 		:in STD_LOGIC; --System CLK (100MHz)
		    RST 		:in STD_LOGIC; --Global RST (Synchronous)
		    SPI_EN      :in STD_LOGIC; -- SPI enable flag
		    SPI_DATA    :in STD_LOGIC_VECTOR(7 downto 0); --Byte to be sent
		    SPI_CS	    :out STD_LOGIC; --Chip Select
		    SPI_SDA     :out STD_LOGIC; --1 bit serial, outputs 1 bit at a time (MSB)
            SPI_SCLK    :out STD_LOGIC; --SPI clock
            SPI_FIN     :out STD_LOGIC
        );
        end component;

    --delay component (to be port-mapped)
    component Delay
        port(
            CLK:        in STD_LOGIC;
            RST:        in STD_LOGIC;
            DELAY_MS:   in STD_LOGIC_VECTOR(11 downto 0);
            DELAY_EN:   in STD_LOGIC;
            DELAY_FIN:  out STD_LOGIC
        );
    end component;
    
    -- modification: ADDED LESS STATES, TO SIMPLIFY FSM
    type state is(
        IDLE,
        INIT,
        WAIT_SPI,
        START_SPI,
        WAIT_DELAY1,
        WAIT_DELAY2,
        WAIT_DELAY3,
        WAIT_DELAY4,
        START_DELAY,
        DONE
    );


    --signals
    signal init_index : integer range 0 to init_sequence'high + 1 := 0;

    signal current_state: state := IDLE;
   
    signal temp_spi_en: STD_LOGIC := '0'; -- currently spi not enabled
    signal temp_spi_data: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal temp_res: STD_LOGIC := '1'; -- 0: 
    signal temp_dc: STD_LOGIC := '0';
    signal temp_cs: STD_LOGIC := '0'; -- cs bring active LOW
    signal temp_fin: STD_LOGIC := '0'; -- 0: OLEDINIT has not finished
    signal temp_spi_fin: STD_LOGIC;

    signal temp_delay_ms : STD_LOGIC_VECTOR (11 downto 0) := (others => '0');
    signal temp_delay_en : STD_LOGIC := '0';
    signal temp_delay_fin : STD_LOGIC;


    begin

        SPI_COMP: SpiControl port map(
            CLK => CLK,
            RST => RST,
            SPI_EN => temp_spi_en,
            SPI_DATA => temp_spi_data,
            SPI_CS => SPI_CS,
            SPI_SDA => SPI_SDA,
            SPI_SCLK => SPI_SCLK,
            SPI_FIN => temp_spi_fin
        );

        DELAY_COMP: Delay port map(
            CLK => CLK,
            RST => RST,
            DELAY_MS => temp_delay_ms,
            DELAY_EN => temp_delay_en,
            DELAY_FIN => temp_delay_fin 
        );

        SPI_DC <= temp_dc;
        SPI_RES <= temp_res;
        FIN <= temp_fin;


        STATE_MACHINE : process (CLK)
	    begin
            if(rising_edge(CLK)) then
                if(RST = '1') then
                    current_state <= IDLE;
                    temp_res <= '0'; --Assert reset (active low)
                    init_index <= 0;
                    temp_spi_en <= '0';
                    temp_delay_en <= '0';
                    temp_fin <= '0';
                else
                    temp_res <= '1'; -- Release reset

                    case (current_state) is
                        when IDLE =>
                            if(SPI_EN = '1') then
                                init_index <= 0;
                                current_state <= INIT;
                            end if;
                        when INIT =>
                            if init_index <= init_sequence'high then
                                -- Load current step
                                temp_dc      <= init_sequence(init_index).dc;
                                temp_spi_data <= init_sequence(init_index).value;

                                if init_sequence(init_index).delay > 0 then
                                    temp_delay_ms <= std_logic_vector(to_unsigned(init_sequence(init_index).delay, 12));
                                    current_state <= START_DELAY; --do delay first
                                else
                                    current_state <= START_SPI;  -- Send SPI immediately
                                end if;
                            else
                                current_state <= DONE;
                            end if;

                        when START_SPI =>
                            temp_spi_en <= '1';
                            current_state <= WAIT_SPI;

                        when WAIT_SPI =>
                            if temp_spi_fin = '1' then
                                temp_spi_en <= '0';
                                init_index <= init_index + 1;
                                current_state <= INIT;
                            end if;
                        
                        when START_DELAY =>
                            temp_delay_en <= '1';
                            current_state <= WAIT_DELAY1;
                        
                        when WAIT_DELAY1 =>
                            current_state <= WAIT_DELAY2;
                        
                        when WAIT_DELAY2 =>
                            current_state <= WAIT_DELAY3;
                        
                        when WAIT_DELAY3 =>
                            current_state <= WAIT_DELAY4;

                        when WAIT_DELAY4 =>
                            if temp_delay_fin = '1' then
                                temp_delay_en <= '0';
                                temp_delay_ms <= (others => '0'); --reset delay got at typle indexth
                                init_index <= init_index + 1;
                                current_state <= INIT;
                            end if;
                        
                        when DONE =>
                            temp_fin <= '1';
                            if SPI_EN = '0' then
                                current_state <= IDLE;
                            end if;
                        
                        when others =>
						    current_state <= IDLE;
                    end case;
                end if;
            end if;
        end process;

end Behavioral;

