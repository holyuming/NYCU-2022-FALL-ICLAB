//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2022 Fall
//   Lab06-Exercise		: Unix Timestamp
//   Author     	    : Heng-Yu Liu (nine87129.ee10@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : TESTBED.v
//   Module Name : TESTBED
//   Release version : V1.0 (Release Date: 2022-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`timescale 1ns/1ps 

`ifdef RTL_TOP
	`include "UT_TOP.v"
	`include "PATTERN.v"
`endif

`ifdef GATE_TOP
	`include "UT_TOP_SYN.v"
	`include "PATTERN.v"
`endif

module TESTBED; 

//Connection wires
wire clk, rst_n;
wire in_valid, out_valid;
wire [30:0] in_time;
wire [3:0]  out_display;
wire [2:0]  out_day;

initial begin
	`ifdef RTL_TOP
		$fsdbDumpfile("UT_TOP.fsdb");
		$fsdbDumpvars(0,"+mda");
		$fsdbDumpvars();
	`endif

	`ifdef GATE_TOP
		$sdf_annotate("UT_TOP_SYN.sdf", My_DESIGN);
//		$fsdbDumpfile("UT_TOP_SYN.fsdb");
//		$fsdbDumpvars(0,"+mda");
//		$fsdbDumpvars();
	`endif
end

`ifdef RTL_TOP
	UT_TOP My_DESIGN(
		.clk(clk),
		.rst_n(rst_n),
		.in_valid(in_valid),
		.out_valid(out_valid),
		.in_time(in_time),
		.out_display(out_display),
		.out_day(out_day)
	);

	PATTERN My_PATTERN(
		.clk(clk),
		.rst_n(rst_n),
		.in_valid(in_valid),
		.out_valid(out_valid),
		.in_time(in_time),
		.out_display(out_display),
		.out_day(out_day)
	);

`elsif GATE_TOP
	UT_TOP My_DESIGN(
		.clk(clk),
		.rst_n(rst_n),
		.in_valid(in_valid),
		.out_valid(out_valid),
		.in_time(in_time),
		.out_display(out_display),
		.out_day(out_day)
	);
	
	PATTERN My_PATTERN(
		.clk(clk),
		.rst_n(rst_n),
		.in_valid(in_valid),
		.out_valid(out_valid),
		.in_time(in_time),
		.out_display(out_display),
		.out_day(out_day)
	);
`endif


endmodule
