`timescale 1ns/1ps
`ifdef RTL
`include "SP_wocg.v"

`elsif GATE
`include "SP_SYN.v"

`endif

`include "PATTERN.v"

module TESTBED();
	wire clk, rst_n, in_valid, cg_en;
	wire [8:0] in_data;
	wire [2:0] in_mode;
	wire out_valid;
	wire signed	[9:0] out_data;	

	
initial begin
	`ifdef RTL
		$fsdbDumpfile("SP.fsdb");
		$fsdbDumpvars();
		$fsdbDumpvars(0,"+mda");
	`elsif GATE
		$sdf_annotate("SP_SYN.sdf",I_SP);
		// $fsdbDumpfile("SP_SYN.fsdb");   
		//$fsdbDumpvars(0,"+mda");
		// $fsdbDumpvars();
	`endif
end

SP I_SP
(
	// Input signals
	.clk(clk),
	.rst_n(rst_n),
	.in_valid(in_valid),
	.cg_en(cg_en), 
	.in_data(in_data),
	.in_mode(in_mode),
	// Output signals
	.out_valid(out_valid),
	.out_data(out_data)
);


PATTERN I_PATTERN
(
	// Output signals
	.clk(clk),
	.rst_n(rst_n),
	.in_valid(in_valid),
	.cg_en(cg_en),
	.in_data(in_data),
	.in_mode(in_mode),
	// Input signals
	.out_valid(out_valid),
	.out_data(out_data)
);

endmodule
