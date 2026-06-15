-- project     : spi_master_vhdl
-- date        : 11.06.2026
-- version     : 1.0
-- author      : siarhei baldzenka
-- e-mail      : sbaldzenka@proton.me
-- description : https://github.com/sbaldzenka/spi_master

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity spi_master_tb is
generic
(   -- simulation parameters
    CLK_PERIOD       : time    := 10.000 ns;
    -- DUT parameters
    CPOL             : integer := 0;
    CPHA             : integer := 0;
    CLOCK_DIVIDER    : integer := 4;
    NUMBER_OF_SLAVES : integer := 1
);
end spi_master_tb;

architecture rtl of spi_master_tb is

    component spi_master is
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
    end component;

    -- signals
    signal clk                 : std_logic;
    signal reset               : std_logic;
    signal transaction_counter : std_logic_vector(                 7 downto 0);
    signal finish_flag         : std_logic;
    signal slave_device_sel    : std_logic_vector(NUMBER_OF_SLAVES-1 downto 0);
    signal valid_in            : std_logic;
    signal data_in             : std_logic_vector(                 7 downto 0);
    signal ready_in            : std_logic;
    signal valid_out           : std_logic;
    signal valid_out_ff        : std_logic;
    signal data_out            : std_logic_vector(                 7 downto 0);
    signal mosi                : std_logic;
    signal miso                : std_logic;
    signal data_tx             : std_logic_vector(                 7 downto 0);
    signal data_rx             : std_logic_vector(                 7 downto 0);
    signal data_tx_int         : integer;
    signal data_rx_int         : integer;

begin

    CLK_GENERATE: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    RESET_GENERATE: process
    begin
        reset <= '1';
        wait for 10 us;
        reset <= '0';
        wait;
    end process;

    TEST: process
    begin
        report "------------------------------------------------- START SIMULATION.";
        slave_device_sel    <= (others => '0');
        wait until falling_edge(reset);
        slave_device_sel(0) <= '1';
        wait until rising_edge(finish_flag);
        slave_device_sel(0) <= '0';
        report "------------------------------------------------- FINISH SIMULATION.";
        wait;
    end process;

    TRAFFIC_GEN: process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                valid_in <= '0';
                data_in  <= (others => '0');
            else
                if (ready_in = '1') then
                    valid_in <= '1';
                    data_in  <= data_in + '1';
                else
                    valid_in <= '0';
                end if;
            end if;
        end if;
    end process;

    TRANSACTION_CNT: process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                finish_flag         <= '0';
                transaction_counter <= (others => '0');
            else
                if (finish_flag = '0') then
                    if (valid_in = '1' and ready_in = '1') then
                        transaction_counter <= transaction_counter + '1';
                    end if;

                    if (transaction_counter = x"63") then
                        finish_flag <= '1';
                    end if;
                else
                    transaction_counter <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    miso <= mosi;

    DATA_VECTOR_TO_INT: process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                data_tx <= (others => '0');
            elsif (valid_in = '1' and ready_in = '1') then
                data_tx <= data_in;
            end if;

            if (reset = '1') then
                data_rx <= (others => '0');
            elsif (valid_out = '1') then
                data_rx <= data_out;
            end if;
        end if;
    end process;

    data_tx_int <= conv_integer(data_tx);
    data_rx_int <= conv_integer(data_rx);

    FF: process(clk)
    begin
        if rising_edge(clk) then
            valid_out_ff <= valid_out;
        end if;
    end process;

    DATA_COMP: process(valid_out_ff)
    begin
        if falling_edge (valid_out_ff) then
            report ">>>> DATA TX:" & integer'image(data_tx_int);
            report ">>>> DATA RX:" & integer'image(data_rx_int);

            if (data_tx_int = data_rx_int) then
                report "------------------------------------------------- DATA PASSED.";
            else
                report "------------------------------------------------- DATA ERROR!";
            end if;
        end if;
    end process;

    DUT_inst: spi_master
    generic map
    (
        CPOL             => CPOL,
        CPHA             => CPHA,
        CLOCK_DIVIDER    => CLOCK_DIVIDER,
        NUMBER_OF_SLAVES => NUMBER_OF_SLAVES
    )
    port map
    (
        i_clk              => clk,
        i_reset            => reset,
        i_slave_device_sel => slave_device_sel,
        i_valid            => valid_in,
        i_data             => data_in,
        o_ready            => ready_in,
        o_valid            => valid_out,
        o_data             => data_out,
        o_cs_n             => open,
        o_sclk             => open,
        o_mosi             => mosi,
        i_miso             => miso
    );

end rtl;
