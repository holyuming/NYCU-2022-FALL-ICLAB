`timescale 1ns/10ps
`include "PATTERN.v"
`ifdef RTL
  `include "HD.v"
`endif
`ifdef GATE
  `include "HD_SYN.v"
`endif
	  		  	
module TESTBED; 

//Connection wires
wire [6:0] code_word1, code_word2;
wire [5:0] out_n;

initial begin
  `ifdef RTL
    $fsdbDumpfile("HD.fsdb");
	  $fsdbDumpvars(0,"+mda");
    $fsdbDumpvars();
  `endif
  `ifdef GATE
    $sdf_annotate("HD_SYN.sdf", My_HD);
    $fsdbDumpfile("HD_SYN.fsdb");
	  $fsdbDumpvars(0,"+mda");
    $fsdbDumpvars();    
  `endif
end

HD My_HD(
.code_word1(code_word1),
.code_word2(code_word2),
.out_n(out_n)
);

PATTERN My_PATTERN(
.code_word1(code_word1),
.code_word2(code_word2),
.out_n(out_n)
);
  
endmodule
