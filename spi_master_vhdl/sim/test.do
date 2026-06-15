-- project     : spi_master_vhdl
-- date        : 11.06.2026
-- version     : 1.0
-- author      : siarhei baldzenka
-- e-mail      : sbaldzenka@proton.me
-- description : https://github.com/sbaldzenka/spi_master

vlib work
vmap work work

vcom -93 ../tb/spi_master_tb.vhd

vcom -93 ../src/spi_master.vhd

vsim -t 1ps -voptargs=+acc=lprn -lib work spi_master_tb

do waves_test.do
view wave
run 1 ms