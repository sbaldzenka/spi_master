-- project     : spi_master_vhdl
-- date        : 06.06.2026
-- version     : 1.0
-- author      : siarhei baldzenka
-- e-mail      : sbaldzenka@proton.me
-- description : https://github.com/sbaldzenka/spi_master

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity spi_master is
generic
(
    CPOL             : integer := 0;
    CPHA             : integer := 0;
    CLOCK_DIVIDER    : integer := 4;
    NUMBER_OF_SLAVES : integer := 1
);
port
(
    -- global signal
    i_clk              : in  std_logic;
    i_reset            : in  std_logic;
    -- control
    i_slave_device_sel : in  std_logic_vector(NUMBER_OF_SLAVES-1 downto 0);
    -- data in bus
    i_valid            : in  std_logic;
    i_data             : in  std_logic_vector(                 7 downto 0);
    o_ready            : out std_logic;
    -- data bus out
    o_valid            : out std_logic;
    o_data             : out std_logic_vector(                 7 downto 0);
    -- spi master interface
    o_cs_n             : out std_logic_vector(NUMBER_OF_SLAVES-1 downto 0);
    o_sclk             : out std_logic;
    o_mosi             : out std_logic;
    i_miso             : in  std_logic
);
end spi_master;

architecture rtl of spi_master is

    -- types
    type states is
    (
        S_IDLE,
        S_START,
        S_BYTE_TRANSACTION,
        S_WAIT,
        S_END
    );

    -- constants
    constant NO_SELECT        : std_logic_vector(NUMBER_OF_SLAVES-1 downto 0) := (others => '0');
    constant MIN_PERIOD_VALUE : std_logic_vector(   CLOCK_DIVIDER-1 downto 0) := (others => '0');
    constant MAX_PERIOD_VALUE : std_logic_vector(   CLOCK_DIVIDER-1 downto 0) := (others => '1');

    -- signals
    signal ready_flag         : std_logic;
    signal period_counter     : std_logic_vector(CLOCK_DIVIDER-1 downto 0);
    signal bit_leading_pulse  : std_logic;
    signal bit_trailing_pulse : std_logic;
    signal bit_period_pulse   : std_logic;
    signal bit_counter        : std_logic_vector(              2 downto 0);
    signal srl_reg_out        : std_logic_vector(              7 downto 0);
    signal srl_reg_in         : std_logic_vector(              7 downto 0);
    signal state              : states;

begin

    o_ready <= ready_flag;
    o_cs_n  <= not i_slave_device_sel;

    READY_SIGNAL_CTRL: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (state = S_START or state = S_WAIT) then
                if (period_counter = MIN_PERIOD_VALUE) then
                    ready_flag <= '1';
                end if;

                if (i_valid = '1') then
                    ready_flag <= '0';
                end if;
            else
                ready_flag <= '0';
            end if;
        end if;
    end process;

    OUTPUT_BUS_CTRL: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (bit_counter = x"7" and bit_period_pulse = '1') then
                o_valid <= '1';
                o_data  <= srl_reg_in;
            else
                o_valid <= '0';
            end if;
        end if;
    end process;

    SRL_REG_OUT_CTRL: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (state = S_IDLE) then
                srl_reg_out <= (others => '0');
            else
                if (i_valid = '1' and ready_flag = '1') then
                    srl_reg_out <= i_data;
                end if;
            end if;

            if (CPHA = 1) then
                if (state = S_BYTE_TRANSACTION and bit_trailing_pulse = '1') then
                    srl_reg_out <= srl_reg_out(6 downto 0) & '0';
                end if;
            else
                if (state = S_BYTE_TRANSACTION and bit_leading_pulse = '1') then
                    srl_reg_out <= srl_reg_out(6 downto 0) & '0';
                end if;
            end if;
        end if;
    end process;

    SRL_REG_IN_CTRL: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (state = S_IDLE) then
                srl_reg_in <= (others => '0');
            end if;

            if (CPHA = 1) then
                if (state = S_BYTE_TRANSACTION and bit_trailing_pulse = '1') then
                    srl_reg_in <= srl_reg_in(6 downto 0) & i_miso;
                end if;
            else
                if (state = S_BYTE_TRANSACTION and bit_leading_pulse = '1') then
                    srl_reg_in <= srl_reg_in(6 downto 0) & i_miso;
                end if;
            end if;
        end if;
    end process;

    PERIOD_COUNTER_PROC: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (state = S_IDLE) then
                period_counter <= (others => '0');
            else
                period_counter <= period_counter + '1';
            end if;
        end if;
    end process;

    LEADING_PULSE_GEN: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (period_counter = MAX_PERIOD_VALUE) then
                bit_leading_pulse <= '1';
            else
                bit_leading_pulse <= '0';
            end if;
        end if;
    end process;

    TRAILING_PULSE_GEN: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (period_counter = ('0' & MAX_PERIOD_VALUE(CLOCK_DIVIDER-1 downto 1))) then
                bit_trailing_pulse <= '1';
            else
                bit_trailing_pulse <= '0';
            end if;
        end if;
    end process;

    PERIOD_PULSE_GEN: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (period_counter = MAX_PERIOD_VALUE - '1') then
                bit_period_pulse <= '1';
            else
                bit_period_pulse <= '0';
            end if;
        end if;
    end process;

    BIT_COUNTER_PROC: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (state = S_BYTE_TRANSACTION) then
                if (bit_period_pulse = '1') then
                    bit_counter <= bit_counter + '1';
                end if;
            else
                bit_counter <= (others => '0');
            end if;
        end if;
    end process;

    SCLK_CTRL: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (state = S_IDLE or state = S_WAIT) then
                if (CPOL = 1) then
                    o_sclk <= '1';
                else
                    o_sclk <= '0';
                end if;
            elsif (state = S_BYTE_TRANSACTION) then
                o_sclk <= not period_counter(CLOCK_DIVIDER-1);
            end if;
        end if;
    end process;

    MOSI_CTRL: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (CPHA = 1) then
                if (state = S_START or state = S_WAIT) then
                    o_mosi <= '0';
                elsif (state = S_BYTE_TRANSACTION) then
                    if (bit_leading_pulse = '1') then
                        o_mosi <= srl_reg_out(7);
                    end if;
                end if;
            else
                if (state = S_START or state = S_WAIT) then
                    o_mosi <= srl_reg_out(7);
                elsif (state = S_BYTE_TRANSACTION) then
                    if (bit_trailing_pulse = '1') then
                        o_mosi <= srl_reg_out(7);
                    end if;
                else
                    o_mosi <= '0';
                end if;
            end if;
        end if;
    end process;

    FSM: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_reset = '1') then
                state <= S_IDLE;
            else
                case (state) is
                    when S_IDLE =>
                        if (i_slave_device_sel /= NO_SELECT) then
                            state <= S_START;
                        end if;

                    when S_START =>
                        if (period_counter = MAX_PERIOD_VALUE) then
                            state <= S_BYTE_TRANSACTION;
                        end if;

                    when S_BYTE_TRANSACTION =>
                        if (bit_period_pulse = '1' and bit_counter = x"7") then
                            state <= S_WAIT;
                        end if;

                    when S_WAIT =>
                        if (period_counter = MAX_PERIOD_VALUE) then
                            state <= S_BYTE_TRANSACTION;
                        end if;

                        if (i_slave_device_sel = NO_SELECT) then
                            state <= S_END;
                        end if;

                    when S_END =>
                        if (period_counter = MAX_PERIOD_VALUE) then
                            state <= S_IDLE;
                        end if;

                    when others =>
                        state <= S_IDLE;
                end case;
            end if;
        end if;
    end process;

end rtl;