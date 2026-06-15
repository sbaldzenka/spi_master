-- project     : spi_master_vhdl
-- date        : 11.06.2026
-- version     : 1.0
-- author      : siarhei baldzenka
-- e-mail      : sbaldzenka@proton.me
-- description : https://github.com/sbaldzenka/spi_master

add wave -noupdate -divider testbench
add wave -noupdate -format Logic -radix UNSIGNED -group {testbench} /spi_master_tb/*

add wave -noupdate -divider spi_master
add wave -noupdate -format Logic -radix UNSIGNED -group {spi_master} /spi_master_tb/DUT_inst/*

-- Toggle leaf names command:
config wave -signalnamewidth 1