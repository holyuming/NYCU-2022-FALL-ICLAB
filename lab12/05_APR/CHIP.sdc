set sdc_version 2.1

set_units -time ns -resistance kOhm -capacitance pF -voltage V -current mA
set_wire_load_mode top
set_load -pin_load 0.05 [get_ports out_valid]
set_load -pin_load 0.05 [get_ports {cost[3]}]
set_load -pin_load 0.05 [get_ports {cost[2]}]
set_load -pin_load 0.05 [get_ports {cost[1]}]
set_load -pin_load 0.05 [get_ports {cost[0]}]
create_clock [get_ports clk]  -period 10  -waveform {0 5}
set_input_delay -clock clk  0  [get_ports clk]
set_input_delay -clock clk  5  [get_ports rst_n]
set_input_delay -clock clk  5  [get_ports in_valid]
set_input_delay -clock clk  5  [get_ports {source[3]}]
set_input_delay -clock clk  5  [get_ports {source[2]}]
set_input_delay -clock clk  5  [get_ports {source[1]}]
set_input_delay -clock clk  5  [get_ports {source[0]}]
set_input_delay -clock clk  5  [get_ports {destination[3]}]
set_input_delay -clock clk  5  [get_ports {destination[2]}]
set_input_delay -clock clk  5  [get_ports {destination[1]}]
set_input_delay -clock clk  5  [get_ports {destination[0]}]
set_output_delay -clock clk  5  [get_ports out_valid]
set_output_delay -clock clk  5  [get_ports {cost[3]}]
set_output_delay -clock clk  5  [get_ports {cost[2]}]
set_output_delay -clock clk  5  [get_ports {cost[1]}]
set_output_delay -clock clk  5  [get_ports {cost[0]}]
