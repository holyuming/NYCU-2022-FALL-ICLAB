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
//   File Name   : TESETBED.v
//   Module Name : TESETBED
//   Release version : V1.0 (Release Date: 2022-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`timescale 1ns/1ps 

`ifdef RTL
    `include "PATTERN_IP.v"
    `include "B2BCD_IP_demo.v"
`endif

`ifdef GATE
    `include "PATTERN_IP.v"
    `include "B2BCD_IP_demo_SYN.v"
`endif

module TESTBED; 

parameter B_WIDTH   = 4;
parameter BCD_DIGIT = 2;

// Connection wires
wire [B_WIDTH-1:0]     Binary_code;
wire [BCD_DIGIT*4-1:0] BCD_code;


initial begin
    `ifdef RTL
//        $fsdbDumpfile("B2BCD_IP_demo.fsdb");
//      $fsdbDumpvars(0,"+mda");
//        $fsdbDumpvars();
    `endif
    `ifdef GATE
        $sdf_annotate("B2BCD_IP_demo_SYN.sdf",My_IP);
//        $fsdbDumpfile("B2BCD_IP_demo_SYN.fsdb");
//        $fsdbDumpvars(0,"+mda");
//        $fsdbDumpvars();
    `endif
end

`ifdef RTL
    B2BCD_IP_demo #(.WIDTH(B_WIDTH), .DIGIT(BCD_DIGIT)) My_IP (
            .Binary_code(Binary_code), 
            .BCD_code   (BCD_code)
    );
    
    PATTERN_IP #(.WIDTH(B_WIDTH), .DIGIT(BCD_DIGIT)) My_PATTERN (
            .Binary_code(Binary_code), 
            .BCD_code   (BCD_code)
    );

`elsif GATE
    B2BCD_IP_demo My_IP (
            .Binary_code(Binary_code), 
            .BCD_code   (BCD_code)
    );
    
    PATTERN_IP #(.WIDTH(B_WIDTH), .DIGIT(BCD_DIGIT)) My_PATTERN (
            .Binary_code(Binary_code), 
            .BCD_code   (BCD_code)
    );

`endif  


endmodule
