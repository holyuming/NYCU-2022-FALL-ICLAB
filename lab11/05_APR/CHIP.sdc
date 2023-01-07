###################################################################

# Created by write_sdc on Sun Dec 18 01:06:55 2022

###################################################################
set sdc_version 2.1

set_units -time ns -resistance kOhm -capacitance pF -power mW -voltage V -current mA
set_load -pin_load 0.05 [get_ports out_valid]
set_load -pin_load 0.05 [get_ports out_value]
create_clock [get_ports clk]  -period 18  -waveform {0 9}
set_input_delay -clock clk  0  [get_ports clk]
set_input_delay -clock clk  0  [get_ports rst_n]
set_input_delay -clock clk  9  [get_ports in_valid]
set_input_delay -clock clk  9  [get_ports in_valid2]
set_input_delay -clock clk  9  [get_ports matrix]
set_input_delay -clock clk  9  [get_ports {matrix_size[1]}]
set_input_delay -clock clk  9  [get_ports {matrix_size[0]}]
set_input_delay -clock clk  9  [get_ports i_mat_idx]
set_input_delay -clock clk  9  [get_ports w_mat_idx]
set_output_delay -clock clk  9  [get_ports out_valid]
set_output_delay -clock clk  9  [get_ports out_value]
