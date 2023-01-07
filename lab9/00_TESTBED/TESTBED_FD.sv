`timescale 1ns/100ps

`include "Usertype_FD.sv"
`include "INF.sv"
`include "PATTERN_FD.sv"

`ifdef RTL
  `include "FD.sv"
`endif

module TESTBED;
  
  parameter simulation_cycle = 8.0;
  reg  SystemClock;

  INF  inf();
  PATTERN_FD test_p(.clk(SystemClock), .inf(inf.PATTERN_FD));
  
  `ifdef RTL
	FD dut(.clk(SystemClock), .inf(inf.FD_inf) );
  `endif
  
 //------ Generate Clock ------------
  initial begin
    SystemClock = 0;
	#30
    forever begin
      #(simulation_cycle/2.0)
        SystemClock = ~SystemClock;
    end
  end
  
//------ Dump VCD File ------------  
initial begin
  `ifdef RTL
    $fsdbDumpfile("FD.fsdb");
    $fsdbDumpvars(0,"+all");
    $fsdbDumpSVA;
  `endif
end

endmodule