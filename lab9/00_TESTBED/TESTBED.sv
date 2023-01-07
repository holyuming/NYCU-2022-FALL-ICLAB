`timescale 1ns/1ps

`include "Usertype_FD.sv"
`include "INF.sv"
`include "PATTERN.sv"
// `include "PATTERN_bridge.sv"
// `include "PATTERN_FD.sv"
`include "../00_TESTBED/pseudo_DRAM.sv"

`ifdef RTL
  `include "bridge.sv"
  `include "FD.sv"
  `define CYCLE_TIME 3.3
`endif

`ifdef GATE
  `include "bridge_SYN.v"
  `include "bridge_Wrapper.sv"
  `include "FD_SYN.v"
  `include "FD_Wrapper.sv"
  `define CYCLE_TIME 3.3
`endif

module TESTBED;
  
parameter simulation_cycle = `CYCLE_TIME;
  reg  SystemClock;

  INF             inf();
  PATTERN         test_p(.clk(SystemClock), .inf(inf.PATTERN));
  // PATTERN_bridge  test_pb(.clk(SystemClock), .inf(inf.PATTERN_bridge));
  // PATTERN_FD      test_pp(.clk(SystemClock), .inf(inf.PATTERN_FD));
  pseudo_DRAM     dram_r(.clk(SystemClock), .inf(inf.DRAM)); 

  `ifdef RTL
	bridge  dut_b(.clk(SystemClock), .inf(inf.bridge_inf) );
	FD      dut_p(.clk(SystemClock), .inf(inf.FD_inf) );
  `endif
  
  `ifdef GATE
	bridge_svsim  dut_b(.clk(SystemClock), .inf(inf.bridge_inf) );
	FD_svsim      dut_p(.clk(SystemClock), .inf(inf.FD_inf) );
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
  
//------ Dump FSDB File ------------  
initial begin
  `ifdef RTL
    // $fsdbDumpfile("FDB.fsdb");
    // $fsdbDumpvars(0,"+all");
    // $fsdbDumpSVA;
  `elsif GATE
    // $fsdbDumpfile("FD_SYN.fsdb");
    $sdf_annotate("bridge_SYN.sdf",dut_b.bridge);      
    $sdf_annotate("FD_SYN.sdf",dut_p.FD);      
    // $fsdbDumpvars(0,"+all");
  `endif
end

endmodule