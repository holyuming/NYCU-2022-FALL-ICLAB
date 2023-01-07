`timescale 1ns/1ps

`include "Usertype_FD.sv"
`include "INF.sv"
`include "PATTERN.sv"
`include "../00_TESTBED/pseudo_DRAM.sv"
`include "CHECKER.sv"

`ifdef RTL
  `include "bridge.sv"
  `include "FD.sv"
  `define CYCLE_TIME 1.0
`endif

module TESTBED;
  
parameter simulation_cycle = `CYCLE_TIME;
  reg  SystemClock;

  INF             inf();
  PATTERN         test_p(.clk(SystemClock), .inf(inf.PATTERN));
  pseudo_DRAM     dram_r(.clk(SystemClock), .inf(inf.DRAM)); 
  Checker 		    check_inst (.clk(SystemClock), .inf(inf.CHECKER));
  
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
  `endif

end

endmodule