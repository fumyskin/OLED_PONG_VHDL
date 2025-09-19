
----------------------------------------------------------------------------------
-- Module Name:    SpiCtrl - Behavioral 
-- Project Name:   PmodOled Demo
-- Description:    SPI block that sends SPI data formatted SCLK active low with
--                 SDO changing on the falling edge
-- Revision: 1.0 - SPI completed
-- Revision 0.01 - File Created 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SpiControl is
    Port ( CLK       : in  STD_LOGIC; -- System CLK (100MHz)
           RST       : in  STD_LOGIC; -- Global RST (Synchronous)
           SPI_EN    : in  STD_LOGIC; -- SPI enable flag
           SPI_DATA  : in  STD_LOGIC_VECTOR(7 downto 0); -- Byte to be sent
           SPI_CS    : out STD_LOGIC; -- Chip Select
           SPI_SDA   : out STD_LOGIC; -- 1-bit serial, outputs 1 bit at a time (MSB first)
           SPI_SCLK  : out STD_LOGIC; -- SPI clock
           SPI_FIN   : out STD_LOGIC  -- SPI finish flag
    );
end SpiControl;

architecture Behavioral of SpiControl is

    type states is (Idle,
                    Send,
                    Hold1,
                    Hold2,
                    Hold3,
                    Hold4,
                    Done);

    signal current_state  : states := Idle;

    signal shift_register : STD_LOGIC_VECTOR(7 downto 0); -- Shift register
    signal shift_counter  : STD_LOGIC_VECTOR(3 downto 0); -- Bit counter
    signal clk_divided    : STD_LOGIC := '1'; -- Used as SPI_SCLK
    signal counter        : STD_LOGIC_VECTOR(4 downto 0) := (others => '0'); -- Clock divider counter
    signal temp_sdo       : STD_LOGIC := '1';
    signal falling        : STD_LOGIC := '0'; -- Detect falling edge of clk_divided

begin

    -- Generate divided clock (idle high, toggles every 16 system clock cycles)
    clk_divided <= counter(4);
    SPI_SCLK    <= not clk_divided;

    -- Chip select active LOW
    SPI_CS  <= '1' when (current_state = Idle and SPI_EN = '0') else '0';
    SPI_SDA <= temp_sdo;
    SPI_FIN <= '1' when (current_state = Done) else '0';

    ------------------------------------------------------------------------
    -- FSM
    ------------------------------------------------------------------------
    STATE_MACHINE : process (CLK)  
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                current_state <= Idle;
            else
                case current_state is
                    when Idle =>
                        if SPI_EN = '1' then
                            current_state <= Send;
                        end if;

                    when Send =>
                        if (shift_counter = "1000" and falling = '0') then
                            current_state <= Hold1;
                        end if;

                    when Hold1 =>
                        current_state <= Hold2;

                    when Hold2 =>
                        current_state <= Hold3;

                    when Hold3 =>
                        current_state <= Hold4;

                    when Hold4 =>
                        current_state <= Done;

                    when Done =>
                        if SPI_EN = '0' then
                            current_state <= Idle;
                        end if;

                    when others =>
                        current_state <= Idle;
                end case;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Clock divider
    ------------------------------------------------------------------------
    CLK_DIV : process (CLK)
    begin
        if rising_edge(CLK) then
            if (current_state = Send) then
                counter <= std_logic_vector(unsigned(counter) + 1);
            else
                counter <= (others => '0');
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- SPI send logic
    ------------------------------------------------------------------------
    SPI_SEND_BYTE : process (CLK)
    begin
        if rising_edge(CLK) then
            if current_state = Idle then
                shift_counter  <= (others => '0');
                shift_register <= SPI_DATA; -- load new byte
                temp_sdo       <= '1';
                falling        <= '0';

            elsif current_state = Send then
                if (clk_divided = '0' and falling = '0') then
                    falling        <= '1';
                    temp_sdo       <= shift_register(7); -- send MSB
                    shift_register <= shift_register(6 downto 0) & '0';
                    shift_counter  <= std_logic_vector(unsigned(shift_counter) + 1);
                elsif clk_divided = '1' then
                    falling <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
