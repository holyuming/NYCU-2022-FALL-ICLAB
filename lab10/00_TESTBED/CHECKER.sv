module Checker(input clk, INF.CHECKER inf);
import usertype::*;

//declare other cover group
covergroup CG1 @(posedge clk iff (inf.id_valid == 1));
    coverpoint inf.D.d_id[0] {
        option.at_least = 1;
        option.auto_bin_max = 256;
    }
endgroup

covergroup CG2 @(posedge clk iff (inf.act_valid == 1));
    coverpoint inf.D.d_act[0] {
        option.at_least = 10;
        bins t0 [] = (Take, Order, Deliver, Cancel => Take, Order, Deliver, Cancel);
    }
endgroup

covergroup CG3 @(negedge clk iff (inf.out_valid == 1));
    coverpoint inf.complete {
        option.at_least = 200;
		bins b0 = { 0 };
		bins b1 = { 1 };
    }
endgroup

covergroup CG4 @(negedge clk iff (inf.out_valid == 1));
    coverpoint inf.err_msg {
        option.at_least = 20;
        bins b0 = { No_Food };
        bins b1 = { D_man_busy };
        bins b2 = { No_customers };
        bins b3 = { Res_busy };
        bins b4 = { Wrong_cancel };
        bins b5 = { Wrong_res_ID };
        bins b6 = { Wrong_food_ID };
    }
endgroup

// instantiate
CG1 cg1 = new();
CG2 cg2 = new();
CG3 cg3 = new();
CG4 cg4 = new();


//************************************ below assertion is to check your pattern ***************************************** 
//                                          Please finish and hand in it
// This is an example assertion given by TA, please write the required assertions below
//  assert_interval : assert property ( @(posedge clk)  inf.out_valid |=> inf.id_valid == 0 [*2])
//  else
//  begin
//  	$display("Assertion X is violated");
//  	$fatal; 
//  end
wire #(0.5) rst_reg = inf.rst_n;
Action action;
always_ff @( posedge clk, negedge inf.rst_n ) begin : action_ff
    if (!inf.rst_n) action <= No_action;
    else            action <= (inf.act_valid == 1) ? inf.D.d_act[0] : action;
end
//write other assertions
//========================================================================================================================================================
// Assertion 1 ( All outputs signals (including FD.sv and bridge.sv) should be zero after reset.)
//========================================================================================================================================================

// assertion 1: All output signals (including FD.sv and bridge.sv) should be zero after reset.
always_ff @( negedge rst_reg ) begin
    ASSERT_1 : assert (
        // FD
        inf.out_valid === 0 &&
        inf.out_info === 0 &&
        inf.err_msg === 0 &&
        inf.complete === 0 &&
        inf.C_addr === 0 &&
        inf.C_data_w === 0 &&
        inf.C_in_valid === 0 &&
        inf.C_r_wb === 0 &&
        // bridge
        inf.C_out_valid === 0 &&
        inf.C_data_r === 0 &&
        inf.AR_VALID === 0 &&
        inf.AR_ADDR === 0 &&
        inf.R_READY === 0 &&
        inf.AW_VALID === 0 &&
        inf.AW_ADDR === 0 &&
        inf.W_VALID === 0 &&
        inf.W_DATA === 0 &&
        inf.B_READY === 0

    ) else begin
        $display("Assertion 1 is violated");
        $fatal;
    end
end


// assertion 2: If action is completed, err_msg should be 4’b0.
ASSERT_2 : assert property ( @(negedge clk) ( inf.complete === 1 && inf.out_valid === 1 ) |-> (inf.err_msg === 4'b0) )
else
begin
	$display("Assertion 2 is violated");
 	$fatal; 
end

// assertion 3: If action is not completed, out_info should be 64’b0.
ASSERT_3 : assert property ( @(negedge clk) ( inf.complete === 0 && inf.out_valid === 1 ) |-> (inf.out_info === 'd0) )
else
begin
	$display("Assertion 3 is violated");
 	$fatal; 
end


// assertion 4: The gap between each input valid is at least 1 cycle and at most 5 cycles.
ASSERT_40 : assert property (
    @(posedge clk)
    (inf.act_valid === 1) |=> (inf.id_valid === 0 && inf.res_valid === 0 && inf.food_valid === 0 && inf.cus_valid === 0) 
    ##[1:5] (inf.id_valid === 1 || inf.res_valid === 1 || inf.food_valid === 1 || inf.cus_valid === 1)
) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

ASSERT_41 : assert property (
    @(posedge clk)
    (inf.id_valid === 1 && action === Take) |=> (inf.cus_valid === 0) ##[1:5] (inf.cus_valid === 1)
) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

ASSERT_42 : assert property (
    @(posedge clk)
    (inf.res_valid === 1) |=> (inf.food_valid === 0) ##[1:5] (inf.food_valid === 1)
) else begin
    $display("Assertion 4 is violated");
    $fatal;
end

ASSERT_43 : assert property (
    @(posedge clk)
    (inf.food_valid === 1 && action === Cancel) |=> (inf.id_valid === 0) ##[1:5] (inf.id_valid === 1)
) else begin
    $display("Assertion 4 is violated");
    $fatal;
end


// assertion 5: All input valid signals won’t overlap with each other.
ASSERT_5 : assert property ( @(posedge clk) (
    $onehot({
        inf.id_valid,
        inf.act_valid,
        inf.res_valid,
        inf.cus_valid,
        inf.food_valid,
        !(inf.id_valid || inf.act_valid || inf.res_valid || inf.cus_valid || inf.food_valid)
    })
)) else begin
    $display("Assertion 5 is violated");
    $fatal;
end


// assertion 6: Out_valid can only be high for exactly one cycle.
ASSERT_6 : assert property (@(posedge clk) (inf.out_valid === 1) |=> (inf.out_valid === 0))
else begin
    $display("Assertion 6 is violated");
    $fatal;
end


// assertion 7: Next operation will be valid 2-10 cycles after out_valid fall.
ASSERT_70 : assert property (@(posedge clk) (inf.out_valid === 1) |-> ##[2:10] (inf.act_valid === 1))
else begin
    $display("Assertion 7 is violated");
    $fatal;
end

ASSERT_71 : assert property (@(posedge clk) (inf.out_valid === 1) |-> (inf.act_valid === 0))
else begin
    $display("Assertion 7 is violated");
    $fatal;
end

ASSERT_72 : assert property (@(posedge clk) (inf.out_valid === 1) |-> ##[1:1] (inf.act_valid === 0))
else begin
    $display("Assertion 7 is violated");
    $fatal;
end

// assertion 8: Latency should be less than 1200 cycles for each operation.
ASSERT_80 : assert property (
    @(posedge clk) 
    (inf.cus_valid === 1 && action == Take) |-> (##[2:1200] inf.out_valid === 1)
)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end

ASSERT_81 : assert property (
    @(posedge clk) 
    (inf.id_valid === 1 && action == Deliver) |-> (##[2:1200] inf.out_valid === 1)
)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end

ASSERT_82 : assert property (
    @(posedge clk) 
    (inf.food_valid === 1 && action == Order) |-> (##[2:1200] inf.out_valid === 1)
)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end

ASSERT_83 : assert property (
    @(posedge clk) 
    (inf.id_valid === 1 && action == Cancel) |-> (##[2:1200] inf.out_valid === 1)
)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end

endmodule