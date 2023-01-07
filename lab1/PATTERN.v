`define CYCLE_TIME 20.0
module PATTERN(
// Output signals
  code_word1,
  code_word2,
  // Input signals
  out_n
);
//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
output reg [6:0] code_word1, code_word2;
input signed [5:0] out_n;
//================================================================
// parameters & integer
//================================================================
integer PATNUM = 2000;
integer total_latency;
integer patcount;
integer file_in, file_out, cnt_in, cnt_out;
integer lat,i,j;
//================================================================
// wire & registers 
//================================================================
integer input_file_a, input_file_b, output_file;
integer golden_out;
integer c1, c2, out1;
//================================================================
// clock
//================================================================
reg clk;
real	CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk;
initial	clk = 0;

//================================================================
// initial
//================================================================
initial begin
    code_word1 = 4'dx;
	code_word2 = 4'dx;
    golden_out = 0;
	total_latency = 0;

    input_file_a  = $fopen("../00_TESTBED/input_a_demo.txt","r");
    input_file_b  = $fopen("../00_TESTBED/input_b_demo.txt","r");
    output_file   = $fopen("../00_TESTBED/output_demo.txt" ,"r");
    @(negedge clk);

	for(patcount = 0; patcount < PATNUM; patcount = patcount + 1)
	begin		
		gen_data;
		gen_golden;
        repeat(1) @(negedge clk);
		check_ans;
		repeat(3) @(negedge clk);
	end
    
	display_pass;
    
    repeat(3) @(negedge clk);
    $finish;
	$fclose(file_in);
	$fclose(file_out);
end

//================================================================
// task
//================================================================
task gen_data; begin
	//generate operation and inputs 
    c1 = $fscanf (input_file_a, "%d", code_word1);
    c2 = $fscanf (input_file_b, "%d", code_word2);
end endtask


task gen_golden; begin
    out1 = $fscanf (output_file, "%d", golden_out);
end endtask

task check_ans; begin
    if(out_n !== golden_out)
    begin
        display_fail;
        $display ("-------------------------------------------------------------------");
		$display("*                            PATTERN NO.%4d 	                      ", patcount);
        $display ("                                 Fail                             ");
        $display ("             answer should be : %d , your answer is : %d           ", golden_out, out_n);
        $display ("-------------------------------------------------------------------");
        #(100);
        $finish ;
    end
    else 
        $display ("             Pass Pattern NO. %d          ", patcount);
end
endtask
task display_fail;
begin
        $display("\n");
        $display("\n");
        $display("        ----------------------------               ");
        $display("        --                        --       |\__||  ");
        $display("        --  OOPS!!                --      / X,X  | ");
        $display("        --                        --    /_____   | ");
        $display("        --  Simulation Failed!!   --   /^ ^ ^ \\  |");
        $display("        --                        --  |^ ^ ^ ^ |w| ");
        $display("        ----------------------------   \\m___m__|_|");
        $display("\n");
end
endtask

task display_pass;
begin
        $display("\n");
        $display("\n");
        $display("        ----------------------------               ");
        $display("        --                        --       |\__||  ");
        $display("        --  Congratulations !!    --      / O.O  | ");
        $display("        --                        --    /_____   | ");
        $display("        --  Simulation PASS!!     --   /^ ^ ^ \\  |");
        $display("        --                        --  |^ ^ ^ ^ |w| ");
        $display("        ----------------------------   \\m___m__|_|");
        $display("\n");
end
endtask
endmodule
