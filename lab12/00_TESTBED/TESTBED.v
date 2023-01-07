`timescale 1ns/1ps

`include "PATTERN.v"
`ifdef RTL
  `include "TT.v"
`endif
`ifdef GATE
  `include "TT_SYN.v"
`endif
`ifdef POST
  `include "CHIP.v"
`endif
	  		  	
module TESTBED;

wire         clk, rst_n, in_valid;
wire  [3:0]  source;
wire  [3:0]  destination;

wire         out_valid;
wire  [3:0]  cost;


initial begin
  `ifdef RTL
    //$fsdbDumpfile("TT.fsdb");
	$fsdbDumpvars(0,"+mda");
    $fsdbDumpvars();
  `endif
  `ifdef GATE
    $sdf_annotate("TT_SYN.sdf", u_TT);
    //$fsdbDumpfile("TT_SYN.fsdb");
    $fsdbDumpvars();    
  `endif
  `ifdef POST
    $sdf_annotate("CHIP.sdf", u_CHIP);
    $fsdbDumpfile("CHIP_POST.fsdb");
	$fsdbDumpvars(0,"+mda");
  `endif
end

PATTERN u_PATTERN(
    .clk            (   clk          ),
    .rst_n          (   rst_n        ),
    .in_valid       (   in_valid     ),
    .source         (   source       ),
    .destination    (   destination  ),

    .out_valid      (   out_valid    ),
    .cost           (   cost         )
   );

`ifdef RTL	
	TT u_TT(
		.clk            (   clk          ),
		.rst_n          (   rst_n        ),
		.in_valid       (   in_valid     ),
		.source         (   source       ),
		.destination    (   destination  ),

		.out_valid      (   out_valid    ),
		.cost           (   cost         )
	   );	
`endif
`ifdef GATE	
	TT u_TT(
		.clk            (   clk          ),
		.rst_n          (   rst_n        ),
		.in_valid       (   in_valid     ),
		.source         (   source       ),
		.destination    (   destination  ),

		.out_valid      (   out_valid    ),
		.cost           (   cost         )
	   );	
`endif
`ifdef POST	
	CHIP u_CHIP(
		.clk            (   clk          ),
		.rst_n          (   rst_n        ),
		.in_valid       (   in_valid     ),
		.source         (   source       ),
		.destination    (   destination  ),

		.out_valid      (   out_valid    ),
		.cost           (   cost         )
	   );	
`endif

endmodule
